`timescale 1ns / 1ps

module Core_controller(
    input CLK,
    input en,
    input rst,
    // SR control
    input [2:0] mode_in,
    input acc_done,
    // Core en counter control
    input [6:0] width_out_in,
    input [7:0] ch_in_in,
    input [7:0] ch_out_in,
    // FSM control
    input AGU_O_done,
    // output
    output reg set,
    output reg [12:0] SR_0,
    output reg [5:0] SR_1,
    output reg core_done,
    output reg core_busy,
    output reg core_rst
    );
    
    ////////// state define //////////
    parameter idle = 0, set_up = 1, processing = 2, ending = 3, finish = 4;
    ////////// state define end //////////

    ////////// parameter define //////////
    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;
    ////////// parameter define end //////////

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

    ////////// Core en counter //////////
    reg core_en_counter_en;
    wire core_en_counter_done;
    wire SR_0_en;
    Core_en_counter core_en_counter(
        .CLK(CLK),
        .en(core_en_counter_en),
        .rst(core_rst),
        .set(set),
        .mode(mode_in),
        .width_out_in(width_out_in),
        .ch_in_in(ch_in_in),
        .ch_out_in(ch_out_in),
        .SR_0_en(SR_0_en),
        .done(core_en_counter_done)
    );
    ////////// Core en counter end //////////
    
    ////////// FSM //////////
    reg [2:0] state, next_state;
    always@(*) begin
        //avoid latch
        next_state = state;
        core_done = 0;
        core_en_counter_en = 0;
        core_rst = 0;
        set = 0;
        core_busy = 0;
        
        case(state)
            idle: begin
                core_rst = 1;
                if(en) begin
                    next_state = set_up;
                end
                else begin
                    next_state = idle;
                end
            end
            set_up: begin
                next_state = processing;
                core_busy = 1;
                set = 1;
            end
            processing: begin
                core_en_counter_en = 1;
                core_busy = 1;
                if(core_en_counter_done) begin
                    next_state = ending;
                end
                else begin
                    next_state = processing;
                end
            end
            ending: begin
                core_busy = 1;
                if(AGU_O_done) begin
                    next_state = finish;
                end
                else begin
                    next_state = ending;
                end
            end
            finish: begin
                core_done = 1;
                if(en) begin
                    next_state = finish;
                end
                else begin
                    next_state = idle;
                end
            end
            default: begin
                next_state = idle;
            end
        endcase
    end
    always@(posedge CLK) begin
        if(rst) begin
            state <= idle;
        end
        else begin
            state <= next_state;
        end
    end
    ////////// FSM end //////////

    ////////// SR_0 //////////
    always@(posedge CLK) begin
        if (core_rst) begin
            SR_0 <= 13'b0;
        end
        else begin
            case(mode)
                maxpooling, GAP: begin
                    if(state == processing) begin 
                        SR_0 <= {SR_0[11], SR_0[8], 2'b0, SR_0[7:0], SR_0_en};
                    end
                    else if(state == ending) begin
                        SR_0 <= {1'b1, SR_0[10:0], 1'd0};
                    end
                    else begin
                        SR_0 <= SR_0;
                    end
                end
                default: begin
                    if(state == processing) begin 
                        SR_0 <= {SR_0[11:0], SR_0_en};
                    end
                    else if(state == ending) begin
                        SR_0 <= {1'b1, SR_0[10:0], 1'd0};
                    end
                    else begin
                        SR_0 <= SR_0;
                    end
                end
            endcase
        end
    end
    ////////// SR_0 end //////////

    ////////// SR_1 //////////
    always@(posedge CLK) begin
        if(core_rst) begin
            SR_1 <= 6'b0;
        end
        else begin
            if(state == processing || state == ending) begin
                SR_1 <= {SR_1[4:0], acc_done};
            end
            else begin
                SR_1 <= SR_1;
            end
        end
    end
    ////////// SR_1 end //////////

endmodule