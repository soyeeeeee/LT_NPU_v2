`timescale 1ns / 1ps

module Weight_Loader_stop (
    input  wire        clk,          
    input  wire        rst_n,        

    // AXI Stream Input Interface (From DMA)
    // INT8 format: Weight phase uses data[31:0] for 4 x INT8 and data[63:32]=0; Bias phase uses 2 x INT32.
    input  wire [63:0] s_axis_data,  
    input  wire        s_axis_valid, 
    output wire        s_axis_ready, // [修改] 改由邏輯控制

    // [新增] 來自 AGU 的背壓訊號
    input  wire        i_backend_ready, 

    // Internal Pipeline Output Interface
    output reg  [63:0] m_data,       
    output reg         m_valid       
);

    // 1. AXI Handshake Control (把 AGU 的 ready 傳給 DMA)
    assign s_axis_ready = i_backend_ready;

    // 2. Input Register Slice (具備暫停功能)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            m_data  <= 64'd0;
            m_valid <= 1'b0;
        end else begin
            // [關鍵] 只有後端說 OK (Ready=1) 才更新數據
            // 如果 i_backend_ready=0，這裡會鎖住 (Freeze)，資料不會遺失
            if (i_backend_ready) begin
                m_valid <= s_axis_valid;
                m_data  <= s_axis_data;
            end
        end
    end

endmodule