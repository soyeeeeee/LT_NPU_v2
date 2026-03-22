`timescale 1ns / 1ps

module Param_decoder(
    input CLK,
    input rst, // global reset

    ////////// IS/VLIW input //////////
    // VLIW
    input [132:0] VLIW_num,
    // IS
    input [16:0] output_combined, // {glb_out_mode, width_out, ch_out}
    input [16:0] input_combined, // {glb_in_mode, width_in, ch_in}
    input [5:0] double_buffer_sel, // {output_glb, input_glb, W_storage[1:0], B_storage[1:0]}
    input [7:0] cycle_tile_size,

    ////////// CIU //////////
    // AGU C parameters
    output [15:0] AGU_C_param_1, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_2, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_3, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_4, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_5, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_6, // {AGU_C_initial, tile_size}

    ////////// Tile Buffer Operator //////////
    // control param
    output [22:0] tbo_param, // {tile_sel_cycle, tile_assign}

    ////////// Core //////////
    // control signal
    output [18:0] core_control, // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization, factor_sel[1:0]}
    // AGU initial
    output [28:0] core_AGU_initial_1, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    output [28:0] core_AGU_initial_2, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    output [28:0] core_AGU_initial_3, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    output [28:0] core_AGU_initial_4, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    output [28:0] core_AGU_initial_5, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    output [28:0] core_AGU_initial_6, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    // tile size
    output [29:0] core_tile_param, // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}

    ////////// GLB operator //////////
    // GLB input
    output [53:0] glb_input_param, // {glb_in_mode[53:52], AGU_G_initial[51:38], AGU_T_initial[37:30], glb_width_in[29:23], glb_ch_in[22:15], tile_width_in[14:8], tile_ch_in[7:0]}
    // GLB output
    output [53:0] glb_output_param, // {glb_out_mode[53:52], AGU_G_initial[51:38], AGU_T_initial[37:30], glb_width_out[29:23], glb_ch_out[22:15], tile_width_out[14:8], tile_ch_out[7:0]}

    ////////// prep //////////
    output prep_buffer_sel
    );

    ////////// VLIW decoder //////////
    wire [2:0] tile_sel_cycle;
    wire [8:0] tile_sel_cal;
    VLIW_decoder vliw_decoder(
        .CLK(CLK),
        .rst(rst),
        .VLIW_in(VLIW_num[74:55]),
        .tile_sel_cal(tile_sel_cal),
        .tile_sel_cycle(tile_sel_cycle)
    );
    ////////// VLIW decoder end //////////

    ////////// cycle initial //////////
    reg [47:0] cycle_initial;
    always@(*) begin
        cycle_initial[47:40] = 0;
        cycle_initial[39:32] = cycle_tile_size + 1;
        cycle_initial[31:24] = ((cycle_tile_size + 1) << 1);
        cycle_initial[23:16] = ((cycle_tile_size + 1) << 1) + cycle_tile_size + 1;
        cycle_initial[15:8]  = ((cycle_tile_size + 1) << 2);
        cycle_initial[7:0]   = ((cycle_tile_size + 1) << 2) + cycle_tile_size + 1;
    end
    ////////// cycle initial end //////////

    ////////// AGU initial //////////
    // AGU_O_initial
    reg [7:0] AGU_O_initial_1, AGU_O_initial_2, AGU_O_initial_3, AGU_O_initial_4, AGU_O_initial_5, AGU_O_initial_6;
    always@(*) begin
        if(VLIW_num[132:130] == 3'd2 || VLIW_num[132:130] == 3'd4) begin
            AGU_O_initial_1 = 0;
            AGU_O_initial_2 = cycle_tile_size + 1;
            AGU_O_initial_3 = ((cycle_tile_size + 1) << 1);
            AGU_O_initial_4 = ((cycle_tile_size + 1) << 1) + cycle_tile_size + 1;
            AGU_O_initial_5 = ((cycle_tile_size + 1) << 2);
            AGU_O_initial_6 = ((cycle_tile_size + 1) << 2) + cycle_tile_size + 1;
        end
        else begin
            AGU_O_initial_1 = 0;
            AGU_O_initial_2 = 0;
            AGU_O_initial_3 = 0;
            AGU_O_initial_4 = 0;
            AGU_O_initial_5 = 0;
            AGU_O_initial_6 = 0;
        end
    end
    // AGU_W, AGU_B, AGU_G, AGU_T
    reg [12:0] AGU_W_initial;
    reg [7:0] AGU_B_initial;
    reg [13:0] input_AGU_G_initial, output_AGU_G_initial;
    reg [7:0] input_AGU_T_initial, output_AGU_T_initial;

    always@(*) begin
        // output AGU_G
        if(double_buffer_sel[5]) begin
            output_AGU_G_initial = 14'd8192 + VLIW_num[32:19];
        end
        else begin
            output_AGU_G_initial = 14'd0 + VLIW_num[32:19];
        end
        // input AGU_G
        if(double_buffer_sel[4]) begin
            input_AGU_G_initial = 14'd8192 + VLIW_num[54:41];
        end
        else begin
            input_AGU_G_initial = 14'd0 + VLIW_num[54:41];
        end
        // AGU_W
        case(double_buffer_sel[3:2])
            2'b11, 2'b10: begin
                AGU_W_initial = 13'd4096 + VLIW_num[125:113];
            end
            2'b01: begin
                AGU_W_initial = 13'd2048 + VLIW_num[125:113];
            end
            2'b00: begin
                AGU_W_initial = 13'd0 + VLIW_num[125:113];
            end
            default: begin
                AGU_W_initial = 13'd0 + VLIW_num[125:113];
            end
        endcase
        // AGU_B
        case(double_buffer_sel[1:0])
            2'b11, 2'b10: begin
                AGU_B_initial = 8'd128 + VLIW_num[112:105];
            end
            2'b01: begin
                AGU_B_initial = 8'd64 + VLIW_num[112:105];
            end
            2'b00: begin
                AGU_B_initial = 8'd0 + VLIW_num[112:105];
            end
            default: begin
                AGU_B_initial = 8'd0 + VLIW_num[112:105];
            end
        endcase
        input_AGU_T_initial = VLIW_num[40:33];
        output_AGU_T_initial = VLIW_num[18:11];
    end
    ////////// AGU initial end //////////

    ////////// GLB param decode //////////
    // break down combined parameters
    wire [6:0] width_out, width_in;
    wire [7:0] ch_out, ch_in;
    assign width_out = output_combined[14:8];
    assign ch_out = output_combined[7:0];
    assign width_in = input_combined[14:8];
    assign ch_in = input_combined[7:0];
    // decode
    reg [6:0] glb_width_out, glb_width_in;
    reg [7:0] glb_ch_out, glb_ch_in;
    reg [6:0] tile_width_out, tile_width_in;
    reg [7:0] tile_ch_out, tile_ch_in;
    always@(*) begin
        // decode output parameters
        case(output_combined[16:15]) // glb_out_mode
            0: begin // broadcast mode
                glb_width_out = width_out;
                glb_ch_out = ch_out;
                tile_width_out = width_out;
                tile_ch_out = ch_out;
            end
            1: begin // multi-cast mode
                glb_width_out = width_out;
                glb_ch_out = ((ch_out + 1) << 2) + ((ch_out + 1) << 1) - 1;
                tile_width_out = width_out;
                tile_ch_out = ch_out;
            end
            2: begin // post-processing mode
                glb_width_out = width_out;
                glb_ch_out = ch_out;
                tile_width_out = width_out;
                tile_ch_out = ch_out;
            end
            default: begin
                glb_width_out = width_out;
                glb_ch_out = ch_out;
                tile_width_out = width_out;
                tile_ch_out = ch_out;
            end
        endcase
        // decode input parameters
        case(input_combined[16:15]) // glb_in_mode
            0: begin // uni-write mode
                glb_width_in = width_in;
                glb_ch_in = ch_in;
                tile_width_in = width_in;
                tile_ch_in = ch_in;
            end
            1: begin // multi-write mode
                glb_width_in = width_in;
                glb_ch_in = ((ch_in + 1) << 2) + ((ch_in + 1) << 1) - 1;
                tile_width_in = width_in;
                tile_ch_in = ch_in;
            end
            default: begin
                glb_width_in = width_in;
                glb_ch_in = ch_in;
                tile_width_in = width_in;
                tile_ch_in = ch_in;
            end
        endcase
    end

    ////////// combine control signals //////////
    // CIU control
    assign AGU_C_param_1 = {cycle_initial[47:40], cycle_tile_size};
    assign AGU_C_param_2 = {cycle_initial[39:32], cycle_tile_size};
    assign AGU_C_param_3 = {cycle_initial[31:24], cycle_tile_size};
    assign AGU_C_param_4 = {cycle_initial[23:16], cycle_tile_size};
    assign AGU_C_param_5 = {cycle_initial[15:8], cycle_tile_size};
    assign AGU_C_param_6 = {cycle_initial[7:0], cycle_tile_size};
    // TBO control
    assign tbo_param = {tile_sel_cycle, VLIW_num[74:55]};
    // Core control
    assign core_control = {VLIW_num[132:126], tile_sel_cal, VLIW_num[9:7]};
    assign core_AGU_initial_1 = {AGU_W_initial, AGU_B_initial, AGU_O_initial_1};
    assign core_AGU_initial_2 = {AGU_W_initial, AGU_B_initial, AGU_O_initial_2};
    assign core_AGU_initial_3 = {AGU_W_initial, AGU_B_initial, AGU_O_initial_3};
    assign core_AGU_initial_4 = {AGU_W_initial, AGU_B_initial, AGU_O_initial_4};
    assign core_AGU_initial_5 = {AGU_W_initial, AGU_B_initial, AGU_O_initial_5};
    assign core_AGU_initial_6 = {AGU_W_initial, AGU_B_initial, AGU_O_initial_6};
    assign core_tile_param = VLIW_num[104:75];
    // GLB control
    assign glb_input_param = {input_combined[16:15], input_AGU_G_initial, input_AGU_T_initial, glb_width_in, glb_ch_in, tile_width_in, tile_ch_in};
    assign glb_output_param = {output_combined[16:15], output_AGU_G_initial, output_AGU_T_initial, glb_width_out, glb_ch_out, tile_width_out, tile_ch_out};
    // prep control
    assign prep_buffer_sel = VLIW_num[10];
    ////////// combine control signals end //////////

endmodule