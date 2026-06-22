`timescale 1ns / 1ps

// =============================================================================
// Module: Image_Loader
// Description: AXI Stream Skid Buffer (Pipeline Register)
//              負責接收 DMA 數據並提供緩衝，切斷 Ready 時序路徑 (Timing Break)。
//              確保高頻 (400MHz) 下的 Backpressure 處理安全。
// =============================================================================

// Raw YUV422 remains 64-bit; INT8 conversion occurs after preprocessing.
module Image_Loader (
    input  wire        clk,
    input  wire        rst_n,

    // --- Slave Interface (來自 DMA) ---
    input  wire [63:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    output reg         s_axis_tready, // Registered Ready Signal

    // --- Master Interface (去 Preprocessing) ---
    output reg  [63:0] m_axis_tdata,
    output reg         m_axis_tvalid,
    input  wire        m_axis_tready
);

    // =========================================================================
    // 內部信號 (Skid Buffer)
    // =========================================================================
    // 當 Master 端忙碌 (Ready=0) 但 Slave 端仍有數據時，暫存於此。
    reg [63:0] skid_data;
    reg        skid_valid;

    // =========================================================================
    // 主要邏輯
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= 64'd0;
            skid_valid    <= 1'b0;
            skid_data     <= 64'd0;
            s_axis_tready <= 1'b0;
        end else begin
            // -------------------------------------------------------
            // 1. Master (輸出) 邏輯
            // -------------------------------------------------------
            // 若後端準備好接收，或目前輸出無效 (Bubble)，則更新輸出
            if (m_axis_tready || !m_axis_tvalid) begin
                if (skid_valid) begin
                    // 若 Skid Buffer 有資料，優先輸出 Skid Buffer
                    m_axis_tdata  <= skid_data;
                    m_axis_tvalid <= 1'b1;
                    skid_valid    <= 1'b0; // 清空 Skid Buffer
                end else begin
                    // 若 Skid Buffer 為空，直接透傳輸入資料 (Passthrough)
                    m_axis_tdata  <= s_axis_tdata;
                    m_axis_tvalid <= s_axis_tvalid;
                end
            end

            // -------------------------------------------------------
            // 2. Skid Buffer (暫存) 邏輯
            // -------------------------------------------------------
            // 條件：後端忙碌 + 輸出端有資料 + 前端有新資料進來
            // 動作：將新資料存入 Skid Buffer，避免資料遺失
            if (!m_axis_tready && m_axis_tvalid && s_axis_tvalid && s_axis_tready) begin
                skid_data  <= s_axis_tdata;
                skid_valid <= 1'b1;
            end

            // -------------------------------------------------------
            // 3. Slave (輸入) Ready 邏輯
            // -------------------------------------------------------
            // 只要 Skid Buffer 是空的，我們就準備好接收新資料。
            // 這切斷了 s_ready 與 m_ready 的直接組合邏輯路徑。
            s_axis_tready <= !skid_valid; 
        end
    end

endmodule