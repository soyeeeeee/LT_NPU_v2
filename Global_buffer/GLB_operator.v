`timescale 1ns / 1ps

module GLB_operator(
    input CLK,
    input rst,
    input glb_input_en,
    input glb_output_en,
    ////////// Control param //////////
    input [10:0] output_ch_to_Y_initial, // 0~2047
    input [10:0] input_ch_to_Y_initial, // 0~2047
    input [53:0] glb_input_param, // {glb_in_mode[1:0], input_AGU_param[51:0]}
    input [53:0] glb_output_param, // {glb_out_mode[1:0], output_AGU_param[51:0]}
    ////////// GLB_input //////////
    // input tile
    output [8:0] glb_prep_wb_bus,// {en, addr[7:0]}
    output [8:0] glb_ciu_wb_bus_1, // {en, addr[7:0]}
    output [8:0] glb_ciu_wb_bus_2, // {en, addr[7:0]}
    output [8:0] glb_ciu_wb_bus_3, // {en, addr[7:0]}
    output [8:0] glb_ciu_wb_bus_4, // {en, addr[7:0]}
    output [8:0] glb_ciu_wb_bus_5, // {en, addr[7:0]}
    output [8:0] glb_ciu_wb_bus_6, // {en, addr[7:0]}
    input [64:0] prep_glb_wb_bus, // {valid, data[63:0]}
    input [64:0] ciu_glb_wb_bus_1, // {valid, data[63:0]}
    input [64:0] ciu_glb_wb_bus_2, // {valid, data[63:0]}
    input [64:0] ciu_glb_wb_bus_3, // {valid, data[63:0]}
    input [64:0] ciu_glb_wb_bus_4, // {valid, data[63:0]}
    input [64:0] ciu_glb_wb_bus_5, // {valid, data[63:0]}
    input [64:0] ciu_glb_wb_bus_6, // {valid, data[63:0]}
    ////////// GLB_output //////////
    // output tile
    output [72:0] glb_ciu_load_bus_1, // {en, addr[7:0], data[63:0]}
    output [72:0] glb_ciu_load_bus_2, // {en, addr[7:0], data[63:0]}
    output [72:0] glb_ciu_load_bus_3, // {en, addr[7:0], data[63:0]}
    output [72:0] glb_ciu_load_bus_4, // {en, addr[7:0], data[63:0]}
    output [72:0] glb_ciu_load_bus_5, // {en, addr[7:0], data[63:0]}
    output [72:0] glb_ciu_load_bus_6, // {en, addr[7:0], data[63:0]}
    output reg [72:0] glb_posp_load_bus, // {en, addr[7:0], data[63:0]}
    // busy signal
    output glb_input_busy,
    output glb_output_busy
    );

    ////////// input buffer //////////
    reg [51:0] input_AGU_param_buffer; // {AGU_G_initial[51:38], AGU_T_initial[37:30], glb_width_in[29:23], glb_ch_in[22:15], tile_width_in[14:8], tile_ch_in[7:0]}
    reg [51:0] output_AGU_param_buffer; // {AGU_G_initial[51:38], AGU_T_initial[37:30], glb_width_out[29:23], glb_ch_out[22:15], tile_width_out[14:8], tile_ch_out[7:0]}
    always@(posedge CLK) begin
        if(rst) begin
            input_AGU_param_buffer <= 52'd0;
            output_AGU_param_buffer <= 52'd0;
        end
        else begin
            input_AGU_param_buffer <= glb_input_param[51:0];
            output_AGU_param_buffer <= glb_output_param[51:0];
        end
    end
    ////////// input buffer end //////////

    ////////// tile parameter //////////
    wire [6:0] glb_width_in = input_AGU_param_buffer[29:23];
    wire [7:0] glb_ch_in = input_AGU_param_buffer[22:15];
    wire [6:0] glb_width_out = output_AGU_param_buffer[29:23];
    wire [7:0] glb_ch_out = output_AGU_param_buffer[22:15]; // glb_ch = tile_ch*6
    wire [7:0] input_AGU_T_initial = input_AGU_param_buffer[37:30];
    wire [7:0] output_AGU_T_initial = output_AGU_param_buffer[37:30];
    // GLB input
    wire [22:0] input_AGU_T_param = {input_AGU_T_initial, input_AGU_param_buffer[14:0]};
    wire [28:0] input_AGU_G_param = {input_AGU_param_buffer[51:38], glb_width_in, glb_ch_in};
    // GLB output
    wire [22:0] output_AGU_T_param = {output_AGU_T_initial, output_AGU_param_buffer[14:0]};
    wire [28:0] output_AGU_G_param = {output_AGU_param_buffer[51:38], glb_width_out, glb_ch_out};
    ////////// tile parameter end /////////

    ////////// ch_to_Y //////////
    wire [10:0] input_ch_to_Y_bus, output_ch_to_Y_bus;
    wire [13:0] input_Y, output_Y; // real addr
    // ch_to_Y addr calculation
    wire [10:0] input_ch, output_ch;
    assign output_ch = output_ch_to_Y_initial + output_ch_to_Y_bus[9:0];
    assign input_ch = input_ch_to_Y_initial + input_ch_to_Y_bus[9:0];
    // Ch_to_Y instance
    Ch_to_Y ch_to_Y(
        // port a
        .clka(CLK),
        .ena(input_ch_to_Y_bus[10]),
        .regcea(1'b1),
        .addra(input_ch),
        .douta(input_Y),
        // port b
        .clkb(CLK),
        .enb(output_ch_to_Y_bus[10]),
        .regceb(1'b1),
        .addrb(output_ch),
        .doutb(output_Y)
    );
    ////////// ch_to_Y end //////////

    ////////// GLB //////////
    wire [63:0] glb_doutb;
    reg [63:0] glb_doutb_buffer;
    wire [78:0] glb_input_bus;
    wire [14:0] glb_output_bus;
    always@(posedge CLK) begin
        if(rst) glb_doutb_buffer <= 0;
        else glb_doutb_buffer <= glb_doutb;
    end
    // glb instance
    GLB glb(
        .CLK(CLK),
        .rst(rst),
        // port a
        .ena(glb_input_bus[78]),
        .wea(glb_input_bus[78]),
        .addra(glb_input_bus[77:64]),
        .dina(glb_input_bus[63:0]),
        // port b
        .enb(glb_output_bus[14]),
        .regceb(1'b1),
        .addrb(glb_output_bus[13:0]),
        .doutb(glb_doutb)
    );
    ////////// GLB end //////////

    ////////// GLB_input //////////
    // ciu to glb wb bus buffer
    reg [64:0] ciu_glb_wb_bus_123, ciu_glb_wb_bus_456;
    wire [2:0] wb_sel_123, wb_sel_456;
    assign wb_sel_123 = {ciu_glb_wb_bus_1[64], ciu_glb_wb_bus_2[64], ciu_glb_wb_bus_3[64]};
    assign wb_sel_456 = {ciu_glb_wb_bus_4[64], ciu_glb_wb_bus_5[64], ciu_glb_wb_bus_6[64]};
    always@(posedge CLK) begin
        if(rst) begin
            ciu_glb_wb_bus_123 <= 65'd0;
            ciu_glb_wb_bus_456 <= 65'd0;
        end
        else begin
            case(wb_sel_123)
                3'b100: ciu_glb_wb_bus_123 <= {1'b1, ciu_glb_wb_bus_1[63:0]};
                3'b010: ciu_glb_wb_bus_123 <= {1'b1, ciu_glb_wb_bus_2[63:0]};
                3'b001: ciu_glb_wb_bus_123 <= {1'b1, ciu_glb_wb_bus_3[63:0]};
                default: ciu_glb_wb_bus_123 <= 65'd0;
            endcase
            case(wb_sel_456)
                3'b100: ciu_glb_wb_bus_456 <= {1'b1, ciu_glb_wb_bus_4[63:0]};
                3'b010: ciu_glb_wb_bus_456 <= {1'b1, ciu_glb_wb_bus_5[63:0]};
                3'b001: ciu_glb_wb_bus_456 <= {1'b1, ciu_glb_wb_bus_6[63:0]};
                default: ciu_glb_wb_bus_456 <= 65'd0;
            endcase
        end
    end
    // wb bus split
    wire [10:0] glb_ciu_wb_bus_123;
    wire [10:0] glb_ciu_wb_bus_456;
    assign glb_ciu_wb_bus_1 = {glb_ciu_wb_bus_123[10], glb_ciu_wb_bus_123[7:0]};
    assign glb_ciu_wb_bus_2 = {glb_ciu_wb_bus_123[9], glb_ciu_wb_bus_123[7:0]};
    assign glb_ciu_wb_bus_3 = {glb_ciu_wb_bus_123[8], glb_ciu_wb_bus_123[7:0]};
    assign glb_ciu_wb_bus_4 = {glb_ciu_wb_bus_456[10], glb_ciu_wb_bus_456[7:0]};
    assign glb_ciu_wb_bus_5 = {glb_ciu_wb_bus_456[9], glb_ciu_wb_bus_456[7:0]};
    assign glb_ciu_wb_bus_6 = {glb_ciu_wb_bus_456[8], glb_ciu_wb_bus_456[7:0]};
    // GLB_input instance
    GLB_input glb_input(
        .CLK(CLK),
        .en(glb_input_en),
        .rst(rst),
        .glb_in_mode(glb_input_param[53:52]),
        // AGU_T
        .AGU_T_param(input_AGU_T_param),
        // AGU_G
        .AGU_G_param(input_AGU_G_param),
        .ch_to_Y_bus(input_ch_to_Y_bus),
        .ch_to_Y_Y(input_Y),
        // input tile
        .glb_prep_wb_bus(glb_prep_wb_bus),
        .glb_ciu_wb_bus_123(glb_ciu_wb_bus_123),
        .glb_ciu_wb_bus_456(glb_ciu_wb_bus_456),
        .prep_glb_wb_bus(prep_glb_wb_bus), // {wb_en_pp, wb_data_pp[63:0]}
        .ciu_glb_wb_bus_123(ciu_glb_wb_bus_123), // {wb_en_123, wb_data_123[63:0]}
        .ciu_glb_wb_bus_456(ciu_glb_wb_bus_456), // {wb_en_456, wb_data_456[63:0]}
        // glb
        .glb_input_bus(glb_input_bus), // {glb_ena, gaddr[13:0], glb_dina[63:0]}
        // busy signal
        .glb_input_busy(glb_input_busy)
    );
    ////////// GLB_input end //////////

    ////////// GLB_output //////////
    // glb to ciu/PosP load bus buffer
    reg [74:0] glb_ciu_load_bus_123; // {en[2:0], addr[7:0], data[63:0]}
    reg [74:0] glb_ciu_load_bus_456; // {en[2:0], addr[7:0], data[63:0]}
    wire [78:0] glb_load_bus;
    always@(posedge CLK) begin
        if(rst) begin
            glb_ciu_load_bus_123 <= 75'd0;
            glb_ciu_load_bus_456 <= 75'd0;
            glb_posp_load_bus <= 73'd0;
        end
        else begin
            glb_ciu_load_bus_123 <= {glb_load_bus[78:76], glb_load_bus[71:0]};
            glb_ciu_load_bus_456 <= {glb_load_bus[75:73], glb_load_bus[71:0]};
            glb_posp_load_bus <= {glb_load_bus[72], glb_load_bus[71:0]};
        end
    end
    // glb to ciu/PosP load bus split
    assign glb_ciu_load_bus_1 = {glb_ciu_load_bus_123[74], glb_ciu_load_bus_123[71:64], glb_ciu_load_bus_123[63:0]};
    assign glb_ciu_load_bus_2 = {glb_ciu_load_bus_123[73], glb_ciu_load_bus_123[71:64], glb_ciu_load_bus_123[63:0]};
    assign glb_ciu_load_bus_3 = {glb_ciu_load_bus_123[72], glb_ciu_load_bus_123[71:64], glb_ciu_load_bus_123[63:0]};
    assign glb_ciu_load_bus_4 = {glb_ciu_load_bus_456[74], glb_ciu_load_bus_456[71:64], glb_ciu_load_bus_456[63:0]};
    assign glb_ciu_load_bus_5 = {glb_ciu_load_bus_456[73], glb_ciu_load_bus_456[71:64], glb_ciu_load_bus_456[63:0]};
    assign glb_ciu_load_bus_6 = {glb_ciu_load_bus_456[72], glb_ciu_load_bus_456[71:64], glb_ciu_load_bus_456[63:0]};
    
    // GLB_output instance
    GLB_output glb_output(
        .CLK(CLK),
        .en(glb_output_en),
        .rst(rst),
        .glb_out_mode(glb_output_param[53:52]),
        // AGU_G
        .AGU_G_param(output_AGU_G_param), // {AGU_G_initial[13:0], glb_width[6:0], glb_ch[7:0]}
        .ch_to_Y_bus(output_ch_to_Y_bus), // {ch_to_Y_en, ch_sum[9:0]}
        .ch_to_Y_Y(output_Y), // addr offset for AGU_G
        // glb
        .glb_output_bus(glb_output_bus), // {enb, gaddr[13:0]}
        .glb_doutb(glb_doutb_buffer),
        // AGU_T
        .AGU_T_param(output_AGU_T_param), // {AGU_T_initial[11:0], tile_width[6:0], tile_ch[7:0]}
        // output tile
        .glb_load_bus(glb_load_bus), // {load_sel[6:0], taddr[7:0], glb_doutb_transposed[63:0]}
        // busy signal
        .glb_output_busy(glb_output_busy)
    );
    ////////// GLB_output end //////////
    
endmodule