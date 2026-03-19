`timescale 1ns / 1ps

// delay = 1

module CIU_load_buffer(
    input CLK,
    input rst,
    input [40:0] glb_ciu_load_bus, // {valid, addr, data}
    output [40:0] ciu_tbo_load_bus // {valid, addr, data}
    );

    ////////// buffer //////////
    reg [40:0] load_buffer;
    always @(posedge CLK) begin
        if (rst) begin
            load_buffer <= 0;
        end
        else begin
            load_buffer <= glb_ciu_load_bus;
        end
    end
    ////////// buffer end //////////

    ////////// output //////////
    assign ciu_tbo_load_bus = load_buffer;
    ////////// output end //////////

endmodule