`timescale 1ns / 1ps

// =============================================================================
// 模組名稱: Image_Write_Subsystem
// 描述: 影像寫入子系統總層。
//       接收 DMA 資料，透過 Processing_V1 進行預處理與裁切，
//       並由 AGU_I_busy 產生對齊之 64-bit INT8 RGB 寫入位址供後端 BRAM 使用。
// =============================================================================

module Image_Write_Subsystem (
    input  wire         clk,
    input  wire         rst_n,

    // --- AXI Stream 串流輸入 ---
    input  wire [63:0]  s_axis_tdata,
    input  wire         s_axis_tvalid,
    input  wire         s_axis_tlast,
    output wire         s_axis_tready,

    // --- 控制介面 ---
    input  wire         i_layer_start,
    input  wire         i_buffer_sel,
    input  wire         i_image_done,
    
    // --- 狀態介面 ---
    output wire         o_tile_done,     // 單行/區塊處理完成
    output wire         o_busy,         

    // --- 對齊後的 URAM 寫入介面 ---
    output wire [6:0]   o_uram_addr,
    output wire         o_uram_we,
    output reg  [63:0]  o_uram_data
);

    // =========================================================================
    // 內部連線
    // =========================================================================
    // Loader 至 Processing
    wire [63:0] loader_tdata;
    wire        loader_tvalid;
    wire        loader_tready;

    // Processing 至 AGU 
    wire [63:0] proc_tdata;
    wire         proc_tvalid;
    wire         proc_tlast;
    wire         agu_ready;

    // =========================================================================
    // 1. Image_Loader (Skid Buffer 吸收高頻延遲)
    // =========================================================================
    Image_Loader u_image_loader (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .m_axis_tdata   (loader_tdata),
        .m_axis_tvalid  (loader_tvalid),
        .m_axis_tready  (loader_tready)
    );

    // =========================================================================
    // 2. Processing_V1 (影像預處理核心)
    // =========================================================================
    Processing_V1 u_processing (
        .aclk           (clk),
        .aresetn        (rst_n),
        .s_axis_tdata   (loader_tdata),
        .s_axis_tvalid  (loader_tvalid),
        .s_axis_tlast   (s_axis_tlast),
        .s_axis_tready  (loader_tready),
        .m_axis_tdata   (proc_tdata),
        .m_axis_tvalid  (proc_tvalid),
        .m_axis_tlast   (proc_tlast),
        .m_axis_tready  (agu_ready)      // 接收 AGU_I 的背壓控制
    );

    // =========================================================================
    // 3. AGU_I_stop_V1 (位址產生單元，含 Busy 交握機制)
    // =========================================================================
    AGU_I_busy u_agu_i (
        .clk            (clk),
        .rst_n          (rst_n),
        .i_valid        (proc_tvalid),   // 接收預處理後之 Valid
        .i_layer_start  (i_layer_start),
        .i_buffer_sel   (i_buffer_sel),
        .i_image_done   (i_image_done),
        .uram_addr      (o_uram_addr),
        .uram_we        (o_uram_we),
        .tile_done      (o_tile_done),
        .o_busy         (o_busy),       
        .o_ready        (agu_ready)      // 輸出 Ready 訊號給 Processing
    );

    // =========================================================================
    // 4. 資料對齊暫存器 (Data Alignment)
    // =========================================================================
    // AGU 收到 valid 後，位址會延遲一拍輸出。
    // 此處將預處理資料也打一拍，確保資料與寫入位址完美對齊。
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            o_uram_data <= 64'd0;
        end else begin
            if (proc_tvalid && agu_ready) begin
                o_uram_data <= proc_tdata;
            end
        end
    end

endmodule