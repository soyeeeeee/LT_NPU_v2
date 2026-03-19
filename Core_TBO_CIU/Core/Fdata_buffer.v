`timescale 1ns / 1ps

// delay = 1 cycle

module Fdata_buffer(
    input CLK,
    input rst,
    input en,
    input set,
    input [8:0]tile_sel, //3*tile
    input [2:0]mode_in, //function
    input boundary,
    input [31:0]tile_1,
    input [31:0]tile_2,
    input [31:0]tile_3,
    input [31:0]tile_4,
    input [31:0]tile_5,
    input [31:0]tile_6,
    output reg [31:0]fdata_0,
    output reg [31:0]fdata_1,
    output reg [31:0]fdata_2,
    output reg [31:0]fdata_3
    );
    
    //cluster mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;

    ////////// input buffer //////////
    reg [2:0] mode;
    always@(posedge CLK) begin
        if(rst) begin
            mode <= 0;
        end
        else if(set) begin
            mode <= mode_in;
        end
        else begin
            mode <= mode;
        end
    end
    ////////// input buffer end //////////
     
    ////////// boundary delay //////////
    reg boundary_buffer_0, boundary_buffer_1;
    always@(posedge CLK) begin
        if(rst) begin
            boundary_buffer_0 <= 0;
            boundary_buffer_1 <= 0;
        end
        else begin
            boundary_buffer_0 <= boundary;
            boundary_buffer_1 <= boundary_buffer_0;
        end
    end
    
    //tile selecting
    reg [31:0]mux_out_0,mux_out_1,mux_out_2;
    always@(*) begin
        //fdata_0
        case(tile_sel[8:6])
            1: mux_out_0 = tile_1;
            2: mux_out_0 = tile_2;
            3: mux_out_0 = tile_3;
            4: mux_out_0 = tile_4;
            5: mux_out_0 = tile_5;
            6: mux_out_0 = tile_6;
            default: mux_out_0 = 0; //tile_sel = 0
        endcase
        //fdata_1
        case(tile_sel[5:3])
            1: mux_out_1 = tile_1;
            2: mux_out_1 = tile_2;
            3: mux_out_1 = tile_3;
            4: mux_out_1 = tile_4;
            5: mux_out_1 = tile_5;
            6: mux_out_1 = tile_6;
            default: mux_out_1 = 0; //tile_sel = 0
        endcase
        //fdata_2
        case(tile_sel[2:0])
            1: mux_out_2 = tile_1;
            2: mux_out_2 = tile_2;
            3: mux_out_2 = tile_3;
            4: mux_out_2 = tile_4;
            5: mux_out_2 = tile_5;
            6: mux_out_2 = tile_6;
            default: mux_out_2 = 0; //tile_sel = 0
        endcase
    end
    
    //output
    always@(posedge CLK) begin
        if(rst) begin
            fdata_0 <= 32'd0;
            fdata_1 <= 32'd0;
            fdata_2 <= 32'd0;
            fdata_3 <= 32'd0;
        end
        else if(en) begin
            if (mode == GAP) begin
                //Pass-through
                fdata_0 <= tile_3;
                fdata_1 <= tile_4;
                fdata_2 <= tile_5;
                fdata_3 <= tile_6;
            end
            else begin
                // (Conv/Pool/DW) + Padding
                fdata_0 <= (boundary_buffer_1) ? 32'd0 : mux_out_0;
                fdata_1 <= (boundary_buffer_1) ? 32'd0 : mux_out_1;
                fdata_2 <= (boundary_buffer_1) ? 32'd0 : mux_out_2;
                fdata_3 <= 32'd0;
            end
        end
        else begin
            fdata_0 <= fdata_0;
            fdata_1 <= fdata_1;
            fdata_2 <= fdata_2;
            fdata_3 <= fdata_3;
        end
    end
    
endmodule