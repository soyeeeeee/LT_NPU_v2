`timescale 1ns / 1ps

module Controller_assembly(
    input CLK,
    input PS_en,
    input PS_rst,
    output system_rst,
    
    ////////// Instruction memory interface //////////
    /*input [48:0] IS_load_bus, // {en, address[47:40], IS[39:0]}
    input [154:0] VLIW_load_bus, // {en, address[153:144], VLIW[143:0]}*/
    
    ////////// Submodule Busy signals //////////
    input instruction_loader_busy,
    input weight_loader_busy,
    input [10:0] lower_busy_bus, // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}

    ////////// Instruction Loader control //////////
    output instruction_loader_en,

    ////////// Weight Loader control //////////
    output [21:0] weight_loader_bus, // {en[21], double_buffer_sel[20:19], weight_amount[18:7], bias_amount[6:0]}

    ////////// Core control and parameters //////////
    // control signal
    output core_en_1,
    output core_en_2,
    output core_en_3,
    output core_en_4,
    output core_en_5,
    output core_en_6,
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
    // requant param
    output [182:0] requant_param, // {factor[15:0], zp[39:0], shift[4:0]}*3

    ////////// TBO control and parameters //////////
    output [22:0] tbo_param, // {tile_sel_cycle, tile_assign}

    ////////// CIU control and parameters //////////
    output cycle_en,
    output [15:0] AGU_C_param_1, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_2, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_3, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_4, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_5, // {AGU_C_initial, tile_size}
    output [15:0] AGU_C_param_6, // {AGU_C_initial, tile_size}

    ////////// GLB control and parameters //////////
    output glb_input_en,
    output glb_output_en,
    output [10:0] output_ch_to_Y_initial,
    output [10:0] input_ch_to_Y_initial, // 0~2047
    output [53:0] glb_input_param, // {glb_in_mode[1:0], input_AGU_param[51:0]}
    output [53:0] glb_output_param, // {glb_out_mode[1:0], output_AGU_param[51:0]}

    ////////// PreP control and parameters //////////
    output [1:0] prep_control_bus, // {prep_en, prep_buffer_sel}

    ////////// PosP control and parameters //////////
    output [32:0] posp_control_bus, // {posp_en[32], hand_th[31:24], tool_th[23:16], block_th[15:8], safe_th[7:0]}

    ////////// PL status //////////
    output PL_busy
);

    ////////// Instruction RAM //////////
    // IS
    wire [8:0] IS_PC_bus; // {en, 8 bit address}
    wire [71:0] IS;
    IS_storage is_storage(
        .clka(CLK),
        .ena(IS_PC_bus[8]),
        .addra(IS_PC_bus[7:0]),
        .douta(IS)
    );
    // VLIW
    wire [10:0] VLIW_PC_bus; // {en, 10 bit address}
    wire [143:0] VLIW;
    VLIW_storage vliw_storage(
        .clka(CLK),
        .ena(VLIW_PC_bus[10]),
        .addra(VLIW_PC_bus[9:0]),
        .douta(VLIW)
    );
    ////////// Instruction RAM end //////////

    ////////// Lower Controller //////////
    wire lower_controller_en;
    wire [9:0] VLIW_initial;
    wire [9:0] VLIW_length;
    wire [10:0] lower_en_bus; // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}
    wire [132:0] VLIW_num;
    wire lower_controller_busy;
    assign {core_en_1, core_en_2, core_en_3, core_en_4, core_en_5, core_en_6, glb_output_en, glb_input_en, cycle_en, prep_control_bus[1], posp_control_bus[32]}
        = lower_en_bus;
    reg [10:0] lower_busy_bus_buffer;
    always@(posedge CLK) begin
        if(system_rst) begin
            lower_busy_bus_buffer <= 0;
        end
        else begin
            lower_busy_bus_buffer <= lower_busy_bus;
        end
    end
    Lower_controller lower_controller(
        .CLK(CLK),
        .en(lower_controller_en),
        .rst(system_rst),
        .VLIW_initial(VLIW_initial),
        .VLIW_length(VLIW_length),
        // VLIW interface
        .VLIW_PC_bus(VLIW_PC_bus), // {en, 10 bit address}
        .VLIW(VLIW),
        // busy signals
        .lower_busy_bus(lower_busy_bus_buffer), // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}
        // output control signals
        .lower_en_bus(lower_en_bus), // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}
        .VLIW_num(VLIW_num), // VLIW number
        // Lower controller status
        .lower_controller_busy(lower_controller_busy) // VLIW busy signal
    );
    ////////// Lower Controller end //////////

    ////////// Top Controller //////////
    wire [16:0] output_combined;      // {glb_out_mode, width_out, ch_out}
    wire [16:0] input_combined;       // {glb_in_mode, width_in, ch_in}
    wire [5:0] double_buffer_sel;    // {output_glb, input_glb, W_storage[1:0], B_storage[1:0]}
    wire [7:0] cycle_tile_size;      // {cycle_tile_size[7:0]}
    Top_controller top_controller(
        .CLK(CLK),
        .PS_en(PS_en),
        .PS_rst(PS_rst),
        .system_rst(system_rst),
        // IS interface
        .IS_PC_bus(IS_PC_bus), // {en, 8bit address}
        .IS(IS),
        // busy signals
        .instruction_loader_busy(instruction_loader_busy),
        .lower_controller_busy(lower_controller_busy),
        .weight_loader_busy(weight_loader_busy),
        // Lower Controller control
        .lower_controller_en(lower_controller_en), 
        .VLIW_initial(VLIW_initial),
        .VLIW_length(VLIW_length),
        // Weight Loader control
        .weight_loader_en(weight_loader_bus[21]),
        .weight_loader_buffer_sel(weight_loader_bus[20:19]),
        .weight_amount(weight_loader_bus[18:7]),
        .bias_amount(weight_loader_bus[6:0]),
        // Instruction Loader control
        .instruction_loader_en(instruction_loader_en),
        // parameters for Core, CIU, TBO, GLB, PreP, PosP
        .output_combined(output_combined),
        .input_combined(input_combined),
        .double_buffer_sel(double_buffer_sel),    // {output_glb, input_glb, W_storage[1:0], B_storage[1:0]}
        .cycle_tile_size(cycle_tile_size),      // {cycle_tile_size[7:0]}
        .output_ch_to_Y_initial(output_ch_to_Y_initial),
        .input_ch_to_Y_initial(input_ch_to_Y_initial),
        .posp_param(posp_control_bus[31:0]),           // {hand_th, tool_th, block_th, safe_th}
        .requant_param(requant_param), // {factor[15:0], zp[39:0], shift[4:0]}*3
        // system status
        .PL_busy(PL_busy)                      // PL working, notify PS
    );
    ////////// Top Controller end //////////

    ////////// Param Decoder //////////
    Param_decoder param_decoder(
        .CLK(CLK),
        .rst(system_rst),

        // IS/VLIW input
        .VLIW_num(VLIW_num),
        .output_combined(output_combined), // {glb_out_mode, width_out, ch_out}
        .input_combined(input_combined), // {glb_in_mode, width_in, ch_in}
        .double_buffer_sel(double_buffer_sel), // {output_glb, input_glb, W_storage, B_storage}
        .cycle_tile_size(cycle_tile_size),

        // CIU
        .AGU_C_param_1(AGU_C_param_1), // {AGU_C_initial, tile_size}
        .AGU_C_param_2(AGU_C_param_2), // {AGU_C_initial, tile_size}
        .AGU_C_param_3(AGU_C_param_3), // {AGU_C_initial, tile_size}
        .AGU_C_param_4(AGU_C_param_4), // {AGU_C_initial, tile_size}
        .AGU_C_param_5(AGU_C_param_5), // {AGU_C_initial, tile_size}
        .AGU_C_param_6(AGU_C_param_6), // {AGU_C_initial, tile_size}

        // Tile Buffer Operator
        .tbo_param(tbo_param), // {tile_sel_cycle, tile_assign}

        // Core
        .core_control(core_control), // {mode_in[15:13], stride_X_in[12:11], ReLU_en_in[10], padding[9], tile_sel_in[8:0]}
        .core_AGU_initial_1(core_AGU_initial_1), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_2(core_AGU_initial_2), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_3(core_AGU_initial_3), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_4(core_AGU_initial_4), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_5(core_AGU_initial_5), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_AGU_initial_6(core_AGU_initial_6), // {AGU_W_initial[28:16], AGU_B_initial[15:8], AGU_O_initial[7:0]}
        .core_tile_param(core_tile_param), // {width_in[29:23], ch_in[22:15], width_out[14:8], ch_out[7:0]}

        // GLB operator
        .glb_input_param(glb_input_param),
        .glb_output_param(glb_output_param),
        .prep_buffer_sel(prep_control_bus[0])
    );
    ////////// Param Decoder end //////////
    
endmodule