`timescale 1ns / 1ps

//delay = 1 cycle

module B_buffer(
    input CLK,
    input rst,
    input en,
    input [31:0]bdata_0,
    input [31:0]bdata_1,
    input [31:0]bdata_2,
    input [31:0]bdata_3,
    output reg [31:0]bias_0,
    output reg [31:0]bias_1,
    output reg [31:0]bias_2,
    output reg [31:0]bias_3
    );
    
    always@(posedge CLK) begin
        if(rst == 1) begin
            bias_0 <= 0;
            bias_1 <= 0;
            bias_2 <= 0;
            bias_3 <= 0;
        end
        else begin
            if(en) begin
                bias_0 <= bdata_0;
                bias_1 <= bdata_1;
                bias_2 <= bdata_2;
                bias_3 <= bdata_3;
            end
            else begin
                bias_0 <= bias_0;
                bias_1 <= bias_1;
                bias_2 <= bias_2;
                bias_3 <= bias_3;
            end
        end
    end
    
endmodule