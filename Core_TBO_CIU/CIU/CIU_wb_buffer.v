`timescale 1ns / 1ps

// delay = 4

module CIU_wb_buffer(
    input CLK,
    input rst,
    input [8:0] glb_ciu_wb_bus, // {en, addr}
    // tile buffer
    output [8:0] ciu_tbo_wb_bus, // {en, addr}
    input [31:0] tbo_ciu_wb_data,
    // output data
    output [32:0] ciu_glb_wb_bus // {data_valid, data}
    );

    ////////// valid SR //////////
    reg [3:0] en_SR;
    always @(posedge CLK) begin
        if (rst) begin
            en_SR <= 4'd0;
        end
        else begin
            en_SR <= {en_SR[2:0], glb_ciu_wb_bus[8]};
        end
    end
    wire data_valid = en_SR[3];
    ////////// valid SR end//////////

    ///////// addr buffer //////////
    reg [7:0] addr_write;
    always @(posedge CLK) begin
        if (rst) begin
            addr_write <= 8'd0;
        end
        else begin
            if (glb_ciu_wb_bus[8]) begin
                addr_write <= glb_ciu_wb_bus[7:0];
            end
            else begin
                addr_write <= addr_write;
            end
        end
    end
    // addr buffer output to tile buffer
    assign ciu_tbo_wb_bus = {en_SR[0], addr_write};
    ///////// addr buffer end//////////

    ///////// write buffer //////////
    reg [31:0] write_data;
    always @(posedge CLK) begin
        if (rst) begin
            write_data <= 32'd0;
        end
        else begin
            if (en_SR[2]) begin
                write_data <= tbo_ciu_wb_data;
            end
            else begin
                write_data <= write_data;
            end
        end
    end
    assign ciu_glb_wb_bus = {data_valid, write_data};
    ///////// write buffer end//////////

endmodule