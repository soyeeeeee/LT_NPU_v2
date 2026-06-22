`timescale 1ns / 1ps

// =============================================================================
// 模組名稱: Weight_Write_Subsystem
// 描述: 權重與偏差值寫入子系統總層。
//       接收 DMA 的 AXI-Stream 資料，透過 AGU_W_busy 產生 24-bit 廣播
//       寫入位址與致能訊號，並將資料打一拍對齊後輸出給 WBR 串鏈。
// =============================================================================

module Weight_Write_Subsystem (
    input  wire        clk,
    input  wire        rst_n,

    // --- AXI Stream 串流輸入 ---
    // 64-bit interface is intentionally retained: low 32 bits carry 4 x INT8 weights; full 64 bits carry 2 x INT32 biases.
    input  wire [63:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output wire        s_axis_tready,

    // --- 控制介面 ---
    input  wire [11:0] i_weight_len,
    input  wire [6:0]  i_bias_len,
    input  wire        i_layer_start,
    input  wire [1:0]  i_buffer_sel,     // 🌟 對應 AGU 更新：變更為 2-bit [1:0]
    input  wire        i_image_done,

    // --- 對齊後的廣播輸出介面 ---
    output reg  [63:0] o_aligned_data,
    output wire [12:0] o_aligned_w_addr, // 🌟 對應 AGU 更新：URAM 位址擴增為 13-bit [12:0]
    output wire [6:0]  o_aligned_b_addr, // BRAM 位址維持 7-bit
    output wire [23:0] o_aligned_w_we_group,
    output wire [23:0] o_aligned_b_we_group,
    
    // --- 狀態介面 ---
    output wire [4:0]  o_layer_cnt,
    output wire        o_layer_done,
    output wire        o_all_done,
    output wire        o_busy          // 忙碌狀態指示
);

    // =========================================================================
    // 內部連線
    // =========================================================================
    wire [63:0] loader_data;
    wire        loader_valid;
    wire        agu_ready;

    // =========================================================================
    // 1. Weight_Loader_stop (負責吸收 DMA 資料並處理背壓)
    // =========================================================================
    Weight_Loader_stop u_loader (
        .clk             (clk), 
        .rst_n           (rst_n),
        .s_axis_data     (s_axis_tdata), 
        .s_axis_valid    (s_axis_tvalid), 
        .s_axis_ready    (s_axis_tready),
        .i_backend_ready (agu_ready),    // 接收 AGU 的背壓控制
        .m_data          (loader_data), 
        .m_valid         (loader_valid)
    );

    // =========================================================================
    // 2. AGU_W_busy (位址產生單元，含 Busy 交握機制)
    // =========================================================================
    AGU_W_busy u_agu_w (
        .clk             (clk), 
        .rst_n           (rst_n),
        .i_valid         (loader_valid), 
        .i_weight_len    (i_weight_len), 
        .i_bias_len      (i_bias_len),
        .i_buffer_sel    (i_buffer_sel),  // 🌟 自動推斷傳遞 2-bit 訊號
        .i_layer_start   (i_layer_start),
        .i_image_done    (i_image_done),
        .o_uram_addr     (o_aligned_w_addr), // 🌟 自動推斷接收 13-bit 位址
        .o_uram_we       (o_aligned_w_we_group),
        .o_bram_addr     (o_aligned_b_addr), 
        .o_bram_we       (o_aligned_b_we_group),
        .o_layer_cnt     (o_layer_cnt),
        .o_layer_done    (o_layer_done), 
        .o_all_done      (o_all_done),
        .o_busy          (o_busy),       // 輸出 Busy 訊號給 Controller
        .o_ready         (agu_ready)     // 輸出 Ready 訊號給 Loader
    );

    // =========================================================================
    // 3. 資料對齊暫存器 (Data Alignment)
    // =========================================================================
    // AGU 收到 valid 後，位址會延遲一拍輸出。
    // 此處將資料也打一拍，確保資料與位址完美對齊。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_aligned_data <= 64'd0;
        end else begin
            if (loader_valid && agu_ready) begin
                o_aligned_data <= loader_data;
            end
        end
    end

endmodule