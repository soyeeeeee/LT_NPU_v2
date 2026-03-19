`timescale 1ns / 1ps

//delay = 4 cycle

module Accumulator(
    input CLK,
    input rst,
    input en,
    input set,
    input [2:0]mode_in,
    input load_bias,
    input ReLU_en,
    input [7:0] ch_in,
    input signed [31:0]bias,
    input signed [31:0]PE_out_0_in,
    input signed [31:0]PE_out_1_in,
    input signed [31:0]PE_out_2_in,
    input signed [31:0]PE_out_3_in,
    output reg signed [15:0]acc_out,
    output acc_done
    );
    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;
    
    ////////// input buffer & signal generate //////////
    reg [7:0] kernel_L;
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
    always@(*) begin
        case(mode)
            conv: kernel_L = 8;
            maxpooling: kernel_L = 2;
            DW: kernel_L = 2;
            PW: kernel_L = ch_in;
            GAP: kernel_L = 3;
            default: kernel_L = 0;
        endcase
    end
    reg signed [32:0] PE_out_0, PE_out_1, PE_out_2, PE_out_3;
    always@(*) begin
        PE_out_0 = {{1{PE_out_0_in[31]}}, PE_out_0_in};
        PE_out_1 = {{1{PE_out_1_in[31]}}, PE_out_1_in};
        PE_out_2 = {{1{PE_out_2_in[31]}}, PE_out_2_in};
        PE_out_3 = {{1{PE_out_3_in[31]}}, PE_out_3_in};
    end
    ////////// signal generate end //////////

    ////////// Stage 1 counter //////////
    reg [7:0] acc_count, next_acc_count;

    // reset bias
    reg rst_bias;
    always@(*) begin
        if(acc_count == 0) begin
            rst_bias = 1;
        end
        else begin
            rst_bias = 0;
        end
    end

    // acc_count
    reg done, next_done;
    always@(*) begin
        next_acc_count = acc_count;
        next_done = 0;
        if(acc_count < kernel_L) begin
            next_acc_count = acc_count + 1;
        end
        else begin
            next_acc_count = 0;
            next_done = 1;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            acc_count <= 0;
            done <= 0;
        end
        else begin
            if(en) begin
                acc_count <= next_acc_count;
                done <= next_done;
            end
            else begin
                acc_count <= acc_count;
                done <= done;
            end
        end
    end
    //////////// Stage 1 counter end //////////

    ////////// SR //////////
    reg [1:0] rst_bias_sr;
    reg [1:0] en_sr;
    reg [2:0] done_sr;
    always@(posedge CLK) begin
        if(rst) begin
            rst_bias_sr <= 0;
            en_sr <= 0;
            done_sr <= 0;
        end
        else begin
            rst_bias_sr <= {rst_bias_sr[0], rst_bias};
            en_sr <= {en_sr[0], en};
            done_sr <= {done_sr[1:0], done};
        end
    end
    assign acc_done = done_sr[1];
    ////////// SR end //////////
    
    ////////// Stage 1 ////////// 
    // adder tree
    reg signed [32:0] add_buffer_10, add_buffer_11;
    always@(posedge CLK) begin
        if(rst) begin
            add_buffer_10 <= 0;
            add_buffer_11 <= 0;
        end
        else begin
            add_buffer_10 <= PE_out_0 + PE_out_1;
            add_buffer_11 <= PE_out_2 + PE_out_3;
        end
    end
    // compare chain
    wire signed [15:0] PE_out_0_trunc = PE_out_0[23:8];
    wire signed [15:0] PE_out_1_trunc = PE_out_1[23:8];
    reg signed [15:0] PE_out_2_trunc;
    wire signed [15:0] comp_1_out;
    reg signed [15:0] comp_result_1;
    always@(posedge CLK) begin
        if(rst) begin
            PE_out_2_trunc <= 0;
        end
        else begin
            if(en) begin
                PE_out_2_trunc <= PE_out_2[23:8];
            end
            else begin
                PE_out_2_trunc <= PE_out_2_trunc;
            end
        end
    end
    // comp_1
    Comparator comp_1(
        .comp_a(PE_out_0_trunc), 
        .comp_b(PE_out_1_trunc), 
        .comp_out(comp_1_out)
    );
    always@(posedge CLK) begin
        if(rst) begin
            comp_result_1 <= 0;
        end
        else begin
            if(en) begin
                comp_result_1 <= comp_1_out;
            end
            else begin
                comp_result_1 <= comp_result_1;
            end
        end
    end
    ////////// Stage 1 end //////////

    ////////// Stage 2 //////////
    // adder tree
    reg signed [33:0] adder_result;
    wire signed [33:0] add_buffer_10_ext = {add_buffer_10[32], add_buffer_10};
    wire signed [33:0] add_buffer_11_ext = {add_buffer_11[32], add_buffer_11};
    always@(posedge CLK) begin
        if(rst) adder_result <= 0;
        else adder_result <= add_buffer_10_ext + add_buffer_11_ext;
    end
    // compare chain
    wire signed [15:0] comp_2_out;
    reg signed [15:0] comp_result_2;
    Comparator comp_2(
        .comp_a(comp_result_1), 
        .comp_b(PE_out_2_trunc), 
        .comp_out(comp_2_out)
    );
    always@(posedge CLK) begin
        if(rst) begin
            comp_result_2 <= 0;
        end
        else begin
            if(en_sr[0]) begin
                comp_result_2 <= comp_2_out;
            end
            else begin
                comp_result_2 <= comp_result_2;
            end
        end
    end
    ////////// Stage 2 end //////////
    
    ////////// bias buffer //////////
    reg signed [31:0] bias_buffer;
    always@(posedge CLK) begin
        if(rst) begin
            bias_buffer <= 0;
        end
        else begin
            if(load_bias) begin
                bias_buffer <= bias;
            end
            else begin
                bias_buffer <= bias_buffer;
            end
        end
    end
    ////////// bias buffer end //////////

    ////////// Stage 3 //////////
    // accumulate
    (* use_dsp = "yes" *) reg signed [47:0] accumulator_reg;
    wire signed [47:0] bias_ext = (mode == maxpooling || mode == GAP) ? 48'sd0 : {{16{bias_buffer[31]}}, bias_buffer};
    wire signed [47:0] adder_result_ext = {{14{adder_result[33]}}, adder_result};
    always@(posedge CLK) begin
        if(rst == 1) begin
            accumulator_reg <= 0;
        end
        else begin
            if(en_sr[1]) begin
                if(rst_bias_sr[1]) begin
                    accumulator_reg <= adder_result_ext + bias_ext;
                end
                else begin
                    accumulator_reg <= adder_result_ext + accumulator_reg;
                end
            end
            else begin
                accumulator_reg <= accumulator_reg;
            end
        end
    end
    // running comparator
    reg signed [15:0] comp_result;
    wire signed [15:0] comp_3_out;
    Comparator comp_3(
        .comp_a(comp_result_2), 
        .comp_b(comp_result), 
        .comp_out(comp_3_out)
    );
    always@(posedge CLK) begin
        if(rst) begin
            comp_result <= 16'h8000;
        end
        else begin
            if(rst_bias_sr[1]) begin
                comp_result <= comp_result_2;
            end
            else if(en_sr[1]) begin
                comp_result <= comp_3_out;
            end
            else begin
                comp_result <= comp_result;
            end
        end
    end
    ////////// Stage 3 end //////////
    
    ////////// acc_result Truncate //////////
    reg signed [15:0] acc_out_truncated;
    always@(*) begin
        if(accumulator_reg[47:23] != {25{accumulator_reg[23]}}) begin
            //overflow
            if(accumulator_reg[47] == 0) begin
                acc_out_truncated = 16'h7FFF; //max pos
            end
            else begin
                acc_out_truncated = 16'h8000; //max neg
            end
        end
        else begin
            acc_out_truncated = accumulator_reg[23:8];
        end
    end
    ////////// acc_result Truncate end //////////

    ////////// Output register && ReLU //////////
    always@(posedge CLK) begin
        if(rst) begin
            acc_out <= 0;
        end
        else begin
            case(mode)
            maxpooling: begin
                acc_out <= comp_result;
            end
            default: begin
                if(ReLU_en == 1) begin
                    if(acc_out_truncated[15] == 0) begin
                        acc_out <= acc_out_truncated;
                    end
                    else begin
                        acc_out <= 16'd0;
                    end
                end
                else begin
                    acc_out <= acc_out_truncated;
                end
            end
            endcase
        end
    end
    ////////// Output register end //////////
    
endmodule