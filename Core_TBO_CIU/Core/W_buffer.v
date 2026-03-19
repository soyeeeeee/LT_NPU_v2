`timescale 1ns / 1ps

//delay = 1 cycle

module W_buffer(
    input CLK,
    input rst,
    input en,
    input [31:0]wdata_0,
    input [31:0]wdata_1,
    input [31:0]wdata_2,
    input [31:0]wdata_3,
    output reg [31:0]PE_win_0,
    output reg [31:0]PE_win_1,
    output reg [31:0]PE_win_2,
    output reg [31:0]PE_win_3
    );
    
    always@(posedge CLK) begin
        if(rst == 1) begin
            PE_win_0 <= 0;
            PE_win_1 <= 0;
            PE_win_2 <= 0;
            PE_win_3 <= 0;
        end
        else begin
            if(en) begin
                PE_win_0 <= wdata_0;
                PE_win_1 <= wdata_1;
                PE_win_2 <= wdata_2;
                PE_win_3 <= wdata_3;
            end
            else begin
                PE_win_0 <= PE_win_0;
                PE_win_1 <= PE_win_1;
                PE_win_2 <= PE_win_2;
                PE_win_3 <= PE_win_3;
            end
        end
    end
    
endmodule