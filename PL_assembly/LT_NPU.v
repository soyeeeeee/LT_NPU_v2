`timescale 1ns / 1ps

module LT_NPU(
    ////////// control and CLK //////////
    input CLK,
    // PS control
    input PS_en,
    input PS_rst,
    output PL_busy,

    ////////// DMA and Memory interface //////////
    input  wire [63:0] s_axis_weight_tdata,
    input  wire        s_axis_weight_tvalid,
    output wire        s_axis_weight_tready,

    input  wire [63:0]  s_axis_image_tdata,
    input  wire         s_axis_image_tvalid,
    input  wire         s_axis_image_tlast,
    output wire         s_axis_image_tready,

    ////////// output //////////
    output [3:0] inference_result
    );

    ////////// Controller Assembly //////////
    // global reset
    wire system_rst;
    // busy signals
    wire instruction_loader_busy;
    wire weight_loader_busy;
    wire core_1_busy, core_2_busy, core_3_busy, core_4_busy, core_5_busy, core_6_busy;
    wire glb_input_busy, glb_output_busy;
    wire cycle_1_busy, cycle_2_busy, cycle_3_busy, cycle_4_busy, cycle_5_busy, cycle_6_busy;
    wire cycle_busy = cycle_1_busy | cycle_2_busy | cycle_3_busy | cycle_4_busy | cycle_5_busy | cycle_6_busy;
    wire prep_busy;
    wire posp_busy;
    wire [10:0] lower_busy_bus; // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}
    assign lower_busy_bus = {core_1_busy, core_2_busy, core_3_busy, core_4_busy, core_5_busy, core_6_busy, glb_output_busy, glb_input_busy, cycle_busy, prep_busy, posp_busy};
    // loader control
    wire [21:0] weight_loader_bus; // {en[21], double_buffer_sel[20:19], weight_amount[18:7], bias_amount[6:0]}
    // core control
    wire core_en_1, core_en_2, core_en_3, core_en_4, core_en_5, core_en_6;
    wire [16:0] core_control; // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
    wire [28:0] core_AGU_initial_1, core_AGU_initial_2, core_AGU_initial_3, core_AGU_initial_4, core_AGU_initial_5, core_AGU_initial_6; // {AGU_W_initial[27:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
    wire [29:0] core_tile_param; // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
    wire [60:0] requant_param; // {factor[15:0], zp[39:0], shift[4:0]}
    // TBO control
    wire [22:0] tbo_param; // {tile_sel_cycle, tile_assign}
    // CIU control
    wire cycle_en;
    wire [15:0] AGU_C_param_1, AGU_C_param_2, AGU_C_param_3, AGU_C_param_4, AGU_C_param_5, AGU_C_param_6; // {AGU_C_initial, tile_size}
    // GLB control
    wire glb_input_en;
    wire glb_output_en;
    wire [10:0] output_ch_to_Y_initial;
    wire [10:0] input_ch_to_Y_initial;
    wire [53:0] glb_input_param; // {glb_in_mode[1:0], input_AGU_param[51:0]}
    wire [53:0] glb_output_param; // {glb_out_mode[1:0], output_AGU_param[51:0]}
    // PreP control
    wire [1:0] prep_control_bus; // {prep_en, prep_buffer_sel}
    // PosP control
    wire [32:0] posp_control_bus; // {posp_en[32], hand_th[31:24], tool_th[23:16], block_th[15:8], safe_th[7:0]}

    ////////// dummy assign //////////
    assign instruction_loader_busy = 1'b0;
    //assign weight_loader_busy = 1'b0;
    //assign prep_busy = 1'b0;
    ////////// dummy assign end //////////

    Controller_assembly controller_assembly_inst(
        // basic
        .CLK(CLK),
        .PS_en(PS_en),
        .PS_rst(PS_rst),
        .system_rst(system_rst),
    
        // Submodule Busy signals
        .instruction_loader_busy(instruction_loader_busy),
        .weight_loader_busy(weight_loader_busy),
        .lower_busy_bus(lower_busy_bus), // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_in, GLB_out, CIU, PreP, PosP}

        // Weight Loader control
        .weight_loader_bus(weight_loader_bus),  // {en[21], double_buffer_sel[20:19], weight_amount[18:7], bias_amount[6:0]}

        // Core control and parameters
        .core_en_1(core_en_1),
        .core_en_2(core_en_2),
        .core_en_3(core_en_3),
        .core_en_4(core_en_4),
        .core_en_5(core_en_5),
        .core_en_6(core_en_6),
        .core_control(core_control), // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial_1(core_AGU_initial_1), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_2(core_AGU_initial_2), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_3(core_AGU_initial_3), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_4(core_AGU_initial_4), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_5(core_AGU_initial_5), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_6(core_AGU_initial_6), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}

        // TBO control and parameters
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // CIU control and parameters
        .cycle_en(cycle_en),
        .AGU_C_param_1(AGU_C_param_1), // {AGU_C_initial, tile_size}
        .AGU_C_param_2(AGU_C_param_2), // {AGU_C_initial, tile_size}
        .AGU_C_param_3(AGU_C_param_3), // {AGU_C_initial, tile_size}
        .AGU_C_param_4(AGU_C_param_4), // {AGU_C_initial, tile_size}
        .AGU_C_param_5(AGU_C_param_5), // {AGU_C_initial, tile_size}
        .AGU_C_param_6(AGU_C_param_6), // {AGU_C_initial, tile_size}

        // GLB control and parameters
        .glb_input_en(glb_input_en),
        .glb_output_en(glb_output_en),
        .output_ch_to_Y_initial(output_ch_to_Y_initial),
        .input_ch_to_Y_initial(input_ch_to_Y_initial),
        .glb_input_param(glb_input_param), // {glb_in_mode[1:0], input_AGU_param[51:0]}
        .glb_output_param(glb_output_param), // {glb_out_mode[1:0], output_AGU_param[51:0]}

        // PreP control and parameters
        .prep_control_bus(prep_control_bus), // {prep_en, prep_buffer_sel}

        // PosP control and parameters
        .posp_control_bus(posp_control_bus), // {posp_en[32], hand_th[31:24], tool_th[23:16], block_th[15:8], safe_th[7:0]}

        // PL status
        .PL_busy(PL_busy)
    );
    ////////// Controller Assembly end //////////

    ////////// Global Buffer Assembly //////////
    wire [8:0] glb_prep_wb_bus;// {en, addr[7:0]}
    wire [8:0] glb_ciu_wb_bus_1; // {en, addr[7:0]}
    wire [8:0] glb_ciu_wb_bus_2; // {en, addr[7:0]}
    wire [8:0] glb_ciu_wb_bus_3; // {en, addr[7:0]}
    wire [8:0] glb_ciu_wb_bus_4; // {en, addr[7:0]}
    wire [8:0] glb_ciu_wb_bus_5; // {en, addr[7:0]}
    wire [8:0] glb_ciu_wb_bus_6; // {en, addr[7:0]}
    wire [32:0] prep_glb_wb_bus; // {valid, data[31:0]}
    wire [32:0] ciu_glb_wb_bus_1; // {valid, data[31:0]}
    wire [32:0] ciu_glb_wb_bus_2; // {valid, data[31:0]}
    wire [32:0] ciu_glb_wb_bus_3; // {valid, data[31:0]}
    wire [32:0] ciu_glb_wb_bus_4; // {valid, data[31:0]}
    wire [32:0] ciu_glb_wb_bus_5; // {valid, data[31:0]}
    wire [32:0] ciu_glb_wb_bus_6; // {valid, data[31:0]}
    wire [40:0] glb_ciu_load_bus_1; // {en, addr[7:0], data[31:0]}
    wire [40:0] glb_ciu_load_bus_2; // {en, addr[7:0], data[31:0]}
    wire [40:0] glb_ciu_load_bus_3; // {en, addr[7:0], data[31:0]}
    wire [40:0] glb_ciu_load_bus_4; // {en, addr[7:0], data[31:0]}
    wire [40:0] glb_ciu_load_bus_5; // {en, addr[7:0], data[31:0]}
    wire [40:0] glb_ciu_load_bus_6; // {en, addr[7:0], data[31:0]}
    wire [40:0] glb_posp_load_bus; // {en, addr[7:0], data[31:0]}

    ////////// dummy assign //////////
    //assign prep_glb_wb_bus = 0;
    ////////// dummy assign end //////////

    GLB_operator glb_operator(
        // basic
        .CLK(CLK),
        .rst(system_rst),
        .glb_input_en(glb_input_en),
        .glb_output_en(glb_output_en),
        // Control param
        .output_ch_to_Y_initial(output_ch_to_Y_initial), // 0~2047
        .input_ch_to_Y_initial(input_ch_to_Y_initial), // 0~2047
        .glb_input_param(glb_input_param), // {glb_in_mode[1:0], input_AGU_param[51:0]}
        .glb_output_param(glb_output_param), // {glb_out_mode[1:0], output_AGU_param[51:0]}
        // GLB_input
        .glb_prep_wb_bus(glb_prep_wb_bus),// {en, addr[7:0]}
        .glb_ciu_wb_bus_1(glb_ciu_wb_bus_1), // {en, addr[7:0]}
        .glb_ciu_wb_bus_2(glb_ciu_wb_bus_2), // {en, addr[7:0]}
        .glb_ciu_wb_bus_3(glb_ciu_wb_bus_3), // {en, addr[7:0]}
        .glb_ciu_wb_bus_4(glb_ciu_wb_bus_4), // {en, addr[7:0]}
        .glb_ciu_wb_bus_5(glb_ciu_wb_bus_5), // {en, addr[7:0]}
        .glb_ciu_wb_bus_6(glb_ciu_wb_bus_6), // {en, addr[7:0]}
        .prep_glb_wb_bus(prep_glb_wb_bus), // {valid, data[31:0]}
        .ciu_glb_wb_bus_1(ciu_glb_wb_bus_1), // {valid, data[31:0]}
        .ciu_glb_wb_bus_2(ciu_glb_wb_bus_2), // {valid, data[31:0]}
        .ciu_glb_wb_bus_3(ciu_glb_wb_bus_3), // {valid, data[31:0]}
        .ciu_glb_wb_bus_4(ciu_glb_wb_bus_4), // {valid, data[31:0]}
        .ciu_glb_wb_bus_5(ciu_glb_wb_bus_5), // {valid, data[31:0]}
        .ciu_glb_wb_bus_6(ciu_glb_wb_bus_6), // {valid, data[31:0]}
        // GLB_output
        .glb_ciu_load_bus_1(glb_ciu_load_bus_1), // {en, addr[7:0], data[31:0]}
        .glb_ciu_load_bus_2(glb_ciu_load_bus_2), // {en, addr[7:0], data[31:0]}
        .glb_ciu_load_bus_3(glb_ciu_load_bus_3), // {en, addr[7:0], data[31:0]}
        .glb_ciu_load_bus_4(glb_ciu_load_bus_4), // {en, addr[7:0], data[31:0]}
        .glb_ciu_load_bus_5(glb_ciu_load_bus_5), // {en, addr[7:0], data[31:0]}
        .glb_ciu_load_bus_6(glb_ciu_load_bus_6), // {en, addr[7:0], data[31:0]}
        .glb_posp_load_bus(glb_posp_load_bus), // {en, addr[7:0], data[31:0]}
        // busy signal
        .glb_input_busy(glb_input_busy),
        .glb_output_busy(glb_output_busy)
    );
    ////////// Global Buffer Assembly end //////////

    ////////// debug //////////
    (* mark_debug = "true" *) wire [15:0] debug_core_control;
    (* mark_debug = "true" *) wire [31:0] debug_tbo_core_cal_data_1;
    (* mark_debug = "true" *) wire [31:0] debug_tbo_core_cal_data_2;
    (* mark_debug = "true" *) wire [31:0] debug_tbo_core_cal_data_3;
    (* mark_debug = "true" *) wire [31:0] debug_tbo_core_cal_data_4;
    (* mark_debug = "true" *) wire [31:0] debug_tbo_core_cal_data_5;
    (* mark_debug = "true" *) wire [31:0] debug_tbo_core_cal_data_6;
    (* mark_debug = "true" *) wire [31:0] debug_w_storage_core_data_0;
    (* mark_debug = "true" *) wire [31:0] debug_b_storage_core_data_0;
    (* mark_debug = "true" *) wire [40:0] debug_core_tbo_store_bus;
    (* mark_debug = "true" *) wire [7:0] debug_addr_cal;
    ////////// debug end //////////


    ////////// Core_TBO_CIU Assembly //////////
    wire [39:0] stream_a_14, stream_a_45, stream_a_56, stream_a_63, stream_a_32, stream_a_21;
    wire [39:0] stream_b_12, stream_b_23, stream_b_36, stream_b_65, stream_b_54, stream_b_41;
    wire [80:0] 
        weight_loader_w_storage_bus_1, 
        weight_loader_w_storage_bus_2, 
        weight_loader_w_storage_bus_3, 
        weight_loader_w_storage_bus_4, 
        weight_loader_w_storage_bus_5, 
        weight_loader_w_storage_bus_6; // {en_0, en_1, en_2, en_3, addr[12:0], data[63:0]}
    wire [74:0] 
        weight_loader_b_storage_bus_1,
        weight_loader_b_storage_bus_2,
        weight_loader_b_storage_bus_3,
        weight_loader_b_storage_bus_4,
        weight_loader_b_storage_bus_5,
        weight_loader_b_storage_bus_6; // {en_0, en_1, en_2, en_3, addr[6:0], data[63:0]}
    
    // Core 1
    Core_TBO_CIU core_1(
        // basic
        .CLK(CLK),
        .rst(system_rst), // system reset

        // CIU
        .cycle_en(cycle_en),
        .AGU_C_param(AGU_C_param_1), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_21),
        .stream_a_out(stream_a_14),
        .stream_b_in(stream_b_41),
        .stream_b_out(stream_b_12),
        .glb_ciu_load_bus(glb_ciu_load_bus_1), // {valid_load, addr_load, din_load}
        .glb_ciu_wb_bus(glb_ciu_wb_bus_1), // {en_wb, addr_wb_in}
        .ciu_glb_wb_bus(ciu_glb_wb_bus_1), // {data_valid, CIU_wb}
        .cycle_busy(cycle_1_busy),

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_en(core_en_1),
        .core_control(core_control),  // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial(core_AGU_initial_1), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        .weight_loader_w_storage_bus(weight_loader_w_storage_bus_1), // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
        .weight_loader_b_storage_bus(weight_loader_b_storage_bus_1), // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
        .core_busy(core_1_busy),
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

    // Core 2
    Core_TBO_CIU core_2(
        // basic
        .CLK(CLK),
        .rst(system_rst), // system reset

        // CIU
        .cycle_en(cycle_en),
        .AGU_C_param(AGU_C_param_2), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_32),
        .stream_a_out(stream_a_21),
        .stream_b_in(stream_b_12),
        .stream_b_out(stream_b_23),
        .glb_ciu_load_bus(glb_ciu_load_bus_2), // {valid_load, addr_load, din_load}
        .glb_ciu_wb_bus(glb_ciu_wb_bus_2), // {en_wb, addr_wb_in}
        .ciu_glb_wb_bus(ciu_glb_wb_bus_2), // {data_valid, CIU_wb}
        .cycle_busy(cycle_2_busy),

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_en(core_en_2),
        .core_control(core_control),  // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial(core_AGU_initial_2), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        .weight_loader_w_storage_bus(weight_loader_w_storage_bus_2), // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
        .weight_loader_b_storage_bus(weight_loader_b_storage_bus_2), // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
        .core_busy(core_2_busy)
    );

    // Core 3
    Core_TBO_CIU core_3(
        // basic
        .CLK(CLK),
        .rst(system_rst), // system reset

        // CIU
        .cycle_en(cycle_en),
        .AGU_C_param(AGU_C_param_3), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_63),
        .stream_a_out(stream_a_32),
        .stream_b_in(stream_b_23),
        .stream_b_out(stream_b_36),
        .glb_ciu_load_bus(glb_ciu_load_bus_3), // {valid_load, addr_load, din_load}
        .glb_ciu_wb_bus(glb_ciu_wb_bus_3), // {en_wb, addr_wb_in}
        .ciu_glb_wb_bus(ciu_glb_wb_bus_3), // {data_valid, CIU_wb}
        .cycle_busy(cycle_3_busy),

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_en(core_en_3),
        .core_control(core_control),  // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial(core_AGU_initial_3), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        .weight_loader_w_storage_bus(weight_loader_w_storage_bus_3), // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
        .weight_loader_b_storage_bus(weight_loader_b_storage_bus_3), // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
        .core_busy(core_3_busy)
    );

    // Core 4
    Core_TBO_CIU core_4(
        // basic
        .CLK(CLK),
        .rst(system_rst), // system reset

        // CIU
        .cycle_en(cycle_en),
        .AGU_C_param(AGU_C_param_4), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_14),
        .stream_a_out(stream_a_45),
        .stream_b_in(stream_b_54),
        .stream_b_out(stream_b_41),
        .glb_ciu_load_bus(glb_ciu_load_bus_4), // {valid_load, addr_load, din_load}
        .glb_ciu_wb_bus(glb_ciu_wb_bus_4), // {en_wb, addr_wb_in}
        .ciu_glb_wb_bus(ciu_glb_wb_bus_4), // {data_valid, CIU_wb}
        .cycle_busy(cycle_4_busy),

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_en(core_en_4),
        .core_control(core_control),  // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial(core_AGU_initial_4), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        .weight_loader_w_storage_bus(weight_loader_w_storage_bus_4), // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
        .weight_loader_b_storage_bus(weight_loader_b_storage_bus_4), // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
        .core_busy(core_4_busy)
    );

    // Core 5
    Core_TBO_CIU core_5(
        // basic
        .CLK(CLK),
        .rst(system_rst), // system reset

        // CIU
        .cycle_en(cycle_en),
        .AGU_C_param(AGU_C_param_5), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_45),
        .stream_a_out(stream_a_56),
        .stream_b_in(stream_b_65),
        .stream_b_out(stream_b_54),
        .glb_ciu_load_bus(glb_ciu_load_bus_5), // {valid_load, addr_load, din_load}
        .glb_ciu_wb_bus(glb_ciu_wb_bus_5), // {en_wb, addr_wb_in}
        .ciu_glb_wb_bus(ciu_glb_wb_bus_5), // {data_valid, CIU_wb}
        .cycle_busy(cycle_5_busy),

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_en(core_en_5),
        .core_control(core_control),  // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial(core_AGU_initial_5), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        .weight_loader_w_storage_bus(weight_loader_w_storage_bus_5), // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
        .weight_loader_b_storage_bus(weight_loader_b_storage_bus_5), // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
        .core_busy(core_5_busy)
    );

    // Core 6
    Core_TBO_CIU core_6(
        // basic
        .CLK(CLK),
        .rst(system_rst), // system reset

        // CIU
        .cycle_en(cycle_en),
        .AGU_C_param(AGU_C_param_6), // {AGU_C_initial, tile_size}
        .stream_a_in(stream_a_56),
        .stream_a_out(stream_a_63),
        .stream_b_in(stream_b_36),
        .stream_b_out(stream_b_65),
        .glb_ciu_load_bus(glb_ciu_load_bus_6), // {valid_load, addr_load, din_load}
        .glb_ciu_wb_bus(glb_ciu_wb_bus_6), // {en_wb, addr_wb_in}
        .ciu_glb_wb_bus(ciu_glb_wb_bus_6), // {data_valid, CIU_wb}
        .cycle_busy(cycle_6_busy),

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_en(core_en_6),
        .core_control(core_control),  // {mode_in[2:0], stride_X_in[1:0], ReLU_en_in, padding, tile_sel_in[8:0], requantization}
        .core_AGU_initial(core_AGU_initial_6), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}
        .weight_loader_w_storage_bus(weight_loader_w_storage_bus_6), // {en_0, en_1, en_2, en_3, addr[75:64], data[63:0]}
        .weight_loader_b_storage_bus(weight_loader_b_storage_bus_6), // {en_0, en_1, en_2, en_3, addr[70:64], data[63:0]}
        .core_busy(core_6_busy)
    );
    ////////// Core_TBO_CIU Assembly end //////////

    ////////// Post-processing //////////
    Post_processing post_processing(
        // basic
        .CLK(CLK),
        .rst(PS_rst),
        .en(posp_control_bus[32]),
        // control bus
        .input_label(posp_control_bus[31:0]), // {hand_th[31:24], tool_th[23:16], block_th[15:8], safe_th[7:0]}
        // input data
        .input_data_valid(glb_posp_load_bus[40]),
        .input_data(glb_posp_load_bus[31:0]),
        // output
        .result(inference_result),
        // busy
        .busy(posp_busy)
    );
    ////////// Post-processing end //////////

    ////////// Data Loader //////////
    wire [6:0]   img_uram_addr;
    wire         img_uram_we;
    wire [127:0] img_uram_data;

    Data_loader data_loader(
        // 時脈與重置訊號
        .clk                  (CLK),
        .rst_n                (~system_rst), // 假設子系統採用低電位重置 (Active-low)
        // AXI-Stream 影像介面
        .s_axis_image_tdata   (s_axis_image_tdata),
        .s_axis_image_tvalid  (s_axis_image_tvalid),
        .s_axis_image_tlast   (s_axis_image_tlast),
        .s_axis_image_tready  (s_axis_image_tready),
        // AXI-Stream 權重介面
        .s_axis_weight_tdata  (s_axis_weight_tdata),
        .s_axis_weight_tvalid (s_axis_weight_tvalid),
        .s_axis_weight_tready (s_axis_weight_tready),
        // 控制訊號 (Controller 至子系統)
        .i_image_start        (prep_control_bus[1]), // TODO: 連接影像啟動控制訊號
        .i_weight_start       (weight_loader_bus[21]),
        .i_image_buffer_sel   (prep_control_bus[0]), // TODO: 連接乒乓緩衝區切換訊號
        .i_weight_buffer_sel  (weight_loader_bus[20:19]),
        .i_weight_len         (weight_loader_bus[18:7]),
        .i_bias_len           (weight_loader_bus[6:0]),
        // 狀態訊號 (子系統至 Controller)
        .o_image_busy         (prep_busy), // TODO: 連接至 lower_busy_bus 的影像對應位元
        .o_weight_busy        (weight_loader_busy),
        // 影像 BRAM 介面 (接至外部乒乓 BRAM)
        .i_prep_rd_en         (glb_prep_wb_bus[8]),     // Enable 訊號 (最高位)
        .i_prep_rd_addr       (glb_prep_wb_bus[7:0]),     // Address 訊號
        .o_prep_rd_valid      (prep_glb_wb_bus[32]),     // 讀出資料有效訊號 (最高位)
        .o_prep_rd_data       (prep_glb_wb_bus[31:0]),     // 讀出 128-bit 影像資料
        // 權重儲存匯流排 (子系統至 6 個運算核心)
        .o_wgt_storage_bus_1  (weight_loader_w_storage_bus_1),
        .o_wgt_storage_bus_2  (weight_loader_w_storage_bus_2),
        .o_wgt_storage_bus_3  (weight_loader_w_storage_bus_3),
        .o_wgt_storage_bus_4  (weight_loader_w_storage_bus_4),
        .o_wgt_storage_bus_5  (weight_loader_w_storage_bus_5),
        .o_wgt_storage_bus_6  (weight_loader_w_storage_bus_6),
        // 偏差儲存匯流排 (子系統至 6 個運算核心)
        .o_bias_storage_bus_1 (weight_loader_b_storage_bus_1),
        .o_bias_storage_bus_2 (weight_loader_b_storage_bus_2),
        .o_bias_storage_bus_3 (weight_loader_b_storage_bus_3),
        .o_bias_storage_bus_4 (weight_loader_b_storage_bus_4),
        .o_bias_storage_bus_5 (weight_loader_b_storage_bus_5),
        .o_bias_storage_bus_6 (weight_loader_b_storage_bus_6)
    );
    ////////// Data Loader end //////////

endmodule