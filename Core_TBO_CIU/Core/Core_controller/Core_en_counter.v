`timescale 1ns / 1ps

// delay = 3

module Core_en_counter(
    input CLK,
    input en,
    input rst,
    input set,
    input [2:0] mode,
    input [6:0] width_out_in,
    input [7:0] ch_in_in,
    input [7:0] ch_out_in,
    output SR_0_en,
    output reg done,
    output [7:0] offset_out,
    output [6:0] w_count_out,
    output [7:0] ch_count_out
    );
    
    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;

    ////////// input buffer //////////
    reg [6:0] width_out;
    reg [7:0] ch_in;
    reg [7:0] ch_out;
    reg [7:0] kernel_L;
    always@(posedge CLK) begin
        if(rst) begin
            width_out <= 0;
            ch_in <= 0;
            ch_out <= 0;
        end
        else if(set) begin
            width_out <= width_out_in;
            ch_in <= ch_in_in;
            ch_out <= ch_out_in;
        end
        else begin
            width_out <= width_out;
            ch_in <= ch_in;
            ch_out <= ch_out;
        end
    end
    // kernel_L define
    always@(*) begin
        case (mode)
            conv: kernel_L = 8;
            maxpooling: kernel_L = 2;
            DW: kernel_L = 2;
            PW: kernel_L = ch_in;
            GAP: kernel_L = 3;
            default: kernel_L = 0;
        endcase
    end
    ////////// input buffer end //////////

    ////////// en SR //////////
    reg [1:0] en_SR;
    always@(posedge CLK) begin
        if(rst || done) begin
            en_SR <= 0;
        end
        else begin
            en_SR <= {en_SR[1:0], en};
        end
    end
    assign SR_0_en = en_SR[1];
    ////////// en SR end //////////
    
    ////////// Stage 1 //////////
    reg [7:0] offset,next_offset;
    reg s1_done;
    reg s2_en;
    //assign s2_en = s1_done & en;
    always@(posedge CLK) begin
        if(rst) s2_en <= 0;
        else s2_en <= s1_done & en;
    end
    //counter
    always@(*) begin
        //avoid latch
        next_offset = offset;
        s1_done = 0;
        
        //counter logic
        if(offset < kernel_L) begin
            next_offset = offset + 1;
        end
        else begin
            next_offset = 0;
            s1_done = 1;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            offset <= 0;
        end
        else begin
            if(en) begin
                offset <= next_offset;
            end
            else begin
                offset <= offset;
            end
        end
    end
    ////////// Stage 1 end //////////

    ////////// Stage 2 //////////
    //counter w_count
    reg [6:0] w_count,next_w_count;
    reg s2_done;
    reg s3_en;
    //assign s3_en = s2_done & s2_en;
    always@(posedge CLK) begin
        if(rst) s3_en <= 0;
        else s3_en <= s2_done & s2_en;
    end
    always@(*) begin
        next_w_count = w_count;
        s2_done = 0;
        if(w_count < width_out) begin
            next_w_count = w_count + 1;
            s2_done = 0;
        end
        else begin
            next_w_count = 0;
            s2_done = 1;
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
    reg [7:0] ch_count,next_ch_count;
    reg s3_done;
    //counter ch_count & L
    always@(*) begin
        //avoid latch
        next_ch_count = ch_count;
        s3_done = 0;

        //counter logic
        if(ch_count < ch_out) begin
            next_ch_count = ch_count + 1;
            s3_done = 0;
        end
        else begin
            next_ch_count = 0;
            s3_done = 1;
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
    ////////// Stage 3 end //////////

    //done logic
    always@(*) begin
        done = 0;
        if(en) begin
            if(s3_done && s3_en) begin
                done = 1;
            end
            else begin
                done = 0;
            end
        end
        else begin
            done = 0;
        end
    end
    
    // debug
    assign offset_out = offset;
    assign w_count_out = w_count;
    assign ch_count_out = ch_count;
    
endmodule