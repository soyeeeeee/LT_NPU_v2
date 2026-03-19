`timescale 1ns / 1ps

//delay = 1 cycle

module Array_buffer(
    input CLK,
    input rst,
    input en,
    input set,
    input [63:0]fdata_0,
    input [63:0]fdata_1,
    input [63:0]fdata_2,
    input [63:0]fdata_3,
    input [2:0]mode_in,
    output reg [63:0] PE_fin_0,
    output reg [63:0] PE_fin_1,
    output reg [63:0] PE_fin_2,
    output reg [63:0] PE_fin_3
    );
    
    // mode define
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;
    
    ////////// input buffer //////////
    reg [2:0] mode;
    always@(posedge CLK) begin
        if(rst) begin
            mode <= 0;
        end
        else if(set) begin
            mode <= mode_in;
        end
        else begin
            mode <= mode;
        end
    end
    ////////// input buffer end //////////

    ////////// convolution counter //////////
    reg [1:0] conv_count, next_conv_count;
    always@(*) begin
        next_conv_count = conv_count;
        case(mode)
            conv: begin
                if(conv_count < 2) begin
                    next_conv_count = conv_count + 1;
                end
                else begin
                    next_conv_count = 0;
                end
            end
            default: begin
                next_conv_count = 0;
            end
        endcase
    end
    always@(posedge CLK) begin
        if(rst) begin
            conv_count <= 0;
        end
        else begin
            if(en) begin
                conv_count <= next_conv_count;
            end
            else begin
                conv_count <= conv_count;
            end
        end
    end
    ////////// convolution counter end //////////
    
    ////////// output data //////////
    always@(posedge CLK) begin
        case(mode)
            conv: begin
                case(conv_count)
                    0: begin
                        PE_fin_0 <= {4{fdata_0[63:48]}};
                        PE_fin_1 <= {4{fdata_0[47:32]}};
                        PE_fin_2 <= {4{fdata_0[31:16]}};
                        PE_fin_3 <= {4{fdata_0[15:0]}};
                    end
                    1: begin
                        PE_fin_0 <= {4{fdata_1[63:48]}};
                        PE_fin_1 <= {4{fdata_1[47:32]}};
                        PE_fin_2 <= {4{fdata_1[31:16]}};
                        PE_fin_3 <= {4{fdata_1[15:0]}};
                    end
                    2: begin
                        PE_fin_0 <= {4{fdata_2[63:48]}};
                        PE_fin_1 <= {4{fdata_2[47:32]}};
                        PE_fin_2 <= {4{fdata_2[31:16]}};
                        PE_fin_3 <= {4{fdata_2[15:0]}};
                    end
                    default: begin
                        PE_fin_0 <= {4{fdata_0[63:48]}};
                        PE_fin_1 <= {4{fdata_0[47:32]}};
                        PE_fin_2 <= {4{fdata_0[31:16]}};
                        PE_fin_3 <= {4{fdata_0[15:0]}};
                    end
                endcase
            end
            PW: begin
                PE_fin_0 <= {4{fdata_0[63:48]}};
                PE_fin_1 <= {4{fdata_0[47:32]}};
                PE_fin_2 <= {4{fdata_0[31:16]}};
                PE_fin_3 <= {4{fdata_0[15:0]}};
            end
            maxpooling, DW, GAP: begin
                PE_fin_0 <= fdata_0;
                PE_fin_1 <= fdata_1;
                PE_fin_2 <= fdata_2;
                PE_fin_3 <= fdata_3;
            end
            default: begin
                PE_fin_0 <= fdata_0;
                PE_fin_1 <= fdata_1;
                PE_fin_2 <= fdata_2;
                PE_fin_3 <= fdata_3;
            end
        endcase
    end
    ////////// output data end //////////
    
endmodule