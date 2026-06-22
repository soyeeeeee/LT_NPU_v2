`timescale 1ns / 1ps

// =============================================================================
// 模組名稱: WBR (Weight Broadcast Router)
// 描述: 權重廣播路由器 (Daisy-Chain 管線節點)。
//       接收前級的資料、位址與寫入致能訊號。截取最低 4-bit 作為本地寫入致能，
//       其餘控制訊號右移 4-bit 後，與資料、位址及交握訊號同步打一拍轉發至下一級。
// =============================================================================

module WBR (
    input  wire        clk,
    input  wire        rst_n,

    // ==========================================
    // [Input] 來自上一級 (或子系統總層)
    // Data remains 64-bit so the same path can carry low-32-bit INT8 weights or full-width INT32 biases.
    // ==========================================
    input  wire [63:0] i_data,
    input  wire [12:0] i_w_addr,     // 🌟 配合 AGU 更新：擴充為 13-bit
    input  wire [6:0]  i_b_addr,
    
    // 寫入控制 (24-bit 總線)
    input  wire [23:0] i_w_we_group, 
    input  wire [23:0] i_b_we_group,
    
    // 狀態與交握訊號
    input  wire        i_layer_done,
    input  wire        i_busy,         

    // ==========================================
    // [Output] 本地輸出 (供本層 Storage 使用)
    // ==========================================
    output reg  [63:0] o_local_data,
    
    // 本地 Weight 寫入 (截取最低 4-bit)
    output reg  [3:0]  o_local_w_we,   
    output reg  [12:0] o_local_w_addr, // 🌟 配合 AGU 更新：擴充為 13-bit
    
    // 本地 Bias 寫入 (截取最低 4-bit)
    output reg  [3:0]  o_local_b_we,   
    output reg  [6:0]  o_local_b_addr,

    // ==========================================
    // [Output] 轉發輸出 (供下一級 WBR 使用)
    // ==========================================
    output reg  [63:0] o_next_data,
    output reg  [12:0] o_next_w_addr,  // 🌟 配合 AGU 更新：擴充為 13-bit
    output reg  [6:0]  o_next_b_addr,
    
    // 轉發寫入控制 (已右移 4-bit)
    output reg  [23:0] o_next_w_we_group,
    output reg  [23:0] o_next_b_we_group,
    
    // 轉發狀態與交握訊號
    output reg         o_next_layer_done,
    output reg         o_next_busy        
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // --- 復位本地輸出 ---
            o_local_data      <= 64'd0;
            o_local_w_addr    <= 13'd0; // 🌟 重置數值改為 13'd0
            o_local_b_addr    <= 7'd0;
            o_local_w_we      <= 4'd0;
            o_local_b_we      <= 4'd0;

            // --- 復位轉發輸出 ---
            o_next_data       <= 64'd0;
            o_next_w_addr     <= 13'd0; // 🌟 重置數值改為 13'd0
            o_next_b_addr     <= 7'd0;
            o_next_w_we_group <= 24'd0;
            o_next_b_we_group <= 24'd0;
            o_next_layer_done <= 1'b0;
            o_next_busy       <= 1'b0; 
        end else begin
            // =====================================================
            // 1. 本地寫入邏輯 (Local Drop)
            // =====================================================
            // 資料與位址直接同步暫存
            o_local_data      <= i_data;
            o_local_w_addr    <= i_w_addr;
            o_local_b_addr    <= i_b_addr;
            
            // 截取 Write Enable 總線的最低 4-bit 給本地使用
            o_local_w_we      <= i_w_we_group[3:0];
            o_local_b_we      <= i_b_we_group[3:0];

            // =====================================================
            // 2. 轉發邏輯 (Forward to Next)
            // =====================================================
            // 資料與位址原封不動轉發
            o_next_data       <= i_data;
            o_next_w_addr     <= i_w_addr;
            o_next_b_addr     <= i_b_addr;

            // Write Enable 總線右移 4-bit (高位補 0)
            o_next_w_we_group <= {4'b0000, i_w_we_group[23:4]};
            o_next_b_we_group <= {4'b0000, i_b_we_group[23:4]};

            // 狀態與交握訊號同步延遲一拍後轉發
            o_next_layer_done <= i_layer_done;
            o_next_busy       <= i_busy; 
        end
    end

endmodule