`timescale 1ns / 1ps

// delay = 3

module AGU_W(
    input CLK,
    input en,
    input rst,
    input set,
    input [2:0] mode_in,
    input [11:0] AGU_W_initial_in,
    input [6:0] width_out_in, //64(0~63) => conv 1
    input [7:0] ch_in_in,
    input [7:0] ch_out_in,    //channel may vary per layer
    output reg [11:0] Waddr,
    output reg done
    );
    
    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;

    ////////// input buffer ////////// (2 cycle)
    reg [11:0] AGU_W_initial;
    reg [6:0] width_out;
    reg [7:0] ch_in;
    reg [7:0] ch_out;
    reg [7:0] kernel_L;
    reg [2:0] mode;
    always@(posedge CLK) begin
        if(rst) begin
            mode <= 0;
            AGU_W_initial <= 0;
            width_out <= 0;
            ch_in <= 0;
            ch_out <= 0;
        end
        else if(set) begin
            mode <= mode_in;
            AGU_W_initial <= AGU_W_initial_in;
            width_out <= width_out_in;
            ch_in <= ch_in_in;
            ch_out <= ch_out_in;
        end
        else begin
            mode <= mode;
            AGU_W_initial <= AGU_W_initial;
            width_out <= width_out;
            ch_in <= ch_in;
            ch_out <= ch_out;
        end
    end
    // kernel_L define
    always@(posedge CLK) begin
        case (mode)
            conv: kernel_L <= 8;
            maxpooling: kernel_L <= 0;
            DW: kernel_L <= 2;
            PW: kernel_L <= ch_in;
            GAP: kernel_L <= 0;
            default: kernel_L <= 0;
        endcase
    end
    wire [11:0] k_stride = kernel_L + 1;
    ////////// input buffer end //////////

    ////////// en SR //////////
    reg [1:0] adder_en;
    always@(posedge CLK) begin
        if(rst == 1) begin
            adder_en <= 0;
        end
        else begin
            adder_en <= {adder_en[0], en};
        end
    end
    ////////// en SR end //////////
    
    ////////// Stage 1 //////////
    reg [8:0] offset,next_offset;
    reg s1_done;
    reg s2_en;
    always@(posedge CLK) begin
        s2_en <= s1_done & en;
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

    // adder
    reg [11:0] adder_1;
    always@(posedge CLK) begin
        if(rst) begin
            adder_1 <= 0;
        end
        else begin
            if(en) begin
                adder_1 <= AGU_W_initial + offset;
            end
            else begin
                adder_1 <= adder_1;
            end
        end
    end
    ////////// Stage 1 end //////////

    ////////// Stage 2 //////////
    //counter w_count
    reg [6:0] w_count,next_w_count;
    reg s2_done;
    reg s3_en;
    always@(posedge CLK) begin
        s3_en <= s2_done & s2_en;
    end
    always@(*) begin
        next_w_count = w_count;
        s2_done = 0;
        if(w_count < width_out) begin
            next_w_count = w_count + 1;
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

    // adder reg
    reg [11:0] adder_2;
    always@(posedge CLK) begin
        if(rst == 1) begin
            adder_2 <= 0;
        end
        else begin
            if(adder_en[0]) begin
                adder_2 <= adder_1;
            end
            else begin
                adder_2 <= adder_2;
            end
        end
    end
    ////////// Stage 2 end //////////

    ////////// Stage 3 //////////
    reg [7:0] ch_count,next_ch_count;
    reg [11:0] L, next_L;
    reg s3_done;
    //counter ch_count & L
    always@(*) begin
        //avoid latch
        next_ch_count = ch_count;
        next_L = L;
        s3_done = 0;

        //counter logic
        if(ch_count < ch_out) begin
            next_ch_count = ch_count + 1;
            next_L = L + k_stride;
        end
        else begin
            next_ch_count = 0;
            next_L = 0;
            s3_done = 1;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            ch_count <= 0;
            L <= 0;
        end
        else begin
            if(s3_en) begin
                ch_count <= next_ch_count;
                L <= next_L;
            end
            else begin
                ch_count <= ch_count;
                L <= L;
            end
        end
    end

    //adder
    always@(posedge CLK) begin
        if(rst) begin
            Waddr <= 0;
        end
        else begin
            if(adder_en[1]) begin
                Waddr <= adder_2 + L;
            end
            else begin
                Waddr <= Waddr;
            end
        end
    end
    ////////// Stage 3 end //////////

    //done logic
    always@(posedge CLK) begin
        if( s3_done && s3_en) begin
            done <= 1;
        end
        else begin
            done <= 0;
        end
    end
    
endmodule