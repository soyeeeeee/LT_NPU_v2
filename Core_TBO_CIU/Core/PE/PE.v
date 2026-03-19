`timescale 1ns / 1ps

// delay = 4 cycle / 2 cycle

module PE(
    input CLK,
    input en,
    input rst,
    input [1:0] PE_mode,
    input signed [15:0] PE_A,
    input signed [15:0] PE_B,
    output reg signed [31:0] PE_out
    );
    
    ////////// SR //////////
    reg [2:0] en_sr;
    always@(posedge CLK) begin
        if(rst) begin
            en_sr <= 0;
        end
        else begin
            en_sr <= {en_sr[1:0], en};
        end
    end
    ////////// SR end //////////
    
    // Mode define
    parameter MAC = 0, GAP = 1, pass = 2;

    ////////// mult_16 //////////
    reg signed [15:0] A_reg, B_reg;
    (* use_dsp = "yes" *) reg signed [31:0] mult_reg;
    reg signed [31:0] P;
    // stage 1
    always@(posedge CLK) begin
        if(rst) begin
            A_reg <= 0;
            B_reg <= 0;
        end
        else if(en) begin
            A_reg <= PE_A;
            B_reg <= PE_B;
        end
    end
    // stage 2
    always@(posedge CLK) begin
        if(rst) begin
            mult_reg <= 0;
        end
        else if(en_sr[0]) begin
            mult_reg <= A_reg * B_reg;
        end
    end
    // stage 3
    always@(posedge CLK) begin
        if(rst) begin
            P <= 0;
        end
        else if(en_sr[1]) begin
            P <= mult_reg;
        end
    end
    ////////// mult_16 end //////////
    
    ////////// shift_right_4 //////////
    reg signed [31:0] A_shift;
    always@(posedge CLK) begin
        if(rst==1) A_shift <= 0;
        else A_shift <= {{12{PE_A[15]}}, PE_A, 4'b0};
    end
    ////////// shift_right_4 end //////////

    ////////// pass_through //////////
    reg signed [31:0] A_pass;
    always@(posedge CLK) begin
        if(rst==1) A_pass <= 0;
        else A_pass <= {{8{PE_A[15]}}, PE_A, 8'b0};
    end
    ////////// pass_through end //////////

    ////////// output mux //////////
    reg signed [31:0]out_buffer;
    always@(*) begin
        case(PE_mode)
            MAC: out_buffer = P;
            GAP: out_buffer = A_shift;
            pass: out_buffer = A_pass;
            default: out_buffer = 0;
        endcase
    end
    ////////// output mux end //////////
    
    ////////// output reg //////////
    always@(posedge CLK) begin
        if(rst==1) PE_out <= 0;
        else begin
            case(PE_mode)
                MAC: begin
                    if(en_sr[2] == 1) PE_out <= out_buffer;
                    else PE_out <= 0;
                end
                GAP: begin
                    if(en_sr[0] == 1) PE_out <= out_buffer;
                    else PE_out <= 0;
                end
                pass: begin
                    if(en_sr[0] == 1) PE_out <= out_buffer;
                    else PE_out <= 0;
                end
                default: PE_out <= 0;
            endcase
        end
    end
    ////////// output reg end //////////
endmodule