`timescale 1ns / 1ps

// delay = 2 cycle

module AGU_C(
    input CLK,
    input en,
    input rst,
    input set,
    input [15:0] AGU_C_param,
    output reg [7:0] caddr,
    output reg done
    );
    
    ////////// input buffer //////////
    reg [7:0] AGU_C_initial;
    reg [7:0] tile_size;
    always@(posedge CLK) begin
        if(rst) begin
            AGU_C_initial <= 0;
            tile_size <= 0;
        end
        else if(set) begin
            AGU_C_initial <= AGU_C_param[15:8];
            tile_size <= AGU_C_param[7:0];
        end
        else begin
            AGU_C_initial <= AGU_C_initial;
            tile_size <= tile_size;
        end
    end
    ////////// input buffer end //////////
    
    ////////// stage 1 //////////
    reg [7:0] tile, next_tile;
    reg s1_done;
    
    always@(*) begin
        next_tile = tile;
        s1_done = 0;
        if(tile == tile_size) begin
            next_tile = 0;
            s1_done = 1;
        end
        else begin
            next_tile = tile + 1;
            s1_done = 0;
        end
    end
    always@(posedge CLK) begin
        if(rst) begin
            tile <= 0;
        end
        else begin
            if(en) begin
                tile <= next_tile;
            end
            else begin
                tile <= tile;
            end
        end
    end

    // adder
    always@(posedge CLK) begin
        if(rst) begin
            caddr <= 0;
        end
        else begin
            if(en) begin
                caddr <= AGU_C_initial + tile;
            end
            else begin
                caddr <= caddr;
            end
        end
    end
    ////////// stage 1 end //////////

    ////////// done signal //////////
    always@(posedge CLK) begin
        if(rst) begin
            done <= 0;
        end
        else begin
            if(s1_done) begin
                done <= 1;
            end
            else begin
                done <= 0;
            end
        end
    end
    ////////// done signal end //////////

endmodule