`timescale 1ns / 1ps

module CI_buffer(
    input CLK,
    input rst,
    input en,
    input mux_sel, // 0: pass stream_in to stream_out; 1: load stream initial
    input [39:0] stream_in,
    input [39:0] stream_initial,
    output reg [39:0] stream_out
    );

    always @(posedge CLK) begin
        if (rst) begin
            stream_out <= 0;
        end
        else begin
            if (en) begin
                if (mux_sel) begin
                    stream_out <= stream_initial; // Load stream initial
                end
                else begin
                    stream_out <= stream_in; // Pass stream_in to stream_out
                end
            end
            else begin
                stream_out <= stream_out;
            end
        end
    end

endmodule