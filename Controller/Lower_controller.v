`timescale 1ns / 1ps

module Lower_controller(
    input CLK,
    input en,
    input rst,
    input [9:0] VLIW_initial,
    input [9:0] VLIW_length,
    
    ////////// Instruction memory interface //////////
    output [10:0] VLIW_PC_bus, // {en, 10 bit address}
    input [143:0] VLIW,
    
    ////////// Submodule Busy signals //////////
    input [10:0] lower_busy_bus, // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}

    ////////// Control signals and VLIW_num //////////
    output reg [10:0] lower_en_bus, // {Core_1, Core_2, Core_3, Core_4, Core_5, Core_6, GLB_out, GLB_in, CIU, PreP, PosP}
    output reg [132:0] VLIW_num, // VLIW number

    ////////// System status //////////
    output reg lower_controller_busy
);

    ////////// Instruction Decoding //////////
    wire [10:0] VLIW_en   = VLIW[143:133];
    ////////// Instruction Decoding end //////////

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

    ////////// Instruction RAM interface //////////
    // PC
    reg [9:0] PC;
    reg [9:0] count;
    reg PC_en;
    assign VLIW_PC_bus = {PC_en, PC};
    always@(posedge CLK) begin
        if(rst) begin
            PC <= 0;
            count <= 0;
        end
        else if(state == S_idle) begin
            PC <= VLIW_initial;
            count <= 0;
        end
        else begin
            PC <= PC + PC_en;
            count <= count + PC_en;
        end
    end
    ////////// Instruction RAM interface end //////////

    ////////// Next State Logic and PC_en //////////
    always @(*) begin
        next_state = state;
        PC_en = 0;
        lower_controller_busy = 0;

        case (state)
            S_idle: begin
                if(en) next_state = S_set_0;
                else next_state = S_idle;
            end
            S_set_0: begin
                PC_en = 1;
                lower_controller_busy = 1;
                next_state = S_set_1;
            end
            S_set_1: begin
                lower_controller_busy = 1;
                PC_en = 1;
                next_state = S_decode;
            end
            S_decode: begin // decode
                lower_controller_busy = 1;
                PC_en = 1;
                if(count == VLIW_length + 3) begin   
                    next_state = S_finish;
                end
                else begin
                    next_state = S_buffer_0;
                end
            end
            S_buffer_0: begin
                lower_controller_busy = 1;
                PC_en = 0;
                next_state = S_buffer_1;
            end
            S_buffer_1: begin
                lower_controller_busy = 1;
                PC_en = 0;
                next_state = S_wait;
            end
            S_wait: begin // wait
                PC_en = 0;
                lower_controller_busy = 1;
                if( lower_busy_bus != 11'd0 ) begin
                    next_state = S_wait; // Stay in wait state until all are done
                end
                else begin
                    next_state = S_decode; // Go back to decode next instruction
                end
            end
            S_finish: begin
                lower_controller_busy = 0; // Notify PS
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
        if(rst) begin
            state <= S_idle;
            lower_en_bus <= 11'd0;
            VLIW_num <= 0;
        end
        else begin
            state <= next_state;
            lower_en_bus <= 11'd0;
            case (state)
                S_idle: begin
                    lower_en_bus <= 11'd0;
                    VLIW_num <= 0;
                end
                S_decode: begin
                    if(count == VLIW_length + 3) begin
                        lower_en_bus <= 11'd0; // No more instructions, disable all submodules
                        VLIW_num <= VLIW_num;
                    end
                    else begin
                        lower_en_bus <= VLIW_en; // Enable the submodules according to the instruction
                        VLIW_num <= VLIW[132:0];
                    end
                end
                S_wait: begin
                    lower_en_bus <= 11'd0; // Disable all submodules while waiting
                    VLIW_num <= VLIW_num;
                end
                default: begin
                    lower_en_bus <= 11'd0; // Default to disabling all submodules
                    VLIW_num <= VLIW_num;
                end
            endcase
        end
    end
    ////////// FSM and register end //////////
    
endmodule