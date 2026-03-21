`timescale 1ns / 1ps

module GLB_input(
    input CLK,
    input en,
    input rst,
    input [1:0] glb_in_mode, // 0: uni_write, 1: multi_write
    // AGU_T
    input [22:0] AGU_T_param, // {AGU_T_initial[11:0], tile_width[6:0], tile_ch[7:0]}
    // AGU_G
    input [28:0] AGU_G_param, // {AGU_G_initial[13:0], glb_width[6:0], glb_ch[7:0]}
    output [10:0] ch_to_Y_bus, // {ch_to_Y_en, ch_sum[9:0]}
    input [13:0] ch_to_Y_Y, // addr offset for AGU_G
    // input tile
    output [8:0] glb_prep_wb_bus, // {wb_sel[0], taddr[7:0]}
    output [10:0] glb_ciu_wb_bus_123, // {wb_sel[3:1], taddr[7:0]}
    output [10:0] glb_ciu_wb_bus_456, // {wb_sel[6:4], taddr[7:0]}
    input [32:0] prep_glb_wb_bus, // {wb_en_pp, wb_data_pp[31:0]}
    input [32:0] ciu_glb_wb_bus_123, // {wb_en_123, wb_data_123[31:0]}
    input [32:0] ciu_glb_wb_bus_456, // {wb_en_456, wb_data_456[31:0]}
    // glb
    output [46:0] glb_input_bus, // {glb_ena, gaddr[13:0], glb_dina[31:0]}
    // busy signal
    output glb_input_busy
    );
    
    ////////// GLB input control //////////
    wire AGU_T_en;
    wire [5:0] SR;
    wire set;
    wire glb_in_rst;
    wire AGU_T_done, AGU_G_done;
    wire wb_data_valid = (ciu_glb_wb_bus_123[32] | ciu_glb_wb_bus_456[32] | prep_glb_wb_bus[32]);
    GLB_input_controller glb_input_control(
        .CLK(CLK),
        .en(en),
        .rst(rst),
        .set(set),
        .wb_data_valid(wb_data_valid),
        .AGU_G_done(AGU_G_done),
        .AGU_T_done(AGU_T_done),
        .AGU_T_en(AGU_T_en),
        .SR(SR),
        .glb_input_busy(glb_input_busy),
        .glb_in_rst(glb_in_rst)
    );
    ////////// GLB input control end //////////

    ////////// signal assign //////////
    wire [13:0] gaddr;
    wire [31:0] data_transposed;
    assign glb_input_bus = {SR[5], gaddr, data_transposed};
    ////////// signal assign end //////////

    ////////// AGU_T //////////
    reg [2:0] core;
    wire write_back_en;
    wire [2:0] core_pointer;
    wire [7:0] taddr;
    // core logic
    always@(*) begin
        if(glb_in_mode == 2'd0) core = 3'd0;
        else core = 3'd5;
    end
    // AGU_T instance
    AGU_T agu_t(
        .CLK(CLK),
        .en(AGU_T_en),
        .rst(glb_in_rst),
        .set(set),
        .AGU_T_param(AGU_T_param),
        .core(core),
        .core_pointer(core_pointer),
        .taddr(taddr),
        .en_next(write_back_en),
        .done(AGU_T_done)
    );
    ////////// AGU_T end //////////

    ////////// write back enable //////////
    reg [6:0] wb_sel;
    always@(*) begin
        if(write_back_en) begin
            if(glb_in_mode == 2'd0) begin
                wb_sel = 7'b0000001;
            end
            else begin
                case(core_pointer)
                    0: wb_sel = 7'b1000000;
                    1: wb_sel = 7'b0100000;
                    2: wb_sel = 7'b0010000;
                    3: wb_sel = 7'b0001000;
                    4: wb_sel = 7'b0000100;
                    5: wb_sel = 7'b0000010;
                    default: wb_sel = 7'b0000000;
                endcase
            end
        end
        else begin
            wb_sel = 7'b0000000;
        end
    end
    assign glb_prep_wb_bus = {wb_sel[0], taddr};
    assign glb_ciu_wb_bus_123 = {wb_sel[6:4], taddr};
    assign glb_ciu_wb_bus_456 = {wb_sel[3:1], taddr};
    ////////// write back enable end //////////

    ////////// data buffer //////////
    wire [2:0] wb_data_valid_bus = {prep_glb_wb_bus[32], ciu_glb_wb_bus_123[32], ciu_glb_wb_bus_456[32]};
    reg [31:0] glb_wb_buffer;
    // data buffer 0
    always@(posedge CLK) begin
        if(glb_in_rst) begin
            glb_wb_buffer <= 32'd0;
        end
        else begin
            if(wb_data_valid) begin
                case(wb_data_valid_bus)
                    3'b100: glb_wb_buffer <= prep_glb_wb_bus[31:0];
                    3'b010: glb_wb_buffer <= ciu_glb_wb_bus_123[31:0];
                    3'b001: glb_wb_buffer <= ciu_glb_wb_bus_456[31:0];
                    default: glb_wb_buffer <= 32'd0;
                endcase
            end
            else begin
                glb_wb_buffer <= glb_wb_buffer;
            end
        end
    end
    ////////// data buffer end //////////

    ////////// AGU_G //////////
    AGU_G agu_g(
        .CLK(CLK),
        .en(wb_data_valid),
        .rst(glb_in_rst),
        .set(set),
        .AGU_G_param(AGU_G_param),
        .ch_to_Y_bus(ch_to_Y_bus),
        .Y(ch_to_Y_Y),
        .gaddr(gaddr),
        .done(AGU_G_done)
    );
    ////////// AGU_G end //////////

    ////////// Input Transpose //////////
    Transpose transpose(
        .CLK(CLK),
        .rst(glb_in_rst),
        .en(SR[0] | SR[1] | SR[2] | SR[3] | SR[4]),
        .data(glb_wb_buffer),
        .data_transpose(data_transposed)
    );
    ////////// Input Transpose end //////////

endmodule