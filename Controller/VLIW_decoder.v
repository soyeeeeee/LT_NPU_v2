`timescale 1ns / 1ps

module VLIW_decoder(
    input CLK,
    input rst,
    input [19:0] VLIW_in,
    output reg [8:0] tile_sel_cal,
    output reg [2:0] tile_sel_cycle
    );

    ////////// decode tile sel //////////
    wire [19:0] tile_assign = VLIW_in[19:0];
    reg [5:0] cal_0, cal_1, cal_2;
    reg [5:0] cycle;
    always@(posedge CLK) begin
        if(rst) begin
            tile_sel_cycle <= 0;
        end
        else begin
            case(cycle)
                6'b000001: tile_sel_cycle <= 3'b001;
                6'b000010: tile_sel_cycle <= 3'b010;
                6'b000100: tile_sel_cycle <= 3'b011;
                6'b001000: tile_sel_cycle <= 3'b100;
                6'b010000: tile_sel_cycle <= 3'b101;
                6'b100000: tile_sel_cycle <= 3'b110;
                default: tile_sel_cycle <= 0;
            endcase
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            tile_sel_cal <= 0;
        end
        else begin
            case(cal_0)
                6'b000001: tile_sel_cal[8:6] <= 3'b001;
                6'b000010: tile_sel_cal[8:6] <= 3'b010;
                6'b000100: tile_sel_cal[8:6] <= 3'b011;
                6'b001000: tile_sel_cal[8:6] <= 3'b100;
                6'b010000: tile_sel_cal[8:6] <= 3'b101;
                6'b100000: tile_sel_cal[8:6] <= 3'b110;
                default: tile_sel_cal[8:6] <= 0;
            endcase
            case(cal_1)
                6'b000001: tile_sel_cal[5:3] <= 3'b001;
                6'b000010: tile_sel_cal[5:3] <= 3'b010;
                6'b000100: tile_sel_cal[5:3] <= 3'b011;
                6'b001000: tile_sel_cal[5:3] <= 3'b100;
                6'b010000: tile_sel_cal[5:3] <= 3'b101;
                6'b100000: tile_sel_cal[5:3] <= 3'b110;
                default: tile_sel_cal[5:3] <= 0;
            endcase
            case(cal_2)
                6'b000001: tile_sel_cal[2:0] <= 3'b001;
                6'b000010: tile_sel_cal[2:0] <= 3'b010;
                6'b000100: tile_sel_cal[2:0] <= 3'b011;
                6'b001000: tile_sel_cal[2:0] <= 3'b100;
                6'b010000: tile_sel_cal[2:0] <= 3'b101;
                6'b100000: tile_sel_cal[2:0] <= 3'b110;
                default: tile_sel_cal[2:0] <= 0;
            endcase
        end
    end
    always@(*) begin
        cal_0 = 0;
        cal_1 = 0;
        cal_2 = 0;
        cycle = 0;
        case(tile_assign[19:17]) // tile 1
            3'd1: begin
                cal_0[0] = 1;
                cal_1[0] = 0;
                cal_2[0] = 0;
            end
            3'd2: begin
                cal_0[0] = 0;
                cal_1[0] = 1;
                cal_2[0] = 0;
            end
            3'd3: begin
                cal_0[0] = 0;
                cal_1[0] = 0;
                cal_2[0] = 1;
            end
            3'd5: begin
                cycle[0] = 1;
            end
            default: begin
                cal_0[0] = 0;
                cal_1[0] = 0;
                cal_2[0] = 0;
            end
        endcase
        case(tile_assign[16:14]) // tile 2
            3'd1: begin
                cal_0[1] = 1;
                cal_1[1] = 0;
                cal_2[1] = 0;
            end
            3'd2: begin
                cal_0[1] = 0;
                cal_1[1] = 1;
                cal_2[1] = 0;
            end
            3'd3: begin
                cal_0[1] = 0;
                cal_1[1] = 0;
                cal_2[1] = 1;
            end
            3'd5: begin
                cycle[1] = 1;
            end
            default: begin
                cal_0[1] = 0;
                cal_1[1] = 0;
                cal_2[1] = 0;
            end
        endcase
        case(tile_assign[13:11]) // tile 3
            3'd1: begin
                cal_0[2] = 1;
                cal_1[2] = 0;
                cal_2[2] = 0;
            end
            3'd2: begin
                cal_0[2] = 0;
                cal_1[2] = 1;
                cal_2[2] = 0;
            end
            3'd3: begin
                cal_0[2] = 0;
                cal_1[2] = 0;
                cal_2[2] = 1;
            end
            3'd5: begin
                cycle[2] = 1;
            end
            default: begin
                cal_0[2] = 0;
                cal_1[2] = 0;
                cal_2[2] = 0;
            end
        endcase
        case(tile_assign[10:8]) // tile 4
            3'd1: begin
                cal_0[3] = 1;
                cal_1[3] = 0;
                cal_2[3] = 0;
            end
            3'd2: begin
                cal_0[3] = 0;
                cal_1[3] = 1;
                cal_2[3] = 0;
            end
            3'd3: begin
                cal_0[3] = 0;
                cal_1[3] = 0;
                cal_2[3] = 1;
            end
            3'd5: begin
                cycle[3] = 1;
            end
            default: begin
                cal_0[3] = 0;
                cal_1[3] = 0;
                cal_2[3] = 0;
            end
        endcase
        case(tile_assign[7:5]) // tile 5
            3'd1: begin
                cal_0[4] = 1;
                cal_1[4] = 0;
                cal_2[4] = 0;
            end
            3'd2: begin
                cal_0[4] = 0;
                cal_1[4] = 1;
                cal_2[4] = 0;
            end
            3'd3: begin
                cal_0[4] = 0;
                cal_1[4] = 0;
                cal_2[4] = 1;
            end
            3'd5: begin
                cycle[4] = 1;
            end
            default: begin
                cal_0[4] = 0;
                cal_1[4] = 0;
                cal_2[4] = 0;
            end
        endcase
        case(tile_assign[4:2]) // tile 6
            3'd1: begin
                cal_0[5] = 1;
                cal_1[5] = 0;
                cal_2[5] = 0;
            end
            3'd2: begin
                cal_0[5] = 0;
                cal_1[5] = 1;
                cal_2[5] = 0;
            end
            3'd3: begin
                cal_0[5] = 0;
                cal_1[5] = 0;
                cal_2[5] = 1;
            end
            3'd5: begin
                cycle[5] = 1;
            end
            default: begin
                cal_0[5] = 0;
                cal_1[5] = 0;
                cal_2[5] = 0;
            end
        endcase
    end

    
endmodule