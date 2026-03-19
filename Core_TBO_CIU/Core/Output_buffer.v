`timescale 1ns / 1ps

// delay = 1 cycle

module Output_buffer(
    input CLK,
    input rst,
    input en,
    input [63:0] acc_out,
    output reg [63:0] core_out
    );
    
    ////////// output //////////
    reg [63:0] out_0;
    always@(posedge CLK) begin
        if(rst) begin
            core_out <= 0;
            out_0 <= 0;
        end
        else begin
            core_out <= out_0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            out_0 <= 0;
        end
        else begin
            if(en) begin
                out_0 <= acc_out;
            end
            else begin
                out_0 <= out_0;
            end
        end
    end
    ////////// output end //////////
    
endmodule