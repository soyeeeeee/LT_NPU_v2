`timescale 1ns / 1ps

// delay = 4 cycle

module AGU_F(
    input CLK,
    input en,
    input rst,
    input set,
    input padding_in,
    input [6:0] width_in_in,    // Map Width (0~127)
    input [6:0] width_out_in,   // down sampling
    input [7:0] ch_in_in,
    input [7:0] ch_out_in,      // channel may vary per layer
    input [2:0] mode_in,
    input [1:0] stride_X_in,
    output reg [7:0] faddr,
    output reg boundary,
    output reg done
    ); 

    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;

    ////////// input buffer & parameter generate //////////
    reg padding;
    reg [2:0] mode;
    reg [6:0] width_in;
    reg [6:0] width_out;
    reg [7:0] ch_in;
    reg [7:0] ch_out;
    reg [1:0] stride_X;
    reg [7:0] stride_Y;
    reg [1:0] AGU_offset_X;
    reg [7:0] ch_stride;
    always@(posedge CLK) begin
        if(rst) begin
            stride_Y <= 0;
            AGU_offset_X <= 0;
        end
        else if(set) begin
            case (mode_in)
                conv: begin
                    stride_Y <= 0;
                    AGU_offset_X <= 2;
                end
                maxpooling: begin
                    stride_Y <= width_in_in + 1;
                    AGU_offset_X <= 2;
                end
                DW: begin
                    stride_Y <= width_in_in + 1;
                    AGU_offset_X <= 2;
                end
                PW: begin
                    stride_Y <= 0;
                    AGU_offset_X <= 0;
                end
                GAP: begin
                    stride_Y <= width_in_in + 1;
                    AGU_offset_X <= 3;
                end
                default: begin
                    stride_Y <= width_in_in + 1;
                    AGU_offset_X <= 0;
                end
            endcase
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            mode <= 0;
            padding <= 0;
            stride_X <= 0;
            width_in <= 0;
            width_out <= 0;
            ch_in <= 0;
            ch_out <= 0;
            ch_stride <= 0;
        end
        else if(set) begin
            mode <= mode_in;
            padding <= padding_in;
            stride_X <= stride_X_in;
            width_in <= width_in_in;
            width_out <= width_out_in;
            ch_in <= ch_in_in;
            ch_out <= ch_out_in;
            ch_stride <= width_in_in + 1;
        end
    end
    ////////// input buffer & parameter generate end //////////
    
    ////////// adder delay chain //////////
    reg [2:0] adder_en;
    always@(posedge CLK) begin
        if(rst) begin
            adder_en <= 0;
        end
        else begin
            adder_en <= {adder_en[1:0], en};
        end
    end
    ////////// adder delay chain end //////////

    ////////// Stage 1 //////////
    reg [7:0] ch_count_0, next_ch_count_0;
    reg [7:0] offset_Y, next_offset_Y;
    reg s1_done;
    reg s2_en;
    always@(posedge CLK) begin
        if(rst) s2_en <= 0;
        else s2_en <= s1_done & en;
    end
    // GAP skip
    wire gap_skip = (mode == GAP) ? 1'b1: 1'b0;
    // counter offset_Y
    always@(*) begin
        s1_done = 0;
        next_offset_Y = offset_Y;
        if (padding || gap_skip) begin
            next_offset_Y = 0;
            next_ch_count_0 = 0;
            s1_done = 1;
        end
        else begin
            if (ch_count_0 == ch_in) begin
                next_offset_Y = 0;
                next_ch_count_0 = 0;
                s1_done = 1;
            end
            else begin
                next_offset_Y = offset_Y + ch_stride;
                next_ch_count_0 = ch_count_0 + 1;
                s1_done = 0;
            end
        end
    end
    always@(posedge CLK) begin        
        if(rst) begin
            offset_Y <= 0;
            ch_count_0 <= 0;
        end
        else begin
            if(en) begin
                offset_Y <= next_offset_Y;
                ch_count_0 <= next_ch_count_0;
            end
            else begin
                offset_Y <= offset_Y;
                ch_count_0 <= ch_count_0;
            end
        end
    end

    //adder
    reg [7:0] adder_1;
    always@(posedge CLK) begin
        if(rst) begin
            adder_1 <= 0;
        end
        else begin
            if(en) begin
                adder_1 <= offset_Y;
            end
            else begin
                adder_1 <= adder_1;
            end
        end
    end
    ////////// Stage 1 end //////////

    ////////// Stage 2 //////////
    reg [1:0] offset_X, next_offset_X;
    reg s2_done;
    reg s3_en;
    always@(posedge CLK) begin
        if(rst) s3_en <= 0;
        else s3_en <= s2_done & s2_en;
    end
    //counter offset_X
    always@(*) begin
        s2_done = 0;
        if (offset_X == AGU_offset_X) begin
            next_offset_X = 0;
            s2_done = 1;
        end
        else begin
            next_offset_X = offset_X + 1;
            s2_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            offset_X <= 0;
        end
        else begin
            if(s2_en) begin
                offset_X <= next_offset_X;
            end
            else begin
                offset_X <= offset_X;
            end
        end
    end

    //adder
    reg [7:0] adder_2;  
    always@(posedge CLK) begin
        if(rst) begin
            adder_2 <= 0;
        end
        else begin
            if(adder_en[0]) begin
                adder_2 <= adder_1 + offset_X;
            end
            else begin
                adder_2 <= adder_2;
            end
        end
    end
    ////////// Stage 2 end //////////

    ////////// Stage 3 //////////
    reg [7:0] x_count,next_x_count;
    reg [8:0] X, next_X; //max 127
    reg s3_done;
    reg s4_en;
    always@(posedge CLK) begin
        if(rst) s4_en <= 0;
        else s4_en <= s3_done & s3_en;
    end
    //counter X & x_count
    always@(*) begin
        // Default Assignments (防止 Latch)
        next_X = X;
        next_x_count = x_count;
        s3_done = 0;
        if (x_count == width_out) begin
            next_X = 0;
            next_x_count = 0;
            s3_done = 1;
        end
        else begin
            next_X = X + stride_X;
            next_x_count = x_count + 1;
            s3_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            X <= 0;
            x_count <= 0;
        end
        else begin
            if(s3_en) begin
                X <= next_X;
                x_count <= next_x_count;
            end
            else begin
                X <= X;
                x_count <= x_count;
            end
        end
    end
    
    //adder
    reg [7:0] adder_3;
    always@(posedge CLK) begin
        if(rst) begin
            adder_3 <= 0;
        end
        else begin
            if(adder_en[1]) begin
                adder_3 <= adder_2 + X;
            end
            else begin
                adder_3 <= adder_3;
            end
        end
    end
    ////////// Stage 3 end //////////

    ////////// Stage 4 //////////
    reg [7:0] ch_count_1, next_ch_count_1;
    reg [7:0] Y, next_Y;
    reg s4_done;
    //counter Y & ch_count_1
    always@(*) begin
        // Default Assignments (防止 Latch)
        next_Y = Y;
        next_ch_count_1 = ch_count_1;
        s4_done = 0;
        if (ch_count_1 == ch_out) begin
            next_Y = 0;
            next_ch_count_1 = 0;
            s4_done = 1;
        end
        else begin
            next_Y = Y + stride_Y;
            next_ch_count_1 = ch_count_1 + 1;
            s4_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            Y <= 0;
            ch_count_1 <= 0;
        end
        else begin
            if(s4_en) begin
                Y <= next_Y;
                ch_count_1 <= next_ch_count_1;
            end
            else begin
                Y <= Y;
                ch_count_1 <= ch_count_1;
            end
        end
    end
    
    //adder
    always@(posedge CLK) begin
        if(rst) begin
            faddr <= 0;
        end
        else begin
            if(adder_en[2]) begin
                faddr <= adder_3 + Y - padding;
            end
            else begin
                faddr <= faddr;
            end
        end
    end
    ////////// Stage 4 end //////////
    
    //boundary signal
    wire boundary_cond = ( (adder_3 == 0) || (adder_3 > width_in + 1) ) ? 1 : 0;
    always@(posedge CLK) begin
        if ( (padding == 1) && boundary_cond) begin
            boundary <= 1;
        end
        else boundary <= 0;
    end
    
    //done logic
    always@(posedge CLK) begin
        if( s4_done && s4_en) begin
            done <= 1;
        end
        else begin
            done <= 0;
        end 
    end
    
endmodule 