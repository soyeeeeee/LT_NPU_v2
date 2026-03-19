`timescale 1ns / 1ps

// delay = 6 cycle

module AGU_G(
    input CLK,
    input en,
    input rst,
    input set,
    // parameter
    input [28:0] AGU_G_param, // {AGU_G_initial[13:0], glb_width[6:0], glb_ch[7:0]}
    // ch_to_Y
    output [10:0] ch_to_Y_bus, // {ch_to_Y_en, ch_sum[9:0]}
    input [13:0] Y,
    // output
    output reg [13:0] gaddr,
    output en_next,
    output done
    );
    
    ////////// input buffer //////////
    reg [13:0] AGU_G_initial;
    reg [6:0] glb_width;
    reg [7:0] glb_ch;
    always@(posedge CLK) begin
        if(rst) begin
            AGU_G_initial <= 0;
            glb_width <= 0;
            glb_ch <= 0;
        end
        else if(set) begin
            AGU_G_initial <= AGU_G_param[28:15];
            glb_width <= AGU_G_param[14:8] >> 2;
            glb_ch <= AGU_G_param[7:0];
        end
        else begin
            AGU_G_initial <= AGU_G_initial;
            glb_width <= glb_width;
            glb_ch <= glb_ch;
        end
    end
    ////////// input buffer end //////////

    ////////// en SR //////////
    reg [5:0] en_SR;
    assign ch_to_Y_bus[10] = en_SR[2];
    always@(posedge CLK) begin
        if(rst) begin
            en_SR <= 0;
        end
        else if(done) begin
            en_SR <= 6'b100000;
        end
        else begin
            en_SR <= {en_SR[4:0], en};
        end
    end
    assign en_next = en_SR[5];
    ////////// en SR end //////////

    ////////// stage 1 //////////
    reg [7:0] offset_Y,next_offset_Y;
    reg s1_done;
    reg s2_en;
    always@(posedge CLK) begin
        s2_en <= s1_done & en;
    end
    //counter
    always@(*) begin
        //avoid latch
        next_offset_Y = offset_Y;
        s1_done = 0;
        
        //counter logic
        if(offset_Y == 3) begin
            next_offset_Y = 0;
            s1_done = 1;
        end
        else begin
            next_offset_Y = offset_Y + 1;
            s1_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            offset_Y <= 0;
        end
        else begin
            if(en) begin
                offset_Y <= next_offset_Y;
            end
            else begin
                offset_Y <= offset_Y;
            end
        end
    end

    // reg offset_Y
    reg [7:0] offset_Y_reg_0;
    always@(posedge CLK) begin
        if(rst) begin
            offset_Y_reg_0 <= 0;
        end
        else begin
            if(en) begin
                offset_Y_reg_0 <= offset_Y;
            end
            else begin
                offset_Y_reg_0 <= offset_Y_reg_0;
            end
        end
    end
    ////////// stage 1 end //////////

    ////////// stage 2 //////////
    reg [7:0] X,next_X;
    reg [6:0] width_count, next_width_count;
    reg s2_done;
    reg s3_en;
    always@(posedge CLK) begin
        s3_en <= s2_done & s2_en;
    end
    //counter
    always@(*) begin
        //avoid latch
        next_X = X;
        next_width_count = width_count;
        s2_done = 0;
        
        //counter logic
        if(width_count == glb_width) begin
            next_X = 0;
            next_width_count = 0;
            s2_done = 1;
        end
        else begin
            next_X = X + 1;
            next_width_count = width_count + 1;
            s2_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            X <= 0;
            width_count <= 0;
        end
        else begin
            if(s2_en) begin
                X <= next_X;
                width_count <= next_width_count;
            end
            else begin
                X <= X;
                width_count <= width_count;
            end
        end
    end

    // adder 1
    reg [13:0] adder_1;
    always@(posedge CLK) begin
        if(rst) begin
            adder_1 <= 0;
        end
        else begin
            if(en_SR[0]) begin
                adder_1 <= {6'd0, X} + AGU_G_initial;
            end
            else begin
                adder_1 <= adder_1;
            end
        end
    end

    // reg offset_Y
    reg [9:0] offset_Y_reg_1;
    always@(posedge CLK) begin
        if(rst) begin
            offset_Y_reg_1 <= 0;
        end
        else begin
            if(en_SR[0]) begin
                offset_Y_reg_1 <= {2'd0, offset_Y_reg_0};
            end
            else begin
                offset_Y_reg_1 <= offset_Y_reg_1;
            end
        end
    end
    ////////// stage 2 end //////////
    
    ////////// stage 3 //////////
    reg [9:0] ch, next_ch; // 1024
    reg [7:0] ch_count, next_ch_count;
    reg s3_done;
    reg done_det;
    always@(posedge CLK) begin
        done_det <= s3_done & s3_en;
    end
    
    always@(*) begin
        next_ch_count = ch_count;
        next_ch = ch;
        s3_done = 0;
        if(ch_count == glb_ch) begin
            next_ch_count = 0;
            next_ch = 0;
            s3_done = 1;
        end
        else begin
            next_ch_count = ch_count + 1;
            next_ch = ch + 4;
            s3_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            ch_count <= 0;
            ch <= 0;
        end
        else begin
            if(s3_en) begin
                ch_count <= next_ch_count;
                ch <= next_ch;
            end
            else begin
                ch_count <= ch_count;
                ch <= ch;
            end
        end
    end

    // adder_2
    reg [9:0] ch_sum;
    always@(posedge CLK) begin
        if(rst) begin
            ch_sum <= 0;
        end
        else begin
            if(en_SR[2]) begin
                ch_sum <= offset_Y_reg_1 + ch;
            end
            else begin
                ch_sum <= ch_sum;
            end
        end
    end
    assign ch_to_Y_bus[9:0] = ch_sum;
    ////////// stage 3 end //////////

    ////////// addr_1 reg //////////
    reg [13:0] reg_addr_1_0, reg_addr_1_1, reg_addr_1_2;

    always@(posedge CLK) begin
        if(rst) begin
            reg_addr_1_0 <= 0;
        end
        else begin
            if(en_SR[1]) begin
                reg_addr_1_0 <= adder_1;
            end
            else begin
                reg_addr_1_0 <= reg_addr_1_0;
            end
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            reg_addr_1_1 <= 0;
        end
        else begin
            if(en_SR[2]) begin
                reg_addr_1_1 <= reg_addr_1_0;
            end
            else begin
                reg_addr_1_1 <= reg_addr_1_1;
            end
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            reg_addr_1_2 <= 0;
        end
        else begin
            if(en_SR[3]) begin
                reg_addr_1_2 <= reg_addr_1_1;
            end
            else begin
                reg_addr_1_2 <= reg_addr_1_2;
            end
        end
    end
    ////////// addr_1 reg end //////////

    ////////// gaddr //////////
    always@(posedge CLK) begin
        if(rst) begin
            gaddr <= 0;
        end
        else begin
            if(en_SR[4]) begin
                gaddr <= reg_addr_1_2 + Y;
            end
            else begin
                gaddr <= gaddr;
            end
        end
    end
    ////////// gaddr done //////////

    ////////// done signal //////////
    reg [2:0] done_SR;
    always@(posedge CLK) begin
        if(rst) begin
            done_SR <= 0;
        end
        else begin
            done_SR <= {done_SR[1:0], done_det};
        end
    end
    assign done = done_SR[1];
    ////////// done signal end //////////

endmodule