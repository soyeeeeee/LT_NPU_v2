`timescale 1ns / 1ps

module Core_TBO_CIU(
    input CLK,
    input rst, // global reset

    ////////// CIU //////////
    input cycle_en,
    // AGU C parameters
    input [15:0] AGU_C_param, // {AGU_C_initial, tile_size}
    // cycle
    input [71:0] stream_a_in,
    output [71:0] stream_a_out,
    input [71:0] stream_b_in,
    output [71:0] stream_b_out,
    // load
    input [72:0] glb_ciu_load_bus, // {valid_load, addr_load, din_load}
    // write back
    input [8:0] glb_ciu_wb_bus, // {en_wb, addr_wb_in}
    output [64:0] ciu_glb_wb_bus, // {data_valid, CIU_wb}
    // cycle busy
    output cycle_busy,

    ////////// Tile Buffer Operator //////////
    // control param
    input [22:0] tbo_param, // {tile_sel_cycle, tile_assign}

    ////////// Core //////////
    input core_en,
    // control signal, AGU initial, tile size, requantization
    input [16:0] core_control,  // {mode_in[16:14], stride_X_in[13:12], ReLU_en_in[11], padding[10], tile_sel_in[9:1], requantization[0]}
    input [28:0] core_AGU_initial, // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    input [29:0] core_tile_param, // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
    input [60:0] requant_param, // {factor[15:0], zp[39:0], shift[4:0]}
    
    // W_storage
    input [79:0] weight_loader_w_storage_bus, // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
    // B_storage
    input [74:0] weight_loader_b_storage_bus, // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
    // core busy
    output core_busy,
    ////////// debug //////////
    output [15:0] debug_core_control,
    output [63:0] debug_tbo_core_cal_data_1,
    output [63:0] debug_tbo_core_cal_data_2,
    output [63:0] debug_tbo_core_cal_data_3,
    output [63:0] debug_tbo_core_cal_data_4,
    output [63:0] debug_tbo_core_cal_data_5,
    output [63:0] debug_tbo_core_cal_data_6,
    output [63:0] debug_w_storage_core_data_0,
    output [63:0] debug_b_storage_core_data_0,
    output [72:0] debug_core_tbo_store_bus,
    output [7:0] debug_addr_cal
    );

    ////////// CIU //////////
    // cycle bus
    wire [40:0] ciu_tbo_cycle_bus_a, ciu_tbo_cycle_bus_b;
    wire [31:0] tbo_ciu_cycle_data;
    // load bus
    wire [40:0] ciu_tbo_load_bus;
    // write back bus
    wire [8:0] ciu_tbo_wb_bus;
    wire [31:0] tbo_ciu_wb_data;
    // CIU instantiation
    CIU ciu(
        .CLK(CLK),
        .rst(rst), // global reset, will reset whole CIU, including AGU and cycle controller
        .cycle_en(cycle_en),
        // cycle
        .AGU_C_param(AGU_C_param), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_in),
        .stream_a_out(stream_a_out),
        .stream_b_in(stream_b_in),
        .stream_b_out(stream_b_out),
        .ciu_tbo_cycle_bus_a(ciu_tbo_cycle_bus_a), // {valid_cycle_a, addr_cycle_a, din_cycle_a}
        .ciu_tbo_cycle_bus_b(ciu_tbo_cycle_bus_b), // {valid_cycle_b, addr_cycle_b, din_cycle_b}
        .tbo_ciu_cycle_data(tbo_ciu_cycle_data),
        // load
        .glb_ciu_load_bus(glb_ciu_load_bus), // {valid_load, addr_load, din_load}
        .ciu_tbo_load_bus(ciu_tbo_load_bus), // {valid_load, addr_load, din_load}
        // write back
        .glb_ciu_wb_bus(glb_ciu_wb_bus), // {en_wb, addr_wb_in}
        .ciu_tbo_wb_bus(ciu_tbo_wb_bus), // {en_wb, addr_wb}
        .tbo_ciu_wb_data(tbo_ciu_wb_data),
        .ciu_glb_wb_bus(ciu_glb_wb_bus), // {data_valid, CIU_wb}
        // busy
        .cycle_busy(cycle_busy)
    );
    ////////// CIU end //////////

    ////////// Tile Buffer Operator //////////
    // tbo bus
    wire [8:0] core_tbo_cal_bus;
    wire [31:0] tbo_core_cal_data_1;
    wire [31:0] tbo_core_cal_data_2;
    wire [31:0] tbo_core_cal_data_3;
    wire [31:0] tbo_core_cal_data_4;
    wire [31:0] tbo_core_cal_data_5;
    wire [31:0] tbo_core_cal_data_6;
    wire [40:0] core_tbo_store_bus;
    // TBO instantiation
    Tile_buffer_operator tbo(
        .clka(CLK),
        .clkb(CLK),
        .rst(rst),
        // Control param
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}
        // load
        .ciu_tbo_load_bus(ciu_tbo_load_bus), // {valid, addr, din}
        // cycle
        .ciu_tbo_cycle_bus_a(ciu_tbo_cycle_bus_a), // {valid, addr, din}
        .ciu_tbo_cycle_bus_b(ciu_tbo_cycle_bus_b), // {valid, addr, din}
        .tbo_ciu_cycle_data(tbo_ciu_cycle_data),
        // wb
        .ciu_tbo_wb_bus(ciu_tbo_wb_bus), // {en_wb, addr_wb}
        .tbo_ciu_wb_data(tbo_ciu_wb_data),
        // cal
        .core_tbo_cal_bus(core_tbo_cal_bus), // {valid_cal, addr_cal}
        .tbo_core_cal_data_1(tbo_core_cal_data_1),
        .tbo_core_cal_data_2(tbo_core_cal_data_2),
        .tbo_core_cal_data_3(tbo_core_cal_data_3),
        .tbo_core_cal_data_4(tbo_core_cal_data_4),
        .tbo_core_cal_data_5(tbo_core_cal_data_5),
        .tbo_core_cal_data_6(tbo_core_cal_data_6),
        // store
        .core_tbo_store_bus(core_tbo_store_bus) // {valid, addr, din}
    );
    ////////// Tile Buffer Operator end //////////

    ////////// Core //////////
    // W_storage
    wire [12:0] core_w_storage_bus; // {W_storage_en, Waddr[11:0]}
    wire [127:0] w_storage_core_data; // {data_0, data_1, data_2, data_3}
    // B_storage
    wire [8:0] core_b_storage_bus; // {B_storage_en, baddr[7:0]}
    wire [127:0] b_storage_core_data; // {data_0, data_1, data_2, data_3}

    Core core(
        .CLK(CLK), .rst(rst), .en(core_en),
        // control signal
        .core_control(core_control), // {mode_in[15:13], stride_X_in[12:11], ReLU_en_in[10], padding[9], tile_sel_in[8:0]}
        // AGU initial
        .core_AGU_initial(core_AGU_initial), // {AGU_W_initial[27:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        // tile size
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        // requantization
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        // cal tile buffer
        .core_tbo_cal_bus(core_tbo_cal_bus), // {valid_cal, addr_cal}
        .tbo_core_cal_data_1(tbo_core_cal_data_1),
        .tbo_core_cal_data_2(tbo_core_cal_data_2),
        .tbo_core_cal_data_3(tbo_core_cal_data_3),
        .tbo_core_cal_data_4(tbo_core_cal_data_4),
        .tbo_core_cal_data_5(tbo_core_cal_data_5),
        .tbo_core_cal_data_6(tbo_core_cal_data_6),
        // W_storage
        .core_w_storage_bus(core_w_storage_bus), // {W_storage_en, Waddr[11:0]}
        .w_storage_core_data_0(w_storage_core_data[127:96]),
        .w_storage_core_data_1(w_storage_core_data[95:64]),
        .w_storage_core_data_2(w_storage_core_data[63:32]),
        .w_storage_core_data_3(w_storage_core_data[31:0]),
        // B_storage
        .core_b_storage_bus(core_b_storage_bus), // {B_storage_en, baddr[7:0]}
        .b_storage_core_data_0(b_storage_core_data[127:96]),
        .b_storage_core_data_1(b_storage_core_data[95:64]),
        .b_storage_core_data_2(b_storage_core_data[63:32]),
        .b_storage_core_data_3(b_storage_core_data[31:0]),
        // store tile buffer
        .core_tbo_store_bus(core_tbo_store_bus), // {valid, addr, din}
        // core busy
        .core_busy(core_busy),
        // debug
        .debug_core_control(debug_core_control),
        .debug_tbo_core_cal_data_1(debug_tbo_core_cal_data_1),
        .debug_tbo_core_cal_data_2(debug_tbo_core_cal_data_2),
        .debug_tbo_core_cal_data_3(debug_tbo_core_cal_data_3),
        .debug_tbo_core_cal_data_4(debug_tbo_core_cal_data_4),
        .debug_tbo_core_cal_data_5(debug_tbo_core_cal_data_5),
        .debug_tbo_core_cal_data_6(debug_tbo_core_cal_data_6),
        .debug_w_storage_core_data_0(debug_w_storage_core_data_0),
        .debug_b_storage_core_data_0(debug_b_storage_core_data_0),
        .debug_core_tbo_store_bus(debug_core_tbo_store_bus),
        .debug_addr_cal(debug_addr_cal)
    );
    ////////// Core end //////////

    ////////// W_storage //////////
    W_storage w_storage_0(
        .CLK(CLK),
        .rst(rst),
        // port a
        .ena(weight_loader_w_storage_bus[79]),
        .wea(weight_loader_w_storage_bus[79]),
        .addra(weight_loader_w_storage_bus[75:64]),
        .dina(weight_loader_w_storage_bus[63:0]),
        // port b
        .enb(core_w_storage_bus[12]),
        .regceb(1'b1),
        .addrb(core_w_storage_bus[11:0]),
        .doutb(w_storage_core_data[127:96])
    );
    W_storage w_storage_1(
        .CLK(CLK),
        .rst(rst),
        // port a
        .ena(weight_loader_w_storage_bus[78]),
        .wea(weight_loader_w_storage_bus[78]),
        .addra(weight_loader_w_storage_bus[75:64]),
        .dina(weight_loader_w_storage_bus[63:0]),
        // port b
        .enb(core_w_storage_bus[12]),
        .regceb(1'b1),
        .addrb(core_w_storage_bus[11:0]),
        .doutb(w_storage_core_data[95:64])
    );
    W_storage w_storage_2(
        .CLK(CLK),
        .rst(rst),
        // port a
        .ena(weight_loader_w_storage_bus[77]),
        .wea(weight_loader_w_storage_bus[77]),
        .addra(weight_loader_w_storage_bus[75:64]),
        .dina(weight_loader_w_storage_bus[63:0]),
        // port b
        .enb(core_w_storage_bus[12]),
        .regceb(1'b1),
        .addrb(core_w_storage_bus[11:0]),
        .doutb(w_storage_core_data[63:32])
    );
    W_storage w_storage_3(
        .CLK(CLK),
        .rst(rst),
        // port a
        .ena(weight_loader_w_storage_bus[76]),
        .wea(weight_loader_w_storage_bus[76]),
        .addra(weight_loader_w_storage_bus[75:64]),
        .dina(weight_loader_w_storage_bus[63:0]),
        // port b
        .enb(core_w_storage_bus[12]),
        .regceb(1'b1),
        .addrb(core_w_storage_bus[11:0]),
        .doutb(w_storage_core_data[31:0])
    );
    ////////// W_storage end //////////

    ////////// B_storage //////////
    B_storage b_storage_0(
        .clka(CLK),
        .clkb(CLK),
        // port a
        .ena(weight_loader_b_storage_bus[74]),
        .wea(weight_loader_b_storage_bus[74]),
        .addra(weight_loader_b_storage_bus[70:64]),
        .dina(weight_loader_b_storage_bus[63:0]),
        // port b
        .enb(core_b_storage_bus[8]),
        .regceb(1'b1),
        .addrb(core_b_storage_bus[7:0]),
        .doutb(b_storage_core_data[127:96])
    );
    B_storage b_storage_1(
        .clka(CLK),
        .clkb(CLK),
        // port a
        .ena(weight_loader_b_storage_bus[73]),
        .wea(weight_loader_b_storage_bus[73]),
        .addra(weight_loader_b_storage_bus[70:64]),
        .dina(weight_loader_b_storage_bus[63:0]),
        // port b
        .enb(core_b_storage_bus[8]),
        .regceb(1'b1),
        .addrb(core_b_storage_bus[7:0]),
        .doutb(b_storage_core_data[95:64])
    );
    B_storage b_storage_2(
        .clka(CLK),
        .clkb(CLK),
        // port a
        .ena(weight_loader_b_storage_bus[72]),
        .wea(weight_loader_b_storage_bus[72]),
        .addra(weight_loader_b_storage_bus[70:64]),
        .dina(weight_loader_b_storage_bus[63:0]),
        // port b
        .enb(core_b_storage_bus[8]),
        .regceb(1'b1),
        .addrb(core_b_storage_bus[7:0]),
        .doutb(b_storage_core_data[63:32])
    );
    B_storage b_storage_3(
        .clka(CLK),
        .clkb(CLK),
        // port a
        .ena(weight_loader_b_storage_bus[71]),
        .wea(weight_loader_b_storage_bus[71]),
        .addra(weight_loader_b_storage_bus[70:64]),
        .dina(weight_loader_b_storage_bus[63:0]),
        // port b
        .enb(core_b_storage_bus[8]),
        .regceb(1'b1),
        .addrb(core_b_storage_bus[7:0]),
        .doutb(b_storage_core_data[31:0])
    );
    ////////// B_storage end //////////

endmodule