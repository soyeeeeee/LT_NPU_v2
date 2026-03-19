`timescale 1ns / 1ps

// delay = 2 cycle

module AGU_O(
    input CLK,
    input en,
    input rst,
    input set,
    input [7:0] AGU_O_initial_in,
    input [6:0] width_out_in,
    input [7:0] ch_out_in,
    output reg [7:0] oaddr,
    output reg done
    );
    
    ////////// input buffer //////////
    reg [7:0] AGU_O_initial;
    reg [6:0] width_out;
    reg [7:0] ch_out;
    reg [7:0] ch_stride;
    always@(posedge CLK) begin
        if(rst) begin
            AGU_O_initial <= 0;
            width_out <= 0;
            ch_out <= 0;
            ch_stride <= 0;
        end
        else if(set) begin
            AGU_O_initial <= AGU_O_initial_in;
            width_out <= width_out_in;
            ch_out <= ch_out_in;
            ch_stride <= width_out_in + 1; //stride = width_out
        end
        else begin
            AGU_O_initial <= AGU_O_initial;
            width_out <= width_out;
            ch_out <= ch_out;
            ch_stride <= ch_stride;
        end
    end
    ////////// input buffer end //////////

    ////////// adder SR //////////
    reg adder_en;
    always@(posedge CLK) begin
        if(rst) begin
            adder_en <= 0;
        end
        else begin
            adder_en <= en;
        end
    end
    ////////// adder SR end //////////

    ////////// stage 1 //////////
    reg [7:0] width,next_width;
    reg s1_done;
    reg s2_en;
    always@(posedge CLK) begin
        s2_en <= s1_done & en;
    end
    //counter
    always@(*) begin
        //avoid latch
        next_width = width;
        s1_done = 0;
        
        //counter logic
        if(width < width_out) begin
            next_width = width + 1;
            s1_done = 0;
        end
        else begin
            next_width = 0;
            s1_done = 1;
        end
    end
    always@(posedge CLK) begin
        if(rst == 1) begin
            width <= 0;
        end
        else begin
            if(en) begin
                width <= next_width;
            end
            else begin
                width <= width;
            end
        end
    end

    // adder
    reg [7:0] adder_1;
    always@(posedge CLK) begin
        if(rst) begin
            adder_1 <= 0;
        end
        else begin
            if(en) begin
                adder_1 <= AGU_O_initial + width;
            end
            else begin
                adder_1 <= adder_1;
            end
        end
    end
    ////////// stage 1 end //////////
    
    ////////// stage 2 //////////
    reg [7:0] ch, next_ch;
    reg [7:0] Y, next_Y;
    reg s2_done;
    
    always@(*) begin
        next_ch = ch;
        next_Y = Y;
        s2_done = 0;
        if(ch < ch_out) begin
            next_ch = ch + 1;
            next_Y = Y + ch_stride;
            s2_done = 0;
        end
        else begin
            next_ch = 0;
            next_Y = 0;
            s2_done = 1;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            ch <= 0;
            Y <= 0;
        end
        else begin
            if(s2_en) begin
                ch <= next_ch;
                Y <= next_Y;
            end
            else begin
                ch <= ch;
                Y <= Y;
            end
        end
    end

    // adder
    always@(posedge CLK) begin
        if(rst) begin
            oaddr <= 0;
        end
        else begin
            if(adder_en) begin
                oaddr <= adder_1 + Y;
            end
            else begin
                oaddr <= oaddr;
            end
        end
    end
    ////////// stage 2 end //////////

    ////////// done signal //////////
    always@(posedge CLK) begin
        if(rst) begin
            done <= 0;
        end
        else begin
            if(s2_done && s2_en) begin
                done <= 1;
            end
            else begin
                done <= 0;
            end
        end
    end
    ////////// done signal end //////////

endmodule