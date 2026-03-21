`timescale 1ns / 1ps

module Top_controller(
    input CLK,
    input PS_en,
    input PS_rst,
    output reg system_rst,
    
    ////////// Instruction memory interface //////////
    output [8:0] IS_PC_bus, // {en, 8bit address}
    input [71:0] IS,
    
    ////////// Submodule Busy signals //////////
    input instruction_loader_busy,
    input lower_controller_busy,
    input weight_loader_busy,

    ////////// Submodule control and parameter outputs //////////
    // VLIW control
    output reg lower_controller_en,
    output reg [9:0] VLIW_initial,
    output reg [9:0] VLIW_length,
    // Weight Loader control
    output reg weight_loader_en,
    output reg [1:0] weight_loader_buffer_sel,
    output reg [11:0] weight_amount,
    output reg [6:0] bias_amount,
    // Instruction Loader control
    output reg instruction_loader_en,
    output reg [7:0] IS_amount,
    output reg [9:0] VLIW_amount,
    // param
    output reg [16:0] output_combined,      // {glb_out_mode, width_out, ch_out}
    output reg [16:0] input_combined,       // {glb_in_mode, width_in, ch_in}
    output reg [ 5:0] double_buffer_sel,    // {output_glb, input_glb, W_storage, B_storage}
    output reg [ 7:0] cycle_tile_size,      // {cycle_tile_size[7:0]}
    output reg [10:0] output_ch_to_Y_initial,
    output reg [10:0] input_ch_to_Y_initial,
    output reg [31:0] posp_param,           // {hand_th, tool_th, block_th, safe_th}
    output reg [182:0] requant_param,       // {factor[15:0], zp[39:0], shift[4:0]}*3
    ////////// System status //////////
    output reg PL_busy                      // PL working, notify PS
);

    ////////// Instruction Decoding //////////
    wire [2:0] op_class  = IS[71:69];
    wire [2:0] op_func   = IS[68:66];
    wire [1:0] op_cond   = IS[65:64];
    wire [31:0] num_1    = IS[63:32];
    wire [31:0] num_2    = IS[31: 0];
    ////////// Instruction Decoding end //////////

    ////////// Instruction RAM interface //////////
    // initial determine
    reg initial_det;
    always@(posedge CLK) begin
        if(PS_rst) begin
            initial_det <= 0;
        end
        else if(PS_en) begin
            initial_det <= 1;
        end
        else begin
            initial_det <= initial_det;
        end
    end
    // PC
    reg [7:0] PC, next_PC;
    reg PC_en;
    assign IS_PC_bus = {PC_en, PC};
    always@(*) begin
        next_PC = PC + PC_en;
    end
    always@(posedge CLK) begin
        if(PS_rst) begin
            PC <= 0;
        end
        else if(system_rst && initial_det) begin
            PC <= 3;
        end
        else begin
            PC <= next_PC;
        end
    end
    ////////// Instruction RAM interface end //////////

    ////////// OP Code Definitions //////////
    // Class 0: Change Parameter
    localparam CLASS_change_param    = 3'd0;
    localparam FUNC_output_param     = 3'd0;
    localparam FUNC_input_param      = 3'd1;
    localparam FUNC_buffer_initial   = 3'd2;
    localparam FUNC_core_param       = 3'd3;
    localparam FUNC_ch_order         = 3'd4;
    localparam FUNC_posp_param       = 3'd5;
    localparam FUNC_requant_param_0  = 3'd6;
    localparam FUNC_requant_param_1  = 3'd7;
    localparam FUNC_requant_param_2  = 3'd8;
    // Class 1: DRAM
    localparam CLASS_dram            = 3'd1;
    localparam FUNC_get_instruction  = 3'd0;
    localparam FUNC_get_weight       = 3'd1;
    // Class 2: Control
    localparam CLASS_control         = 3'd2;
    localparam FUNC_idle             = 3'd0;
    localparam FUNC_run_VLIW         = 3'd1;
    localparam FUNC_wait             = 3'd2;
    localparam FUNC_finish           = 3'd3;
    ////////// OP Code Definitions end //////////

    ////////// Internal Registers and State //////////
    // FSM States
    reg [2:0] state, next_state;
    localparam S_idle     = 3'd0; // Wait for start
    localparam S_set_0    = 3'd1;
    localparam S_set_1    = 3'd2;
    localparam S_decode   = 3'd3; // Decode and trigger Enable
    localparam S_buffer_0 = 3'd4;
    localparam S_buffer_1 = 3'd5;
    localparam S_wait     = 3'd6; // Wait for Done signal
    localparam S_finish   = 3'd7; // Finish state
    ////////// Internal Registers and State end //////////

    ////////// Start Signal //////////
    reg PS_en_d; // Delayed version of PS_en for edge detection
    always @(posedge CLK) begin
        if (PS_rst) begin
            PS_en_d <= 0; // Latch the start signal
        end
        else begin
            PS_en_d <= PS_en; // Update delayed signal
        end
    end
    wire PS_start_pulse = PS_en & ~PS_en_d; // Detect rising edge of PS_en
    ////////// Start Signal end //////////

    ////////// Next State Logic and PC_en //////////
    always @(*) begin
        next_state = state;
        PC_en = 0;
        PL_busy = 0;
        system_rst = 0;

        case (state)
            S_idle: begin
                system_rst = 1;
                if(PS_en) next_state = S_set_0;
                else next_state = S_idle;
            end
            S_set_0: begin
                PC_en = 1; // Start fetching instructions
                PL_busy = 1;
                next_state = S_set_1;
            end
            S_set_1: begin
                PL_busy = 1;
                PC_en = 1; // Continue fetching instructions
                next_state = S_decode;
            end
            S_decode: begin
                PL_busy = 1;
                PC_en = 1;
                case(op_class)
                    CLASS_change_param: begin
                        next_state = S_decode; // Just set parameters, no need to wait
                    end
                    CLASS_dram: begin
                        next_state = S_decode; // Trigger DRAM access, but we can start decoding next instruction immediately
                    end
                    CLASS_control: begin
                        case(op_func)
                            FUNC_idle: begin
                                next_state = S_decode;
                            end
                            FUNC_run_VLIW: begin
                                next_state = S_decode;
                            end
                            FUNC_wait: begin
                                next_state = S_buffer_0;
                            end
                            FUNC_finish: begin
                                next_state = S_finish;
                            end
                            default: next_state = S_decode;
                        endcase
                    end
                    default: next_state = S_decode;
                endcase
            end
            S_buffer_0: begin
                PL_busy = 1;
                PC_en = 0;
                next_state = S_buffer_1;
            end
            S_buffer_1: begin
                PL_busy = 1;
                PC_en = 0;
                next_state = S_wait;
            end
            S_wait: begin
                PC_en = 0;
                PL_busy = 1;
                if( instruction_loader_busy || lower_controller_busy || weight_loader_busy ) begin
                    next_state = S_wait; // Stay in wait state until all are done
                end
                else begin
                    next_state = S_decode; // Go back to decode next instruction
                end
            end
            S_finish: begin
                PL_busy = 0; // Notify PS
                next_state = S_idle;
            end
            default: begin
                next_state = S_idle;
            end
        endcase
    end
    ////////// Next State Logic and PC_en end //////////

    ////////// FSM and register //////////
    always @(posedge CLK) begin
        if(PS_rst) begin
            state <= S_idle;
            // VLIW control
            lower_controller_en <= 0;
            VLIW_initial <= 0;
            VLIW_length <= 0;
            // Weight Loader control
            weight_loader_en <= 0;
            weight_amount <= 0;
            bias_amount <= 0;
            // Instruction Loader control
            instruction_loader_en <= 0;
            // param
            output_combined <= 0;
            input_combined <= 0;
            double_buffer_sel <= 0;
            cycle_tile_size <= 0;
            output_ch_to_Y_initial <= 0;
            input_ch_to_Y_initial <= 0;
            posp_param <= 32'd0;
            requant_param <= 183'd0;
        end
        else begin
            state <= next_state;
            case (state)
                S_idle: begin
                    // VLIW control
                    lower_controller_en <= 0;
                    VLIW_initial <= 0;
                    VLIW_length <= 0;
                    // Weight Loader control
                    weight_loader_en <= 0;
                    weight_amount <= 0;
                    bias_amount <= 0;
                    // Instruction Loader control
                    instruction_loader_en <= 0;
                    // param
                    output_combined <= 0;
                    input_combined <= 0;
                    double_buffer_sel <= 0;
                    cycle_tile_size <= 0;
                    output_ch_to_Y_initial <= 0;
                    input_ch_to_Y_initial <= 0;
                    posp_param <= 32'd0;
                    requant_param <= 183'd0;
                end
                S_decode: begin
                    weight_loader_en <= 0;
                    instruction_loader_en <= 0;
                    lower_controller_en <= 0;
                    case (op_class)
                        CLASS_change_param: begin
                            case (op_func)
                                FUNC_output_param: begin // Change_GLB_parameter
                                    output_combined  <= {num_1[1:0], num_2[14:0]};
                                end
                                FUNC_input_param: begin // Change_GLB_parameter
                                    input_combined  <= {num_1[1:0], num_2[14:0]};
                                end
                                FUNC_buffer_initial: begin // Change_GLB_parameter
                                    double_buffer_sel  <= num_1[5:0];
                                end
                                FUNC_core_param: begin // Change_core_parameter
                                    cycle_tile_size <= num_1[7:0];
                                end
                                FUNC_ch_order: begin // Change_channel_order
                                    output_ch_to_Y_initial <= num_1[10:0];
                                    input_ch_to_Y_initial <= num_2[10:0];
                                end
                                FUNC_posp_param: begin // Change_postprocess_parameter
                                    posp_param <= {num_1[15:0], num_2[15:0]};
                                end
                                FUNC_requant_param_0: begin // Change_requantization_parameter
                                    requant_param[182:122] <= {num_1[28:0], num_2[31:0]};
                                end
                                FUNC_requant_param_1: begin // Change_requantization_parameter
                                    requant_param[121:61] <= {num_1[28:0], num_2[31:0]};
                                end
                                FUNC_requant_param_2: begin // Change_requantization_parameter
                                    requant_param[60:0] <= {num_1[28:0], num_2[31:0]};
                                end
                                default: begin
                                    // none
                                end
                            endcase
                        end
                        CLASS_dram: begin
                            case (op_func)
                                FUNC_get_weight: begin // get_weight
                                    weight_loader_buffer_sel <= num_2[8:7];
                                    weight_amount <= num_1[11:0];
                                    bias_amount   <= num_2[6:0];
                                    weight_loader_en <= 1;
                                end
                                FUNC_get_instruction: begin // get_instruction
                                    IS_amount <= num_1[7:0];
                                    VLIW_amount <= num_2[9:0];
                                    instruction_loader_en <= 1;
                                end
                                default: begin
                                    // none
                                end
                            endcase
                        end
                        CLASS_control: begin
                            case (op_func)
                                FUNC_run_VLIW: begin
                                    VLIW_initial <= num_1[9:0];
                                    VLIW_length <= num_2[9:0];
                                    lower_controller_en <= 1;
                                end
                                FUNC_wait: begin
                                    // none
                                end
                                FUNC_finish: begin
                                    // none
                                end
                                default: begin
                                    // none
                                end
                            endcase
                        end
                    endcase
                end
                S_wait: begin
                    // none
                end
                default: begin
                    // none
                end
            endcase
        end
    end
    ////////// FSM and register end //////////
    
endmodule