`timescale 1ns / 1ps

module GLB_input_controller(
    input CLK,
    input en,
    input rst,
    input wb_data_valid,
    // AGU_T
    input AGU_G_done,
    input AGU_T_done,
    output reg set,
    output reg AGU_T_en,
    output reg [5:0] SR,
    output reg done,
    output reg glb_input_busy,
    output reg glb_in_rst
    );
    
    ////////// state define //////////
    reg [2:0] state, next_state;
    parameter idle = 0, set_up = 1, processing = 2, ending = 3, finish = 4;
    ////////// state define end //////////

    ////////// FSM //////////
    always@(*) begin
        //avoid latch
        done = 0;
        AGU_T_en = 0;
        glb_in_rst = 0;
        set = 0;
        glb_input_busy = 0;

        case(state)
            idle: begin
                glb_in_rst = 1;
                if(en) begin
                    next_state = set_up;
                end
                else begin
                    next_state = idle;
                end
            end
            set_up : begin
                set = 1;
                glb_input_busy = 1;
                next_state = processing;
            end
            processing: begin
                AGU_T_en = 1;
                glb_input_busy = 1;
                if(AGU_T_done) begin
                    next_state = ending;
                end
                else begin
                    next_state = processing;
                end
            end
            ending: begin
                glb_input_busy = 1;
                if(AGU_G_done) begin
                    next_state = finish;
                end
                else begin
                    next_state = ending;
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
    // SR
    always@(posedge CLK) begin
        if(rst) begin
            SR <= 0;
        end
        else begin
            if(state == processing || state == ending) begin
                SR <= {SR[4:0], wb_data_valid};
            end
            else begin
                SR <= 0;
            end
        end
    end
    ////////// SR end //////////
    
endmodule