`timescale 1ns / 1ps

// delay = 1 cycle

module Output_buffer(
    input CLK,
    input rst,
    input en,
    input [31:0] cal_result,
    output reg [31:0] core_out
    );
    
    ////////// output //////////
    reg [31:0] out_0;
    always@(posedge CLK) begin
        if(rst) begin
            core_out <= 0;
            out_0 <= 0;
        end
        else begin
            core_out <= out_0;
            if(en) begin
                out_0 <= cal_result;
            end
            else begin
                out_0 <= out_0;
            end
        end
    end
    ////////// output end //////////
    
endmodule