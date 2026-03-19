`timescale 1ns / 1ps

module CIU(
    input CLK,
    input rst, // global reset, will reset whole CIU, including AGU and cycle controller
    input cycle_en,
    ////////// AGU parameters //////////
    input [15:0] AGU_C_param, // {AGU_C_initial, tile_size} remember to split these two signal to different control parameters
    ////////// cycle //////////
    // CI buffer
    input [39:0] stream_a_in,
    output [39:0] stream_a_out,
    input [39:0] stream_b_in,
    output [39:0] stream_b_out,
    // tile buffer operator
    output [40:0] ciu_tbo_cycle_bus_a, // {valid_cycle_a, addr_cycle_a, din_cycle_a}
    output [40:0] ciu_tbo_cycle_bus_b, // {valid_cycle_b, addr_cycle_b, din_cycle_b}
    input [31:0] tbo_ciu_cycle_data,
    ////////// load //////////
    input [40:0] glb_ciu_load_bus, // {valid_load, addr_load, din_load}
    output [40:0] ciu_tbo_load_bus, // {valid_load, addr_load, din_load}
    ////////// write back //////////
    input [8:0] glb_ciu_wb_bus, // {en_wb, addr_wb_in}
    output [8:0] ciu_tbo_wb_bus, // {en_wb, addr_wb}
    input [31:0] tbo_ciu_wb_data,
    output [32:0] ciu_glb_wb_bus, // {data_valid, CIU_wb}
    ////////// busy //////////
    output cycle_busy
    );

    ////////// SR //////////
    wire [7:0] cycle_SR;
    ////////// SR end //////////

    ////////// signals for tile buffer operator //////////
    wire [7:0] caddr;
    assign ciu_tbo_cycle_bus_a[40] = cycle_SR[5] | cycle_SR[6];
    assign ciu_tbo_cycle_bus_b[40] = cycle_SR[5] | cycle_SR[6] | cycle_SR[7];
    assign ciu_tbo_cycle_bus_a[39:32] = (cycle_SR[1]) ? caddr : stream_a_in[39:32];
    assign ciu_tbo_cycle_bus_b[39:32] = stream_b_in[39:32];
    assign ciu_tbo_cycle_bus_a[31:0] = stream_a_in[31:0];
    assign ciu_tbo_cycle_bus_b[31:0] = stream_b_in[31:0];
    ////////// signals for tile buffer operator end //////////

    ////////// AGU //////////
    wire set;
    wire AGU_C_done;
    wire cycle_rst;
    AGU_C agu_c(
        .CLK(CLK),
        .en(cycle_SR[0]),
        .rst(cycle_rst),
        .set(set),
        .AGU_C_param(AGU_C_param),
        .caddr(caddr), // output addr to tile buffer
        .done(AGU_C_done)
    );
    ////////// AGU end //////////

    ////////// cycle controller //////////
    Cycle_controller cycle_controller(
        .CLK(CLK),
        .rst(rst),
        .en(cycle_en),
        .AGU_C_done(AGU_C_done),
        .set(set),
        .cycle_rst(cycle_rst),
        .cycle_SR(cycle_SR),
        .cycle_busy(cycle_busy)
    );
    ////////// cycle controller end //////////

    ////////// stream buffer //////////
    wire [39:0] stream_initial;
    Stream_buffer stream_buffer(
        .CLK(CLK),
        .rst(cycle_rst),
        .en(cycle_SR[3]),
        .caddr(caddr),
        .tbo_ciu_cycle_data(tbo_ciu_cycle_data),
        .stream_initial(stream_initial)
    );
    ////////// stream buffer end //////////

    ////////// CI buffer //////////
    // A
    wire CI_buffer_A_en = cycle_SR[4] | cycle_SR[5] | cycle_SR[6] | cycle_SR[7];
    wire mux_sel_a = cycle_SR[4];
    CI_buffer CI_buffer_A(
        .CLK(CLK),
        .rst(cycle_rst),
        .en(CI_buffer_A_en),
        .mux_sel(mux_sel_a),
        .stream_in(stream_a_in),
        .stream_initial(stream_initial),
        .stream_out(stream_a_out)
    );
    // B
    wire CI_buffer_B_en = cycle_SR[4] | cycle_SR[5] | cycle_SR[6] | cycle_SR[7];
    wire mux_sel_b = cycle_SR[4];
    CI_buffer CI_buffer_B(
        .CLK(CLK),
        .rst(cycle_rst),
        .en(CI_buffer_B_en),
        .mux_sel(mux_sel_b),
        .stream_in(stream_b_in),
        .stream_initial(stream_initial),
        .stream_out(stream_b_out)
    );
    ////////// CI buffer end //////////

    ////////// CIU load buffer //////////
    CIU_load_buffer CIU_load_buffer(
        .CLK(CLK),
        .rst(rst),
        .glb_ciu_load_bus(glb_ciu_load_bus),
        .ciu_tbo_load_bus(ciu_tbo_load_bus)
    );
    ////////// CIU load buffer end //////////

    ////////// CIU write buffer //////////
    CIU_wb_buffer CIU_wb_buffer(
        .CLK(CLK),
        .rst(rst),
        .glb_ciu_wb_bus(glb_ciu_wb_bus),
        // output data
        .ciu_glb_wb_bus(ciu_glb_wb_bus),
        // tile buffer
        .tbo_ciu_wb_data(tbo_ciu_wb_data),
        .ciu_tbo_wb_bus(ciu_tbo_wb_bus)
    );
    ////////// CIU write buffer end //////////
endmodule