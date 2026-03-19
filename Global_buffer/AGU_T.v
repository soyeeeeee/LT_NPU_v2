`timescale 1ns / 1ps

// delay = 3 cycle

module AGU_T(
    input CLK,
    input en,
    input rst,
    input set,
    input [22:0] AGU_T_param, // {AGU_T_initial[7:0], tile_width[6:0], tile_ch[7:0]}
    input [2:0] core,
    // output
    output reg [2:0] core_pointer,
    output reg [7:0] taddr,
    output en_next,
    output reg done
    );
    
    ////////// input buffer //////////
    reg [7:0] AGU_T_initial;
    reg [6:0] tile_width;
    reg [7:0] tile_ch;
    reg [7:0] ch_stride;
    always@(posedge CLK) begin
        if(rst) begin
            AGU_T_initial <= 0;
            tile_width <= 0;
            tile_ch <= 0;
            ch_stride <= 0;
        end
        else if(set) begin
            AGU_T_initial <= AGU_T_param[22:15];
            tile_width <= AGU_T_param[14:8];
            tile_ch <= AGU_T_param[7:0];
            ch_stride <= AGU_T_param[14:8] + 1; //stride = tile_width + 1
        end
        else begin
            AGU_T_initial <= AGU_T_initial;
            tile_width <= tile_width;
            tile_ch <= tile_ch;
            ch_stride <= ch_stride;
        end
    end
    ////////// input buffer end //////////

    ////////// en SR //////////
    reg [2:0] en_sr;
    assign en_next = en_sr[2];
    always@(posedge CLK) begin
        if(rst) begin
            en_sr <= 0;
        end
        else if(done) begin
            en_sr <= 3'b100;
        end
        else begin
            en_sr <= {en_sr[1:0], en};
        end
    end
    ////////// en SR end //////////

    ////////// stage 1 //////////
    reg [7:0] X,next_X;
    reg s1_done;
    reg s2_en;
    always@(posedge CLK) begin
        s2_en <= s1_done & en;
    end
    //counter
    always@(*) begin
        //avoid latch
        next_X = X;
        s1_done = 0;
        
        //counter logic
        if(X == tile_width) begin
            next_X = 0;
            s1_done = 1;
        end
        else begin
            next_X = X + 1;
            s1_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst == 1) begin
            X <= 0;
        end
        else begin
            if(en) begin
                X <= next_X;
            end
            else begin
                X <= X;
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
                adder_1 <= AGU_T_initial + X;
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
    reg s2_done, s3_en;
    always@(posedge CLK) begin
        s3_en <= s2_done & s2_en;
    end
    
    always@(*) begin
        next_ch = ch;
        next_Y = Y;
        s2_done = 0;
        if(ch == tile_ch) begin
            next_ch = 0;
            next_Y = 0;
            s2_done = 1;
        end
        else begin
            next_ch = ch + 1;
            next_Y = Y + ch_stride;
            s2_done = 0;
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
    reg [7:0] adder_2;
    always@(posedge CLK) begin
        if(rst) begin
            adder_2 <= 0;
        end
        else begin
            if(en_sr[0]) begin
                adder_2 <= adder_1 + Y;
            end
            else begin
                adder_2 <= adder_2;
            end
        end
    end
    ////////// stage 2 end //////////

    ////////// stage 3 //////////
    reg [2:0] core_count, next_core_count;
    reg s3_done;
    
    always@(*) begin
        next_core_count = core_count;
        s3_done = 0;

        if(core_count == core) begin
            next_core_count = 0;
            s3_done = 1;
        end
        else begin
            next_core_count = core_count + 1;
            s3_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            core_count <= 0;
        end
        else begin
            if(s3_en) begin
                core_count <= next_core_count;
            end
            else begin
                core_count <= core_count;
            end
        end
    end

    // reg
    always@(posedge CLK) begin
        if(rst) begin
            taddr <= 0;
            core_pointer <= 0;
        end
        else begin
            if(en_sr[1]) begin
                taddr <= adder_2;
                core_pointer <= core_count;
            end
            else begin
                taddr <= taddr;
                core_pointer <= core_pointer;
            end
        end
    end
    ////////// stage 3 end //////////

    ////////// done signal //////////
    always@(*) begin
        if(s3_done && s3_en) begin
            done = 1;
        end
        else begin
            done = 0;
        end
    end
    ////////// done signal end //////////

endmodule