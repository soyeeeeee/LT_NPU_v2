`timescale 1ns / 1ps

// =============================================================================
// Module: AGU_I (Controller Handshake Version)
// Description: Image Address Generation Unit
//              Generates write addresses for the double buffer.
//              Uses level handshake for controller synchronization.
// =============================================================================

module AGU_I_busy (
    input  wire        clk,              // 系統時脈
    input  wire        rst_n,            // 非同步復位 (Active Low)

    // --- 資料介面 ---
    input  wire        i_valid,          // 資料有效信號 (來自 Preprocessing)

    // --- 控制介面 (交握訊號) ---
    input  wire        i_layer_start,    // 啟動脈衝 (開始單行處理)
    input  wire        i_buffer_sel,     // Buffer 選擇 (0 或 1)
    input  wire        i_image_done,     // 同步重置訊號 (Frame 處理完成)

    // --- URAM 寫入介面 ---
    output reg  [6:0]  uram_addr,        // 寫入位址 [6]=Buffer, [5:0]=Offset
    output reg         uram_we,          // 寫入致能

    // --- 狀態介面 ---
    output reg         tile_done,        // 單行處理完成訊號
    output reg         o_busy,           // 🌟 改回 reg：利用 D型觸發器的自然延遲
    output wire        o_ready           // 背壓訊號 (輸出至 Preprocessing)
);

    // =========================================================================
    // 參數與內部暫存器
    // =========================================================================
    localparam integer BEATS_PER_LINE = 64; // INT8 版仍為 128px / 2px per 64-bit beat = 64 beats

    reg [5:0] beat_cnt;          // 內部計數器 (0~63)
    reg       wait_for_start;    // 等待啟動狀態旗標
    reg       active_buffer_sel; // 當前鎖定之 Buffer 選擇

    // --- 背壓控制 ---
    assign o_ready = !wait_for_start && rst_n;

    // --- 次態邏輯 ---
    reg next_active_buffer_sel;
    always @(*) begin
        next_active_buffer_sel = active_buffer_sel;
        if (!i_valid || wait_for_start) begin
            if (beat_cnt == 0) begin
                next_active_buffer_sel = i_buffer_sel;
            end
        end
    end

    // =========================================================================
    // 時序邏輯 (狀態更新與交握)
    // =========================================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 1. 非同步重置
            beat_cnt          <= 6'd0;
            wait_for_start    <= 1'b1; 
            active_buffer_sel <= 1'b0;
            
            uram_addr         <= 7'd0;
            uram_we           <= 1'b0;
            tile_done         <= 1'b0;
            o_busy            <= 1'b0; 
            
        end else if (i_image_done) begin
            // 2. 同步重置 (Frame 結束)
            beat_cnt          <= 6'd0;
            wait_for_start    <= 1'b1; 
            active_buffer_sel <= 1'b0;
            
            uram_addr         <= 7'd0;
            uram_we           <= 1'b0;
            tile_done         <= 1'b0;
            o_busy            <= 1'b0; 
            
        end else begin
            // 3. 正常運作邏輯
            
            // 3.1 參數更新 
            if (!wait_for_start || i_layer_start) begin
                active_buffer_sel <= next_active_buffer_sel;
            end

            // 3.2 交握與資料寫入控制
            if (wait_for_start) begin
                uram_we <= 1'b0; 
                
                // 🌟 當前 Clock 看到外部 i_layer_start 為 1 時執行
                if (i_layer_start) begin 
                    wait_for_start <= 1'b0; 
                    tile_done      <= 1'b0; 
                    o_busy         <= 1'b1; // 🌟 賦值 1，會在「下一個 Clock 上升緣」對外生效！
                end
            end else begin
                // 資料接收與處理
                if (i_valid && o_ready) begin
                    uram_we   <= 1'b1;
                    uram_addr <= {active_buffer_sel, beat_cnt}; 

                    if (beat_cnt < BEATS_PER_LINE - 1) begin
                        beat_cnt <= beat_cnt + 1'b1;
                    end else begin
                        // 單行傳輸完成
                        beat_cnt       <= 6'd0;
                        tile_done      <= 1'b1; 
                        wait_for_start <= 1'b1; 
                        o_busy         <= 1'b0; // 傳輸結束，降下 Busy
                    end
                end else begin
                    uram_we <= 1'b0;
                end
            end
        end
    end

endmodule