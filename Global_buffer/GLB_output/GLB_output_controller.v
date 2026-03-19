`timescale 1ns / 1ps

module GLB_output_controller(
    input CLK,
    input en,
    input rst,
    // AGU_G
    output reg AGU_G_en,
    input AGU_G_done,
    input AGU_G_en_next,
    // output
    output reg set,
    output reg [9:0] SR,
    output reg done,
    output reg glb_output_busy,
    output reg glb_out_rst
    );
    
    ////////// state define //////////
    reg [2:0] state, next_state;
    parameter idle = 0, set_up = 1, processing = 2, ending = 3, finish = 4;
    ////////// state define end //////////

    ////////// FSM //////////
    always@(*) begin
        //avoid latch
        next_state = state;
        done = 0;
        AGU_G_en = 0;
        set = 0;
        glb_out_rst = 0;
        glb_output_busy = 0;
        
        case(state)
            idle: begin
                glb_out_rst = 1;
                if(en) begin
                    next_state = set_up;
                end
                else begin
                    next_state = idle;
                end
            end
            set_up: begin
                set = 1;
                glb_output_busy = 1;
                next_state = processing;
            end
            processing: begin
                AGU_G_en = 1;
                glb_output_busy = 1;
                if(AGU_G_done) begin
                    next_state = ending;
                end
                else begin
                    next_state = processing;
                end
            end
            ending: begin
                glb_output_busy = 1;
                if(SR != 0) begin
                    next_state = ending;
                end
                else begin
                    next_state = finish;
                end
            end
            finish: begin
                done = 1;
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

    ////////// SR //////////
    // SR_1
    always@(posedge CLK) begin
        if(rst) begin
            SR <= 0;
        end
        else begin
            SR <= {SR[8:0], AGU_G_en_next};
        end
    end
    ////////// SR end //////////

endmodule