`timescale 1ns / 1ps

//combinational delay = 0 cycle

module Comparator(
    input signed [15:0] comp_a,
    input signed [15:0] comp_b,
    output reg signed [15:0] comp_out
    );
    
    always@(*) begin
        if(comp_a >= comp_b) begin
              comp_out <= comp_a;
        end
        else begin
            comp_out <= comp_b;
        end
    end
    
endmodule