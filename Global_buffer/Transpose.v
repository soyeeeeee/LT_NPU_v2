`timescale 1ns / 1ps

module Transpose(
    input CLK,
    input rst,
    input en,
    input [31:0] data,
    output reg [31:0] data_transpose
    );
    
    reg [31:0] buffer_0;
    reg [39:0] buffer_1;
    reg [47:0] buffer_2;
    reg [55:0] buffer_3;

    ////////// SR buffer //////////
    always @(posedge CLK) begin
        if (en) begin
            buffer_0 <= {buffer_0[23:0], data[31:24]};
            buffer_1 <= {buffer_1[31:0], data[23:16]};
            buffer_2 <= {buffer_2[39:0], data[15:8]};
            buffer_3 <= {buffer_3[47:0], data[7:0]};
        end
        else begin
            buffer_0 <= buffer_0;
            buffer_1 <= buffer_1;
            buffer_2 <= buffer_2;
            buffer_3 <= buffer_3;
        end
    end
    ////////// SR buffer end //////////

    ////////// output //////////
    reg [1:0] count;
    always @(posedge CLK) begin
        if (rst) begin
            count <= 2'd0;
            data_transpose <= 32'd0;
        end
        else begin
            if (en) begin
                count <= count + 2'd1;
                case (count)
                    0: begin
                        data_transpose <= buffer_0;
                    end
                    1: begin
                        data_transpose <= buffer_1[39:8];
                    end
                    2: begin
                        data_transpose <= buffer_2[47:16];
                    end
                    3: begin
                        data_transpose <= buffer_3[55:24];
                    end
                    default: begin
                        data_transpose <= 32'd0;
                    end
                endcase
            end
            else begin
                count <= count;
                data_transpose <= data_transpose;
            end
        end
    end

endmodule