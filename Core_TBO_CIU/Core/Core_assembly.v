`timescale 1ns / 1ps

module Core(
    // basic
    input CLK, input rst, input en,
    ////////// control signal //////////
    input [16:0] core_control, // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
    ////////// AGU initial //////////
    input [28:0] core_AGU_initial, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    ////////// tile size //////////
    input [29:0] core_tile_param, // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
    ////////// requantization //////////
    input [60:0] requant_param, // {factor[15:0], zp[39:0], shift[4:0]}
    ////////// cal tile buffer //////////
    output [8:0] core_tbo_cal_bus, // {valid_cal, addr_cal}
    input [31:0] tbo_core_cal_data_1,
    input [31:0] tbo_core_cal_data_2,
    input [31:0] tbo_core_cal_data_3,
    input [31:0] tbo_core_cal_data_4,
    input [31:0] tbo_core_cal_data_5,
    input [31:0] tbo_core_cal_data_6,
    ////////// W_storage //////////
    output [13:0] core_w_storage_bus, // {W_storage_en, Waddr[12:0]}
    input [31:0] w_storage_core_data_0,
    input [31:0] w_storage_core_data_1,
    input [31:0] w_storage_core_data_2,
    input [31:0] w_storage_core_data_3,
    ////////// B_storage //////////
    output [8:0] core_b_storage_bus, // {B_storage_en, baddr[7:0]}
    input [31:0] b_storage_core_data_0,
    input [31:0] b_storage_core_data_1,
    input [31:0] b_storage_core_data_2,
    input [31:0] b_storage_core_data_3,
    ////////// store tile buffer //////////
    output [40:0] core_tbo_store_bus, // {valid, addr, din}
    ////////// core busy //////////
    output core_busy,
    ////////// debug //////////
    output [15:0] debug_core_control,
    output [31:0] debug_tbo_core_cal_data_1,
    output [31:0] debug_tbo_core_cal_data_2,
    output [31:0] debug_tbo_core_cal_data_3,
    output [31:0] debug_tbo_core_cal_data_4,
    output [31:0] debug_tbo_core_cal_data_5,
    output [31:0] debug_tbo_core_cal_data_6,
    output [31:0] debug_w_storage_core_data_0,
    output [31:0] debug_b_storage_core_data_0,
    output [40:0] debug_core_tbo_store_bus,
    output [7:0] debug_addr_cal
    );
    
    ////////// mode define //////////
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;
    ////////// mode define end //////////

    ////////// input buffer ////////// 
    wire [2:0] mode = core_control[16:14];
    wire [1:0] stride_X = core_control[13:12];
    wire ReLU_en = core_control[11];
    wire padding = core_control[10];
    wire [8:0] tile_sel = core_control[9:1];
    wire requantization = core_control[0];
    wire [15:0] factor = requant_param[60:45];
    wire [39:0] zp = requant_param[44:5];
    wire [4:0] shift = requant_param[4:0];
    wire [6:0] width_in = core_tile_param[29:23];
    wire [7:0] ch_in = core_tile_param[22:15];
    wire [6:0] width_out = core_tile_param[14:8];
    wire [7:0] ch_out = core_tile_param[7:0];
    wire [12:0] AGU_W_initial = core_AGU_initial[28:16];
    wire [7:0] AGU_B_initial = core_AGU_initial[15:8];
    wire [7:0] AGU_O_initial = core_AGU_initial[7:0];
    ////////// input buffer end //////////

    ////////// Controller //////////
    // FSM
    wire Core_en_counter_en;
    wire AGU_O_done;
    wire requant_done;
    wire set;
    wire core_rst; // to reset FSM and other modules when core is done
    wire [12:0] SR_0;
    wire [5:0] SR_1;
    
    // Core controller instance
    Core_controller core_controller(
        .CLK(CLK),
        .en(en),
        .rst(rst),
        // SR control
        .mode_in(mode),
        .requant_done(requant_done),
        // Core en counter control
        .width_out_in(width_out),
        .ch_in_in(ch_in),
        .ch_out_in(ch_out),
        // FSM control
        .AGU_O_done(AGU_O_done),
        // output
        .set(set),
        .SR_0(SR_0),
        .SR_1(SR_1),
        .core_busy(core_busy),
        .core_rst(core_rst)
    );
    ////////// Controller end //////////

    ////////// output signal //////////
    wire [7:0] addr_cal;
    wire [7:0] addr_store;
    wire [31:0] din_store;
    wire [12:0] Waddr;
    wire [7:0] baddr;
    assign core_tbo_cal_bus = {SR_0[4], addr_cal};
    assign core_w_storage_bus = {SR_0[5], Waddr};
    assign core_b_storage_bus = {SR_0[9], baddr};
    assign core_tbo_store_bus = {SR_1[2], addr_store, din_store};
    ////////// output signal end //////////

    ////////// AGU //////////
    // conv1 counter
    reg [1:0] conv_count;
    always@(posedge CLK) begin
        if(core_rst) begin
            conv_count <= 0;
        end
        else begin
            if( SR_0[0] && mode==conv ) begin
                if(conv_count == 2) begin
                    conv_count <= 0;
                end
                else begin
                    conv_count <= conv_count + 1;
                end
            end
            else conv_count <= 0;
        end
    end
    
    // AGU_F
    wire boundary;
    AGU_F agu_f(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[0] && (conv_count==0)),
        .set(set),
        .padding_in(padding),
        .width_in_in(width_in),
        .width_out_in(width_out),
        .ch_in_in(ch_in),
        .ch_out_in(ch_out),
        .mode_in(mode),
        .stride_X_in(stride_X),
        .faddr(addr_cal),
        .boundary(boundary)
    );

    // AGU_W
    AGU_W agu_w(
        .CLK(CLK),
        .en(SR_0[2]),
        .rst(core_rst),
        .set(set),
        .mode_in(mode),
        .AGU_W_initial_in(AGU_W_initial),
        .width_out_in(width_out),
        .ch_in_in(ch_in),
        .ch_out_in(ch_out),
        .Waddr(Waddr)
    );

    // AGU_B
    AGU_B agu_b(
        .CLK(CLK),
        .en(SR_0[6]),
        .rst(core_rst),
        .set(set),
        .mode_in(mode),
        .AGU_B_initial_in(AGU_B_initial),
        .width_out_in(width_out),
        .ch_in_in(ch_in),
        .ch_out_in(ch_out),
        .baddr(baddr)
    );

    // AGU_O
    AGU_O agu_o(
        .CLK(CLK),
        .en(SR_1[0]),
        .rst(core_rst),
        .set(set),
        .AGU_O_initial_in(AGU_O_initial),
        .width_out_in(width_out),
        .ch_out_in(ch_out),
        .oaddr(addr_store),
        .done(AGU_O_done)
    );
    ////////// AGU end //////////

    ////////// Bus and Buffer//////////
    // Fdata buffer
    wire [31:0] fdata_0, fdata_1, fdata_2, fdata_3;
    Fdata_buffer fdata_buffer(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[6]),
        .set(set),
        .tile_sel(tile_sel), //3*tile
        .mode_in(mode), //function
        .boundary(boundary),
        .tile_1(tbo_core_cal_data_1),
        .tile_2(tbo_core_cal_data_2),
        .tile_3(tbo_core_cal_data_3),
        .tile_4(tbo_core_cal_data_4),
        .tile_5(tbo_core_cal_data_5),
        .tile_6(tbo_core_cal_data_6),
        .fdata_0(fdata_0),
        .fdata_1(fdata_1),
        .fdata_2(fdata_2),
        .fdata_3(fdata_3)
    );

    // Array_buffer
    wire [31:0] PE_fin_0, PE_fin_1, PE_fin_2, PE_fin_3;
    Array_buffer array_buffer(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[7]),
        .set(set),
        .fdata_0(fdata_0),
        .fdata_1(fdata_1),
        .fdata_2(fdata_2),
        .fdata_3(fdata_3),
        .mode_in(mode),
        .PE_fin_0(PE_fin_0),
        .PE_fin_1(PE_fin_1),
        .PE_fin_2(PE_fin_2),
        .PE_fin_3(PE_fin_3)
    );

    // W_buffer
    wire [31:0] PE_win_0, PE_win_1, PE_win_2, PE_win_3;
    W_buffer w_buffer(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[7]),
        .wdata_0(w_storage_core_data_0),
        .wdata_1(w_storage_core_data_1),
        .wdata_2(w_storage_core_data_2),
        .wdata_3(w_storage_core_data_3),
        .PE_win_0(PE_win_0),
        .PE_win_1(PE_win_1),
        .PE_win_2(PE_win_2),
        .PE_win_3(PE_win_3)
    );

    // B_buffer
    wire [31:0] bias_0, bias_1, bias_2, bias_3;
    B_buffer b_buffer(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[11]),
        .bdata_0(b_storage_core_data_0),
        .bdata_1(b_storage_core_data_1),
        .bdata_2(b_storage_core_data_2),
        .bdata_3(b_storage_core_data_3),
        .bias_0(bias_0),
        .bias_1(bias_1),
        .bias_2(bias_2),
        .bias_3(bias_3)
    );
    ////////// Bus end //////////

    ////////// PE Array //////////
    wire [63:0] PE_out_0, PE_out_1, PE_out_2, PE_out_3;
    // PE array instance
    PE_array pe_array(
        .CLK(CLK),
        .en(SR_0[8]),
        .rst(core_rst),
        .set(set),
        .mode_in(mode),
        .PE_fin_0(PE_fin_0),
        .PE_fin_1(PE_fin_1),
        .PE_fin_2(PE_fin_2),
        .PE_fin_3(PE_fin_3),
        .PE_win_0(PE_win_0),
        .PE_win_1(PE_win_1),
        .PE_win_2(PE_win_2),
        .PE_win_3(PE_win_3),
        .PE_out_0(PE_out_0),
        .PE_out_1(PE_out_1),
        .PE_out_2(PE_out_2),
        .PE_out_3(PE_out_3)
    );
    ////////// PE Array //////////

    ////////// Accumulator //////////
    wire [23:0] acc_out_0, acc_out_1, acc_out_2, acc_out_3;
    wire acc_done_0, acc_done_1, acc_done_2, acc_done_3;
    Accumulator acc_0(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[12]),
        .set(set),
        .mode_in(mode),
        .load_bias(SR_0[12]),
        .ReLU_en(ReLU_en),
        .ch_in(ch_in),
        .bias(bias_0),
        .PE_out_0_in(PE_out_0[63:48]),
        .PE_out_1_in(PE_out_1[63:48]),
        .PE_out_2_in(PE_out_2[63:48]),
        .PE_out_3_in(PE_out_3[63:48]),
        .acc_out(acc_out_0),
        .acc_done(acc_done_0)
    );
    Accumulator acc_1(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[12]),
        .set(set),
        .mode_in(mode),
        .load_bias(SR_0[12]),
        .ReLU_en(ReLU_en),
        .ch_in(ch_in),
        .bias(bias_1),
        .PE_out_0_in(PE_out_0[47:32]),
        .PE_out_1_in(PE_out_1[47:32]),
        .PE_out_2_in(PE_out_2[47:32]),
        .PE_out_3_in(PE_out_3[47:32]),
        .acc_out(acc_out_1),
        .acc_done(acc_done_1)
    );
    Accumulator acc_2(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[12]),
        .set(set),
        .mode_in(mode),
        .load_bias(SR_0[12]),
        .ReLU_en(ReLU_en),
        .ch_in(ch_in),
        .bias(bias_2),
        .PE_out_0_in(PE_out_0[31:16]),
        .PE_out_1_in(PE_out_1[31:16]),
        .PE_out_2_in(PE_out_2[31:16]),
        .PE_out_3_in(PE_out_3[31:16]),
        .acc_out(acc_out_2),
        .acc_done(acc_done_2)
    );
    Accumulator acc_3(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_0[12]),
        .set(set),
        .mode_in(mode),
        .load_bias(SR_0[12]),
        .ReLU_en(ReLU_en),
        .ch_in(ch_in),
        .bias(bias_3),
        .PE_out_0_in(PE_out_0[15:0]),
        .PE_out_1_in(PE_out_1[15:0]),
        .PE_out_2_in(PE_out_2[15:0]),
        .PE_out_3_in(PE_out_3[15:0]),
        .acc_out(acc_out_3),
        .acc_done(acc_done_3)
    );
    ////////// Accumulator end //////////

    ////////// Requantizer //////////
    wire [7:0] requant_out_0, requant_out_1, requant_out_2, requant_out_3;
    Requantizer requantizer_0(
        .CLK(CLK),
        .rst(core_rst),
        .en(acc_done_0),
        .set(set),
        .requantization(requantization),
        .shift_in(shift),
        .factor(factor),
        .zp(zp),
        .requant_in(acc_out_0),
        .requant_out(requant_out_0),
        .requant_done(requant_done)
    );
    Requantizer requantizer_1(
        .CLK(CLK),
        .rst(core_rst),
        .en(acc_done_1),
        .set(set),
        .requantization(requantization),
        .shift_in(shift),
        .factor(factor),
        .zp(zp),
        .requant_in(acc_out_1),
        .requant_out(requant_out_1)
    );
    Requantizer requantizer_2(
        .CLK(CLK),
        .rst(core_rst),
        .en(acc_done_2),
        .set(set),
        .requantization(requantization),
        .shift_in(shift),
        .factor(factor),
        .zp(zp),
        .requant_in(acc_out_2),
        .requant_out(requant_out_2)
    );
    Requantizer requantizer_3(
        .CLK(CLK),
        .rst(core_rst),
        .en(acc_done_3),
        .set(set),
        .requantization(requantization),
        .shift_in(shift),
        .factor(factor),
        .zp(zp),
        .requant_in(acc_out_3),
        .requant_out(requant_out_3)
    );
    ////////// Requantizer end //////////

    ////////// Output buffer //////////
    Output_buffer output_buffer(
        .CLK(CLK),
        .rst(core_rst),
        .en(SR_1[0]),
        .cal_result({requant_out_0, requant_out_1, requant_out_2, requant_out_3}),
        .core_out(din_store)
    );
    ////////// Output buffer end //////////
    
    ////////// debug //////////
    assign debug_core_control = core_control;
    assign debug_tbo_core_cal_data_1 = tbo_core_cal_data_1;
    assign debug_tbo_core_cal_data_2 = tbo_core_cal_data_2;
    assign debug_tbo_core_cal_data_3 = tbo_core_cal_data_3;
    assign debug_tbo_core_cal_data_4 = tbo_core_cal_data_4;
    assign debug_tbo_core_cal_data_5 = tbo_core_cal_data_5;
    assign debug_tbo_core_cal_data_6 = tbo_core_cal_data_6;
    assign debug_w_storage_core_data_0 = w_storage_core_data_0;
    assign debug_b_storage_core_data_0 = b_storage_core_data_0;
    assign debug_core_tbo_store_bus = core_tbo_store_bus;
    assign debug_addr_cal = addr_cal;
    ////////// debug end //////////
    
endmodule