`timescale 1ns / 1ps

// delay = 5 cycle

module Requantizer(
    input CLK,
    input en,
    input rst,
    input set,
    input requantization,
    input [4:0] shift_in,
    input signed [15:0] factor,
    input signed [39:0] zp,
    input signed [23:0] requant_in,
    output reg signed [7:0] requant_out,
    output requant_done
    );
    
    ////////// SR //////////
    reg [4:0] en_sr;
    always@(posedge CLK) begin
        if(rst) begin
            en_sr <= 0;
        end
        else begin
            en_sr <= {en_sr[3:0], en};
        end
    end
    assign requant_done = en_sr[4];
    ////////// SR end //////////

    ////////// Stage 1 reg //////////
    reg signed [23:0] A_reg;
    reg signed [15:0] B_reg;
    reg signed [39:0] C_reg;
    reg [4:0] shift;

    always@(posedge CLK) begin
        if(rst) begin
            A_reg <= 0;
        end
        else begin
            if(en) begin
                A_reg <= requant_in;
            end
            else begin
                A_reg <= A_reg;
            end
        end
    end
    
    always@(posedge CLK) begin
        if(rst) begin
            B_reg <= 0;
            C_reg <= 0;
            shift <= 0;
        end
        else begin
            if(set) begin
                B_reg <= factor;
                C_reg <= zp;
                shift <= shift_in;
            end
            else begin
                B_reg <= B_reg;
                C_reg <= C_reg;
                shift <= shift;
            end
        end
    end
    ////////// Stage 1 reg end //////////

    ////////// Stage 2 reg //////////
    reg signed [39:0] P_reg;
    reg signed [7:0] A_reg_1;
    
    always@(posedge CLK) begin
        if(rst) begin
            P_reg <= 0;
            A_reg_1 <= 0;
        end
        else begin
            if(en_sr[0]) begin
                P_reg <= A_reg * B_reg;
                A_reg_1 <= A_reg[7:0];
            end
            else begin
                P_reg <= P_reg;
                A_reg_1 <= A_reg_1;
            end
        end
    end
    ////////// Stage 2 reg end //////////

    ////////// Stage 3 reg //////////
    reg signed [39:0] P_add_C_reg;
    reg signed [7:0] A_reg_2;
    
    always@(posedge CLK) begin
        if(rst) begin
            P_add_C_reg <= 0;
            A_reg_2 <= 0;   
        end
        else begin
            if(en_sr[1]) begin
                P_add_C_reg <= P_reg + C_reg;
                A_reg_2 <= A_reg_1;
            end
            else begin
                P_add_C_reg <= P_add_C_reg;
                A_reg_2 <= A_reg_2;
            end
        end
    end
    ////////// Stage 3 reg end //////////

    ////////// Stage 4 reg //////////
    reg signed [39:0] shift_reg; // 改為 [39:0] 以避免截斷
    reg signed [7:0] A_reg_3;
    
    always@(posedge CLK) begin
        if(rst) begin
            shift_reg <= 0;
            A_reg_3 <= 0;
        end
        else begin
            if(en_sr[2]) begin
                shift_reg <= P_add_C_reg >>> shift;
                A_reg_3 <= A_reg_2;
            end
            else begin
                shift_reg <= shift_reg;
                A_reg_3 <= A_reg_3;
            end
        end
    end
    ////////// Stage 4 reg end //////////

    ////////// Stage 5 (output) ////////// 
    always@(posedge CLK) begin
        if(rst) begin
            requant_out <= 0;
        end
        else begin
            if(en_sr[3]) begin
                case(requantization)
                    1'b1: begin
                        if(shift_reg[39:7] != {33{shift_reg[7]}}) begin
                            if(shift_reg[39] == 0) begin
                                requant_out <= 8'h7F;
                            end
                            else begin
                                requant_out <= 8'h80;
                            end
                        end
                        else begin
                            requant_out <= shift_reg[7:0];
                        end
                    end
                    1'b0: begin
                        requant_out <= A_reg_3;
                    end
                    default: begin
                        requant_out <= shift_reg[7:0];
                    end
                endcase
            end
            else begin
                requant_out <= requant_out;
            end
        end
    end
    ////////// Stage 5 end //////////

endmodule