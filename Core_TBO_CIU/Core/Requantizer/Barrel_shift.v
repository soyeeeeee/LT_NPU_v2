`timescale 1ns / 1ps

// delay = 1 cycle

module Barrel_shift(
    input CLK,
    input en,
    input rst,
    input [4:0] shift,
    input [47:0] bs_in,
    output reg signed [47:0] bs_out
    );
    
    ////////// Stage 1 //////////
    wire [47:0] shift_0;
    assign shift_0 = (shift[4])? bs_in >> 32: bs_in;
    ////////// Stage 1 end //////////

    ////////// Stage 2 //////////
    wire [47:0] shift_1;
    assign shift_1 = (shift[3])? shift_0 >> 16: shift_0;
    ////////// Stage 2 end //////////

    ////////// Stage 3 //////////
    wire [47:0] shift_2;
    assign shift_2 = (shift[2])? shift_1 >> 8: shift_1;
    ////////// Stage 3 end //////////

    ////////// Stage 4 //////////
    wire [47:0] shift_3;
    assign shift_3 = (shift[1])? shift_2 >> 4: shift_2;
    ////////// Stage 4 end //////////

    ////////// Stage 5 //////////
    wire [47:0] shift_4;
    assign shift_4 = (shift[0])? shift_3 >> 1: shift_3;
    ////////// Stage 5 end //////////

    ////////// output reg //////////
    always@(posedge CLK) begin
        if(rst) begin
            bs_out <= 0;
        end
        else begin
            if(en) begin
                bs_out <= shift_4;
            end
            else begin
                bs_out <= bs_out;
            end
        end
    end
    ////////// output reg end //////////
endmodule