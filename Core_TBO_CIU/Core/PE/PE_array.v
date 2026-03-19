`timescale 1ns / 1ps

module PE_array(
    input CLK,
    input en,
    input rst,
    input set,
    input [2:0] mode_in,
    input [63:0] PE_fin_0,
    input [63:0] PE_fin_1,
    input [63:0] PE_fin_2,
    input [63:0] PE_fin_3,
    input [63:0] PE_win_0,
    input [63:0] PE_win_1,
    input [63:0] PE_win_2,
    input [63:0] PE_win_3,
    output [127:0] PE_out_0,
    output [127:0] PE_out_1,
    output [127:0] PE_out_2,
    output [127:0] PE_out_3
    );

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

    ////////// mode define //////////
    parameter conv = 0, maxpooling = 1, DW = 2, PW = 3, GAP = 4;
    ////////// mode define end //////////
    
    ////////// PE Array //////////
    reg PE_en_00, PE_en_01, PE_en_02, PE_en_03;
    reg PE_en_10, PE_en_11, PE_en_12, PE_en_13;
    reg PE_en_20, PE_en_21, PE_en_22, PE_en_23;
    reg PE_en_30, PE_en_31, PE_en_32, PE_en_33;
    always@(*) begin
        case(mode)
            conv, maxpooling, DW: begin
                PE_en_00 = 1; PE_en_01 = 1; PE_en_02 = 1; PE_en_03 = 1;
                PE_en_10 = 1; PE_en_11 = 1; PE_en_12 = 1; PE_en_13 = 1;
                PE_en_20 = 1; PE_en_21 = 1; PE_en_22 = 1; PE_en_23 = 1;
                PE_en_30 = 0; PE_en_31 = 0; PE_en_32 = 0; PE_en_33 = 0;
            end
            PW, GAP: begin
                PE_en_00 = 1; PE_en_01 = 1; PE_en_02 = 1; PE_en_03 = 1;
                PE_en_10 = 1; PE_en_11 = 1; PE_en_12 = 1; PE_en_13 = 1;
                PE_en_20 = 1; PE_en_21 = 1; PE_en_22 = 1; PE_en_23 = 1;
                PE_en_30 = 1; PE_en_31 = 1; PE_en_32 = 1; PE_en_33 = 1;
            end
            default: begin
                PE_en_00 = 0; PE_en_01 = 0; PE_en_02 = 0; PE_en_03 = 0;
                PE_en_10 = 0; PE_en_11 = 0; PE_en_12 = 0; PE_en_13 = 0;
                PE_en_20 = 0; PE_en_21 = 0; PE_en_22 = 0; PE_en_23 = 0;
                PE_en_30 = 0; PE_en_31 = 0; PE_en_32 = 0; PE_en_33 = 0;
            end
        endcase
    end
    reg [1:0] PE_mode;
    always@(*) begin
        case(mode)
            conv: PE_mode = 0;
            maxpooling: PE_mode = 2;
            DW: PE_mode = 0;
            PW: PE_mode = 0;
            GAP: PE_mode = 1;
            default: PE_mode = 0;
        endcase
    end

    // 4*4 array 
    wire [31:0] PE_out_00, PE_out_01, PE_out_02, PE_out_03;
    wire [31:0] PE_out_10, PE_out_11, PE_out_12, PE_out_13;
    wire [31:0] PE_out_20, PE_out_21, PE_out_22, PE_out_23;
    wire [31:0] PE_out_30, PE_out_31, PE_out_32, PE_out_33;
    assign PE_out_0 = {PE_out_00, PE_out_01, PE_out_02, PE_out_03};
    assign PE_out_1 = {PE_out_10, PE_out_11, PE_out_12, PE_out_13};
    assign PE_out_2 = {PE_out_20, PE_out_21, PE_out_22, PE_out_23};
    assign PE_out_3 = {PE_out_30, PE_out_31, PE_out_32, PE_out_33};

    // PE instantiation
    PE PE_00(.CLK(CLK), .en(en & PE_en_00), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_0[63:48]), .PE_B(PE_win_0[63:48]), .PE_out(PE_out_00));
    PE PE_01(.CLK(CLK), .en(en & PE_en_01), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_0[47:32]), .PE_B(PE_win_1[63:48]), .PE_out(PE_out_01));
    PE PE_02(.CLK(CLK), .en(en & PE_en_02), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_0[31:16]), .PE_B(PE_win_2[63:48]), .PE_out(PE_out_02));
    PE PE_03(.CLK(CLK), .en(en & PE_en_03), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_0[15:0 ]), .PE_B(PE_win_3[63:48]), .PE_out(PE_out_03));
    PE PE_10(.CLK(CLK), .en(en & PE_en_10), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_1[63:48]), .PE_B(PE_win_0[47:32]), .PE_out(PE_out_10));
    PE PE_11(.CLK(CLK), .en(en & PE_en_11), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_1[47:32]), .PE_B(PE_win_1[47:32]), .PE_out(PE_out_11));
    PE PE_12(.CLK(CLK), .en(en & PE_en_12), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_1[31:16]), .PE_B(PE_win_2[47:32]), .PE_out(PE_out_12));
    PE PE_13(.CLK(CLK), .en(en & PE_en_13), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_1[15:0 ]), .PE_B(PE_win_3[47:32]), .PE_out(PE_out_13));
    PE PE_20(.CLK(CLK), .en(en & PE_en_20), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_2[63:48]), .PE_B(PE_win_0[31:16]), .PE_out(PE_out_20));
    PE PE_21(.CLK(CLK), .en(en & PE_en_21), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_2[47:32]), .PE_B(PE_win_1[31:16]), .PE_out(PE_out_21));
    PE PE_22(.CLK(CLK), .en(en & PE_en_22), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_2[31:16]), .PE_B(PE_win_2[31:16]), .PE_out(PE_out_22));
    PE PE_23(.CLK(CLK), .en(en & PE_en_23), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_2[15:0 ]), .PE_B(PE_win_3[31:16]), .PE_out(PE_out_23));
    PE PE_30(.CLK(CLK), .en(en & PE_en_30), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_3[63:48]), .PE_B(PE_win_0[15:0 ]), .PE_out(PE_out_30));
    PE PE_31(.CLK(CLK), .en(en & PE_en_31), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_3[47:32]), .PE_B(PE_win_1[15:0 ]), .PE_out(PE_out_31));
    PE PE_32(.CLK(CLK), .en(en & PE_en_32), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_3[31:16]), .PE_B(PE_win_2[15:0 ]), .PE_out(PE_out_32));
    PE PE_33(.CLK(CLK), .en(en & PE_en_33), .rst(rst), .PE_mode(PE_mode), .PE_A(PE_fin_3[15:0 ]), .PE_B(PE_win_3[15:0 ]), .PE_out(PE_out_33));
    ////////// PE Array //////////
endmodule