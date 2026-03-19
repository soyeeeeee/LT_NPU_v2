`timescale 1ns / 1ps

// delay = 3 cycle

module AGU_B(
    input CLK,
    input en,
    input rst,
    input set,
    input [2:0] mode_in,
    input [7:0] AGU_B_initial_in,
    input [6:0] width_out_in,
    input [7:0] ch_in_in,
    input [7:0] ch_out_in,
    output reg [7:0] baddr,
    output reg done
    );
    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;

    ////////// input buffer //////////
    reg [2:0] mode;
    reg [7:0] AGU_B_initial;
    reg [6:0] width_out;
    reg [7:0] ch_out;
    reg [7:0] kernel_L;
    always@(posedge CLK) begin
        if(rst) begin
            mode <= 0;
            AGU_B_initial <= 0;
            width_out <= 0;
            ch_out <= 0;
        end
        else if(set) begin
            mode <= mode_in;
            AGU_B_initial <= AGU_B_initial_in;
            width_out <= width_out_in;
            ch_out <= ch_out_in;
        end
        else begin
            mode <= mode;
            AGU_B_initial <= AGU_B_initial;
            width_out <= width_out;
            ch_out <= ch_out;
        end
    end
    always@(*) begin
        case(mode)
            conv: kernel_L = 8;
            maxpooling: kernel_L = 2;
            DW: kernel_L = 2;
            PW: kernel_L = ch_in_in;
            GAP: kernel_L = 0;
            default: kernel_L = 0;
        endcase
    end
    ////////// input buffer end //////////
    
    ////////// en SR //////////
    reg [1:0] en_SR;
    always@(posedge CLK) begin
        if(rst) begin
            en_SR <= 0;
        end
        else begin
            en_SR <= {en_SR[0], en};
        end
    end

    ////////// Stage 1 //////////
    reg [7:0] k_count,next_k_count;
    reg s1_done;
    reg s2_en;
    always@(posedge CLK) begin
        s2_en <= s1_done & en;
    end
    //counter
    always@(*) begin
        //avoid latch
        next_k_count = k_count;
        s1_done = 0;
        
        //counter logic
        if(k_count == kernel_L) begin
            next_k_count = 0;
            s1_done = 1;
        end
        else begin
            next_k_count = k_count + 1;
            s1_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst == 1) begin
            k_count <= 0;
        end
        else begin
            if(en) begin
                k_count <= next_k_count;
            end
            else begin
                k_count <= k_count;
            end
        end
    end
    ////////// Stage 1 end //////////
    
    ////////// Stage 2 //////////
    reg [7:0] w_count, next_w_count;
    reg s2_done;
    reg s3_en;
    always@(posedge CLK) begin
        s3_en <= s2_done & s2_en;
    end
    always@(*) begin
        next_w_count = w_count;
        s2_done = 0;
        if(w_count == width_out) begin
            next_w_count = 0;
            s2_done = 1;
        end
        else begin
            next_w_count = w_count + 1;
            s2_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            w_count <= 0;
        end
        else begin
            if(s2_en) begin
                w_count <= next_w_count;
            end
            else begin
                w_count <= w_count;
            end
        end
    end
    ////////// Stage 2 end //////////

    ////////// Stage 3 //////////
    reg s3_done;
    reg [7:0] ch_count, next_ch_count;
    always@(*) begin
        s3_done = 0;
        if(ch_count == ch_out) begin
            next_ch_count = 0;
            s3_done = 1;
        end
        else begin
            next_ch_count = ch_count + 1;
            s3_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            ch_count <= 0;
        end
        else begin
            if(s3_en) begin
                ch_count <= next_ch_count;
            end
            else begin
                ch_count <= ch_count;
            end
        end
    end
    
    // adder
    always@(posedge CLK) begin
        if(rst) begin
            baddr <= 0;
        end
        else begin
            if(en_SR[1]) begin
                baddr <= AGU_B_initial + ch_count;
            end
            else begin
                baddr <= baddr;
            end
        end
    end
    ////////// Stage 3 end //////////

    ////////// done signal //////////
    always@(posedge CLK) begin
        if(s3_done && s3_en) begin
            done <= 1;
        end
        else begin
            done <= 0;
        end
    end
    ////////// done signal end //////////

endmodule