`timescale 1ns / 1ps

// =============================================================================
// 模組名稱: Input_Write_Subsystem (Data_loader)
// 描述: 輸入寫入子系統頂層模組。
//       整合 AXI-Stream 接收器、影像內部緩衝 BRAM (Prep_buffer_sdp)，
//       以及權重緩衝路由器 (WBR) 的菊花鏈架構。
// =============================================================================

module Data_loader (
    input  wire        clk,
    input  wire        rst_n,

    // ==========================================
    // 1. AXI-Stream 介面 (連接外部 DMA)
    // ==========================================
    input  wire [63:0] s_axis_image_tdata,
    input  wire        s_axis_image_tvalid,
    input  wire        s_axis_image_tlast,
    output wire        s_axis_image_tready,

    // 共用 64-bit Weight/Bias DMA：
    // Weight phase 使用 [31:0] 放置 4 x INT8、[63:32] 由上游填 0；
    // Bias phase 使用完整 64-bit 放置 2 x INT32。
    input  wire [63:0] s_axis_weight_tdata,
    input  wire        s_axis_weight_tvalid,
    output wire        s_axis_weight_tready,

    // ==========================================
    // 2. 控制與狀態介面 (連接 Controller)
    // ==========================================
    input  wire        i_image_start,
    input  wire        i_weight_start,
    
    // 獨立的乒乓緩衝區選擇訊號
    input  wire        i_image_buffer_sel,
    input  wire [1:0]  i_weight_buffer_sel, // 🌟 配合 AGU 更新：加寬為 2-bit
    
    input  wire        i_image_done,
    
    // 權重參數 (來自 Controller 的 weight_loader_bus)
    input  wire [11:0] i_weight_len,
    input  wire [6:0]  i_bias_len,

    // 狀態輸出
    output wire        o_image_busy,
    output wire        o_weight_busy,
    output wire        o_image_tile_done,
    output wire        o_weight_layer_done,

    // ==========================================
    // 3. 影像讀取介面 (連接後級 Global Buffer)
    // ==========================================
    input  wire        i_prep_rd_en,    // 讀取致能
    input  wire [7:0]  i_prep_rd_addr,  // 讀取位址
    output wire        o_prep_rd_valid, // 讀取資料有效訊號 (經過 3 拍延遲對齊)
    output wire [31:0] o_prep_rd_data,  // INT8 RGB Pixel：每次讀取 1 個 32-bit pixel

    // ==========================================
    // 4. 權重與偏差輸出匯流排 (連接 6 個運算核心)
    // ==========================================
    // 🌟 更新格式: {we[3:0], addr[12:0], data[63:0]} = 81-bit
    output wire [80:0] o_wgt_storage_bus_1,
    output wire [80:0] o_wgt_storage_bus_2,
    output wire [80:0] o_wgt_storage_bus_3,
    output wire [80:0] o_wgt_storage_bus_4,
    output wire [80:0] o_wgt_storage_bus_5,
    output wire [80:0] o_wgt_storage_bus_6,

    // 格式: {we[3:0], addr[6:0], data[63:0]} = 75-bit (Bias 維持不變)
    output wire [74:0] o_bias_storage_bus_1,
    output wire [74:0] o_bias_storage_bus_2,
    output wire [74:0] o_bias_storage_bus_3,
    output wire [74:0] o_bias_storage_bus_4,
    output wire [74:0] o_bias_storage_bus_5,
    output wire [74:0] o_bias_storage_bus_6
);

    // =========================================================================
    // 內部訊號宣告
    // =========================================================================
    wire [63:0] wgt_g_data;
    wire [12:0] wgt_g_w_addr; // 🌟 擴寬為 13-bit
    wire [6:0]  wgt_g_b_addr;
    wire [23:0] wgt_g_w_we, wgt_g_b_we;
    wire        wgt_layer_done;

    // 菊花鏈轉發訊號 (L0 -> L1 -> L2 -> L3 -> L4 -> L5)
    wire [63:0] L1_d, L2_d, L3_d, L4_d, L5_d;
    wire [12:0] L1_wa, L2_wa, L3_wa, L4_wa, L5_wa; // 🌟 擴寬為 13-bit
    wire [6:0]  L1_ba, L2_ba, L3_ba, L4_ba, L5_ba;
    wire [23:0] L1_wwe, L2_wwe, L3_wwe, L4_wwe, L5_wwe;
    wire [23:0] L1_bwe, L2_bwe, L3_bwe, L4_bwe, L5_bwe;
    wire        L1_ld, L2_ld, L3_ld, L4_ld, L5_ld, L6_ld;
    wire        L1_busy, L2_busy, L3_busy, L4_busy, L5_busy, L6_busy;
    wire        wgt_sub_busy; 

    // 各核心本地輸出訊號
    wire [63:0] l_d1, l_d2, l_d3, l_d4, l_d5, l_d6;
    wire [12:0] l_wa1, l_wa2, l_wa3, l_wa4, l_wa5, l_wa6; // 🌟 擴寬為 13-bit
    wire [6:0]  l_ba1, l_ba2, l_ba3, l_ba4, l_ba5, l_ba6;
    wire [3:0]  l_wwe1, l_wwe2, l_wwe3, l_wwe4, l_wwe5, l_wwe6;
    wire [3:0]  l_bwe1, l_bwe2, l_bwe3, l_bwe4, l_bwe5, l_bwe6;

    // 影像內部 BRAM 接線（INT8：64-bit write / 32-bit read）
    wire [6:0]  internal_img_addr;
    wire        internal_img_we;
    wire [63:0] internal_img_data;
    
    wire [31:0] bram_rd_data;

    // =========================================================================
    // 實例化 1: 影像寫入子系統
    // =========================================================================
    Image_Write_Subsystem u_image_sub (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (s_axis_image_tdata),
        .s_axis_tvalid  (s_axis_image_tvalid),
        .s_axis_tlast   (s_axis_image_tlast),
        .s_axis_tready  (s_axis_image_tready),
        .i_layer_start  (i_image_start),
        .i_buffer_sel   (i_image_buffer_sel),
        .i_image_done   (i_image_done),
        .o_tile_done    (o_image_tile_done),
        .o_busy         (o_image_busy),
        
        .o_uram_addr    (internal_img_addr),
        .o_uram_we      (internal_img_we),
        .o_uram_data    (internal_img_data)
    );

    // =========================================================================
    // 實例化 1.5: 影像緩衝 BRAM (Prep_buffer_sdp)
    // =========================================================================
    Prep_buffer_sdp prep_buffer(
        // Port A: 寫入端 (由 Image_Write_Subsystem 控制)
        .clka   (clk),
        .ena    (1'b1),               
        .wea    (internal_img_we),    
        .addra  (internal_img_addr),  
        .dina   (internal_img_data),  
        
        // Port B: 讀取端 (由外部 Global Buffer 透過管線控制讀取)
        .clkb   (clk),
        .enb    (i_prep_rd_en),       
        .regceb (1'b1),               // BRAM 輸出暫存器 Enable (產生 1 拍額外延遲)
        .addrb  (i_prep_rd_addr),     
        .doutb  (bram_rd_data)        // 輸出接至內部 wire 進行管線化
    );

    // =========================================================================
    // 輸出管線暫存與 Valid 訊號產生邏輯 (3-Stage Pipeline)
    // =========================================================================
    reg [31:0]  prep_rd_data_reg;
    reg         prep_rd_valid_d1;
    reg         prep_rd_valid_d2;
    reg         prep_rd_valid_d3;

    always @(posedge clk) begin
        if (!rst_n) begin
            prep_rd_data_reg <= 32'b0;
            prep_rd_valid_d1 <= 1'b0;
            prep_rd_valid_d2 <= 1'b0;
            prep_rd_valid_d3 <= 1'b0;
        end else begin
            // 1. 資料打一拍：將 BRAM 輸出的資料鎖定後再輸出，以改善長佈線之時序 (Timing)
            prep_rd_data_reg <= bram_rd_data;
            
            // 2. Valid 訊號延遲對齊 (總共 3 拍)：
            prep_rd_valid_d1 <= i_prep_rd_en;     // 第 1 拍 (對應 BRAM 記憶體陣列讀取延遲)
            prep_rd_valid_d2 <= prep_rd_valid_d1; // 第 2 拍 (對應 BRAM 內建輸出暫存器 regceb 延遲)
            prep_rd_valid_d3 <= prep_rd_valid_d2; // 第 3 拍 (對應外部 prep_rd_data_reg 暫存器延遲)
        end
    end

    // 賦值至外部輸出腳位
    assign o_prep_rd_data  = prep_rd_data_reg;
    assign o_prep_rd_valid = prep_rd_valid_d3;

    // =========================================================================
    // 實例化 2: 權重寫入總站
    // =========================================================================
    Weight_Write_Subsystem u_weight_sub (
        .clk                  (clk),
        .rst_n                (rst_n),
        .s_axis_tdata         (s_axis_weight_tdata),
        .s_axis_tvalid        (s_axis_weight_tvalid),
        .s_axis_tready        (s_axis_weight_tready),
        .i_weight_len         (i_weight_len),
        .i_bias_len           (i_bias_len),
        .i_layer_start        (i_weight_start),
        .i_buffer_sel         (i_weight_buffer_sel), // 🌟 完美對接 2-bit
        .i_image_done         (i_image_done),
        .o_aligned_data       (wgt_g_data),
        .o_aligned_w_addr     (wgt_g_w_addr),        // 🌟 完美對接 13-bit
        .o_aligned_b_addr     (wgt_g_b_addr),
        .o_aligned_w_we_group (wgt_g_w_we),
        .o_aligned_b_we_group (wgt_g_b_we),
        .o_layer_cnt          (),
        .o_layer_done         (wgt_layer_done),
        .o_all_done           (),
        .o_busy               (wgt_sub_busy)
    );

    // =========================================================================
    // 實例化 3: 權重緩衝路由器 WBR x6 (菊花鏈架構)
    // =========================================================================
    WBR u_wbr_1 (.clk(clk), .rst_n(rst_n), .i_data(wgt_g_data), .i_w_addr(wgt_g_w_addr), .i_b_addr(wgt_g_b_addr), .i_w_we_group(wgt_g_w_we), .i_b_we_group(wgt_g_b_we), .i_layer_done(wgt_layer_done), .i_busy(wgt_sub_busy), .o_local_data(l_d1), .o_local_w_we(l_wwe1), .o_local_b_we(l_bwe1), .o_local_w_addr(l_wa1), .o_local_b_addr(l_ba1), .o_next_data(L1_d), .o_next_w_addr(L1_wa), .o_next_b_addr(L1_ba), .o_next_w_we_group(L1_wwe), .o_next_b_we_group(L1_bwe), .o_next_layer_done(L1_ld), .o_next_busy(L1_busy));
    WBR u_wbr_2 (.clk(clk), .rst_n(rst_n), .i_data(L1_d), .i_w_addr(L1_wa), .i_b_addr(L1_ba), .i_w_we_group(L1_wwe), .i_b_we_group(L1_bwe), .i_layer_done(L1_ld), .i_busy(L1_busy), .o_local_data(l_d2), .o_local_w_we(l_wwe2), .o_local_b_we(l_bwe2), .o_local_w_addr(l_wa2), .o_local_b_addr(l_ba2), .o_next_data(L2_d), .o_next_w_addr(L2_wa), .o_next_b_addr(L2_ba), .o_next_w_we_group(L2_wwe), .o_next_b_we_group(L2_bwe), .o_next_layer_done(L2_ld), .o_next_busy(L2_busy));
    WBR u_wbr_3 (.clk(clk), .rst_n(rst_n), .i_data(L2_d), .i_w_addr(L2_wa), .i_b_addr(L2_ba), .i_w_we_group(L2_wwe), .i_b_we_group(L2_bwe), .i_layer_done(L2_ld), .i_busy(L2_busy), .o_local_data(l_d3), .o_local_w_we(l_wwe3), .o_local_b_we(l_bwe3), .o_local_w_addr(l_wa3), .o_local_b_addr(l_ba3), .o_next_data(L3_d), .o_next_w_addr(L3_wa), .o_next_b_addr(L3_ba), .o_next_w_we_group(L3_wwe), .o_next_b_we_group(L3_bwe), .o_next_layer_done(L3_ld), .o_next_busy(L3_busy));
    WBR u_wbr_4 (.clk(clk), .rst_n(rst_n), .i_data(L3_d), .i_w_addr(L3_wa), .i_b_addr(L3_ba), .i_w_we_group(L3_wwe), .i_b_we_group(L3_bwe), .i_layer_done(L3_ld), .i_busy(L3_busy), .o_local_data(l_d4), .o_local_w_we(l_wwe4), .o_local_b_we(l_bwe4), .o_local_w_addr(l_wa4), .o_local_b_addr(l_ba4), .o_next_data(L4_d), .o_next_w_addr(L4_wa), .o_next_b_addr(L4_ba), .o_next_w_we_group(L4_wwe), .o_next_b_we_group(L4_bwe), .o_next_layer_done(L4_ld), .o_next_busy(L4_busy));
    WBR u_wbr_5 (.clk(clk), .rst_n(rst_n), .i_data(L4_d), .i_w_addr(L4_wa), .i_b_addr(L4_ba), .i_w_we_group(L4_wwe), .i_b_we_group(L4_bwe), .i_layer_done(L4_ld), .i_busy(L4_busy), .o_local_data(l_d5), .o_local_w_we(l_wwe5), .o_local_b_we(l_bwe5), .o_local_w_addr(l_wa5), .o_local_b_addr(l_ba5), .o_next_data(L5_d), .o_next_w_addr(L5_wa), .o_next_b_addr(L5_ba), .o_next_w_we_group(L5_wwe), .o_next_b_we_group(L5_bwe), .o_next_layer_done(L5_ld), .o_next_busy(L5_busy));
    WBR u_wbr_6 (.clk(clk), .rst_n(rst_n), .i_data(L5_d), .i_w_addr(L5_wa), .i_b_addr(L5_ba), .i_w_we_group(L5_wwe), .i_b_we_group(L5_bwe), .i_layer_done(L5_ld), .i_busy(L5_busy), .o_local_data(l_d6), .o_local_w_we(l_wwe6), .o_local_b_we(l_bwe6), .o_local_w_addr(l_wa6), .o_local_b_addr(l_ba6), .o_next_data(), .o_next_w_addr(), .o_next_b_addr(), .o_next_w_we_group(), .o_next_b_we_group(), .o_next_layer_done(L6_ld), .o_next_busy(L6_busy));

    // =========================================================================
    // 5. 輸出匯流排打包 (Bus Packaging)
    // =========================================================================
    // === Weight Storage Bus (wwe 順序反轉: 3 2 1 0 -> 0 1 2 3) ===
    // INT8 Weight 格式：每個 64-bit Storage word 的 [31:0] 放 4 x INT8，
    // [63:32] 固定補 0；因此仍保留原本 81-bit Storage bus 與位址/指令格式。
    assign o_wgt_storage_bus_1 = {{l_wwe1[0], l_wwe1[1], l_wwe1[2], l_wwe1[3]}, l_wa1, 32'd0, l_d1[31:0]};
    assign o_wgt_storage_bus_2 = {{l_wwe2[0], l_wwe2[1], l_wwe2[2], l_wwe2[3]}, l_wa2, 32'd0, l_d2[31:0]};
    assign o_wgt_storage_bus_3 = {{l_wwe3[0], l_wwe3[1], l_wwe3[2], l_wwe3[3]}, l_wa3, 32'd0, l_d3[31:0]};
    assign o_wgt_storage_bus_4 = {{l_wwe4[0], l_wwe4[1], l_wwe4[2], l_wwe4[3]}, l_wa4, 32'd0, l_d4[31:0]};
    assign o_wgt_storage_bus_5 = {{l_wwe5[0], l_wwe5[1], l_wwe5[2], l_wwe5[3]}, l_wa5, 32'd0, l_d5[31:0]};
    assign o_wgt_storage_bus_6 = {{l_wwe6[0], l_wwe6[1], l_wwe6[2], l_wwe6[3]}, l_wa6, 32'd0, l_d6[31:0]};

    // === Bias Storage Bus (bwe 順序反轉: 3 2 1 0 -> 0 1 2 3) ===
    assign o_bias_storage_bus_1 = {{l_bwe1[0], l_bwe1[1], l_bwe1[2], l_bwe1[3]}, l_ba1, l_d1};
    assign o_bias_storage_bus_2 = {{l_bwe2[0], l_bwe2[1], l_bwe2[2], l_bwe2[3]}, l_ba2, l_d2};
    assign o_bias_storage_bus_3 = {{l_bwe3[0], l_bwe3[1], l_bwe3[2], l_bwe3[3]}, l_ba3, l_d3};
    assign o_bias_storage_bus_4 = {{l_bwe4[0], l_bwe4[1], l_bwe4[2], l_bwe4[3]}, l_ba4, l_d4};
    assign o_bias_storage_bus_5 = {{l_bwe5[0], l_bwe5[1], l_bwe5[2], l_bwe5[3]}, l_ba5, l_d5};
    assign o_bias_storage_bus_6 = {{l_bwe6[0], l_bwe6[1], l_bwe6[2], l_bwe6[3]}, l_ba6, l_d6};
    
    // =========================================================================
    // 系統狀態輸出邏輯
    // =========================================================================
    // Done 訊號: 待最後一個節點 (L6) 完成，即代表該層權重全數處理完畢
    assign o_weight_layer_done = L6_ld;

    // Busy 訊號: 若管線內任一節點處於忙碌狀態，則整個子系統視為忙碌
    assign o_weight_busy = wgt_sub_busy | L1_busy | L2_busy | L3_busy | L4_busy | L5_busy | L6_busy;

endmodule