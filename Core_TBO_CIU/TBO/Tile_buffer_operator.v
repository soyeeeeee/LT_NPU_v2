`timescale 1ns / 1ps

module Tile_buffer_operator(
    input clka,
    input clkb,
    input rst,
    ////////// Control param //////////
    input [22:0] tbo_param, // {tile_sel_cycle, tile_assign}
    ////////// address & data bus //////////
    // tile load
    input [40:0] ciu_tbo_load_bus, // {valid, addr, din}
    // tile cycle
    input [40:0] ciu_tbo_cycle_bus_a, // {valid, addr, din}
    input [40:0] ciu_tbo_cycle_bus_b, // {valid, addr, din}
    output reg [31:0] tbo_ciu_cycle_data,
    // tile wb
    input [8:0] ciu_tbo_wb_bus, // {en_wb, addr_wb}
    output [31:0] tbo_ciu_wb_data,
    // tile cal
    input [8:0] core_tbo_cal_bus, // {valid_cal, addr_cal}
    output [31:0] tbo_core_cal_data_1,
    output [31:0] tbo_core_cal_data_2,
    output [31:0] tbo_core_cal_data_3,
    output [31:0] tbo_core_cal_data_4,
    output [31:0] tbo_core_cal_data_5,
    output [31:0] tbo_core_cal_data_6,
    // tile store
    input [40:0] core_tbo_store_bus // {valid, addr, din}
    );

    ////////// input buffer ///////////
    reg [2:0] tile_sel_cycle;
    reg [19:0] tile_assign;
    always@(posedge clka) begin
        if(rst) begin
            tile_sel_cycle <= 3'd0;
            tile_assign <= 20'd0;
        end
        else begin
            tile_sel_cycle <= tbo_param[22:20];
            tile_assign <= tbo_param[19:0];
        end
    end
    ////////// input buffer end ///////////

    ////////// define function //////////
    parameter none = 3'd0, cal_0 = 3'd1, cal_1 = 3'd2, cal_2 = 3'd3, load = 3'd4, cycle = 3'd5, store = 3'd6;
    ////////// define function end /////////

    ////////// tile 1 //////////
    reg ena_1, enb_1;
    reg wea_1, web_1;
    wire [31:0] douta_1;
    reg [7:0] addra_1, addrb_1;
    reg [31:0] dina_1, dinb_1;
    // mux
    always@(*) begin
        case(tile_assign[19:17])
            cal_0, cal_1, cal_2: begin
                ena_1 = 0;
                enb_1 = core_tbo_cal_bus[8];
                wea_1 = 0;
                web_1 = 0;
                addra_1 = 8'd0;
                dina_1 = 32'd0;
                addrb_1 = core_tbo_cal_bus[7:0];
                dinb_1 = 32'd0;
            end
            load: begin
                ena_1 = 1;
                enb_1 = 0;
                wea_1 = ciu_tbo_load_bus[40];
                web_1 = 0;
                addra_1 = ciu_tbo_load_bus[39:32];
                dina_1 = ciu_tbo_load_bus[31:0];
                addrb_1 = 8'd0;
                dinb_1 = 32'd0;
            end
            cycle: begin
                ena_1 = 1;
                enb_1 = 1;
                wea_1 = ciu_tbo_cycle_bus_a[40];
                addra_1 = ciu_tbo_cycle_bus_a[39:32];
                dina_1 = ciu_tbo_cycle_bus_a[31:0];
                web_1 = ciu_tbo_cycle_bus_b[40];
                addrb_1 = ciu_tbo_cycle_bus_b[39:32];
                dinb_1 = ciu_tbo_cycle_bus_b[31:0];
            end
            store: begin
                ena_1 = 0;
                enb_1 = 1;
                wea_1 = 0;
                web_1 = core_tbo_store_bus[40];
                addra_1 = 8'd0;
                dina_1 = 32'd0;
                addrb_1 = core_tbo_store_bus[39:32];
                dinb_1 = core_tbo_store_bus[31:0];
            end
            default: begin
                ena_1 = 0;
                enb_1 = 0;
                wea_1 = 0;
                web_1 = 0;
                addra_1 = 8'd0;
                dina_1 = 32'd0;
                addrb_1 = 8'd0;
                dinb_1 = 32'd0;
            end
        endcase
    end

    Tile_buffer_tdp tile_buffer_1(
        .clka(clka),
        .ena(ena_1),
        .wea(wea_1),
        .regcea(1'b1),
        .addra(addra_1),
        .dina(dina_1),
        .douta(douta_1),
        .clkb(clkb),
        .enb(enb_1),
        .web( web_1 ),
        .regceb(1'b1),
        .addrb(addrb_1),
        .dinb(dinb_1),
        .doutb(tbo_core_cal_data_1)
    );
    ////////// tile 1 end //////////

    ////////// tile 2 //////////
    reg ena_2, enb_2;
    reg wea_2, web_2;
    wire [31:0] douta_2;
    reg [7:0] addra_2, addrb_2;
    reg [31:0] dina_2, dinb_2;
    // mux
    always@(*) begin
        case(tile_assign[16:14])
            cal_0, cal_1, cal_2: begin
                ena_2 = 0;
                enb_2 = core_tbo_cal_bus[8];
                wea_2 = 0;
                web_2 = 0;
                addra_2 = 8'd0;
                dina_2 = 32'd0;
                addrb_2 = core_tbo_cal_bus[7:0];
                dinb_2 = 32'd0;
            end
            load: begin
                ena_2 = 1;
                enb_2 = 0;
                wea_2 = ciu_tbo_load_bus[40];
                web_2 = 0;
                addra_2 = ciu_tbo_load_bus[39:32];
                dina_2 = ciu_tbo_load_bus[31:0];
                addrb_2 = 8'd0;
                dinb_2 = 32'd0;
            end
            cycle: begin
                ena_2 = 1;
                enb_2 = 1;
                wea_2 = ciu_tbo_cycle_bus_a[40];
                addra_2 = ciu_tbo_cycle_bus_a[39:32];
                dina_2 = ciu_tbo_cycle_bus_a[31:0];
                web_2 = ciu_tbo_cycle_bus_b[40];
                addrb_2 = ciu_tbo_cycle_bus_b[39:32];
                dinb_2 = ciu_tbo_cycle_bus_b[31:0];
            end
            store: begin
                ena_2 = 0;
                enb_2 = 1;
                wea_2 = 0;
                web_2 = core_tbo_store_bus[40];
                addra_2 = 8'd0;
                dina_2 = 32'd0;
                addrb_2 = core_tbo_store_bus[39:32];
                dinb_2 = core_tbo_store_bus[31:0];
            end
            default: begin
                ena_2 = 0;
                enb_2 = 0;
                wea_2 = 0;
                web_2 = 0;
                addra_2 = 8'd0;
                dina_2 = 32'd0;
                addrb_2 = 8'd0;
                dinb_2 = 32'd0;
            end
        endcase
    end

    Tile_buffer_tdp tile_buffer_2(
        .clka(clka),
        .ena(ena_2),
        .wea(wea_2),
        .regcea(1'b1),
        .addra(addra_2),
        .dina(dina_2),
        .douta(douta_2),
        .clkb(clkb),
        .enb(enb_2),
        .web( web_2 ),
        .regceb(1'b1),
        .addrb(addrb_2),
        .dinb(dinb_2),
        .doutb(tbo_core_cal_data_2)
    );
    ////////// tile 2 end //////////

    ////////// tile 3 //////////
    reg ena_3, enb_3;
    reg wea_3, web_3;
    wire [31:0] douta_3;
    reg [7:0] addra_3, addrb_3;
    reg [31:0] dina_3, dinb_3;
    // mux
    always@(*) begin
        case(tile_assign[13:11])
            cal_0, cal_1, cal_2: begin
                ena_3 = 0;
                enb_3 = core_tbo_cal_bus[8];
                wea_3 = 0;
                web_3 = 0;
                addra_3 = 8'd0;
                dina_3 = 32'd0;
                addrb_3 = core_tbo_cal_bus[7:0];
                dinb_3 = 32'd0;
            end
            load: begin
                ena_3 = 1;
                enb_3 = 0;
                wea_3 = ciu_tbo_load_bus[40];
                web_3 = 0;
                addra_3 = ciu_tbo_load_bus[39:32];
                dina_3 = ciu_tbo_load_bus[31:0];
                addrb_3 = 8'd0;
                dinb_3 = 32'd0;
            end
            cycle: begin
                ena_3 = 1;
                enb_3 = 1;
                wea_3 = ciu_tbo_cycle_bus_a[40];
                addra_3 = ciu_tbo_cycle_bus_a[39:32];
                dina_3 = ciu_tbo_cycle_bus_a[31:0];
                web_3 = ciu_tbo_cycle_bus_b[40];
                addrb_3 = ciu_tbo_cycle_bus_b[39:32];
                dinb_3 = ciu_tbo_cycle_bus_b[31:0];
            end
            store: begin
                ena_3 = 0;
                enb_3 = 1;
                wea_3 = 0;
                web_3 = core_tbo_store_bus[40];
                addra_3 = 8'd0;
                dina_3 = 32'd0;
                addrb_3 = core_tbo_store_bus[39:32];
                dinb_3 = core_tbo_store_bus[31:0];
            end
            default: begin
                ena_3 = 0;
                enb_3 = 0;
                wea_3 = 0;
                web_3 = 0;
                addra_3 = 8'd0;
                dina_3 = 32'd0;
                addrb_3 = 8'd0;
                dinb_3 = 32'd0;
            end
        endcase
    end

    Tile_buffer_tdp tile_buffer_3(
        .clka(clka),
        .ena(ena_3),
        .wea(wea_3),
        .regcea(1'b1),
        .addra(addra_3),
        .dina(dina_3),
        .douta(douta_3),
        .clkb(clkb),
        .enb(enb_3),
        .web( web_3 ),
        .regceb(1'b1),
        .addrb(addrb_3),
        .dinb(dinb_3),
        .doutb(tbo_core_cal_data_3)
    );
    ////////// tile 3 end //////////

    ////////// tile 4 //////////
    reg ena_4, enb_4;
    reg wea_4, web_4;
    wire [31:0] douta_4;
    reg [7:0] addra_4, addrb_4;
    reg [31:0] dina_4, dinb_4;
    // mux
    always@(*) begin
        case(tile_assign[10:8])
            cal_0, cal_1, cal_2: begin
                ena_4 = 0;
                enb_4 = core_tbo_cal_bus[8];
                wea_4 = 0;
                web_4 = 0;
                addra_4 = 8'd0;
                dina_4 = 32'd0;
                addrb_4 = core_tbo_cal_bus[7:0];
                dinb_4 = 32'd0;
            end
            load: begin
                ena_4 = 1;
                enb_4 = 0;
                wea_4 = ciu_tbo_load_bus[40];
                web_4 = 0;
                addra_4 = ciu_tbo_load_bus[39:32];
                dina_4 = ciu_tbo_load_bus[31:0];
                addrb_4 = 8'd0;
                dinb_4 = 32'd0;
            end
            cycle: begin
                ena_4 = 1;
                enb_4 = 1;
                wea_4 = ciu_tbo_cycle_bus_a[40];
                addra_4 = ciu_tbo_cycle_bus_a[39:32];
                dina_4 = ciu_tbo_cycle_bus_a[31:0];
                web_4 = ciu_tbo_cycle_bus_b[40];
                addrb_4 = ciu_tbo_cycle_bus_b[39:32];
                dinb_4 = ciu_tbo_cycle_bus_b[31:0];
            end
            store: begin
                ena_4 = 0;
                enb_4 = 1;
                wea_4 = 0;
                web_4 = core_tbo_store_bus[40];
                addra_4 = 8'd0;
                dina_4 = 32'd0;
                addrb_4 = core_tbo_store_bus[39:32];
                dinb_4 = core_tbo_store_bus[31:0];
            end
            default: begin
                ena_4 = 0;
                enb_4 = 0;
                wea_4 = 0;
                web_4 = 0;
                addra_4 = 8'd0;
                dina_4 = 32'd0;
                addrb_4 = 8'd0;
                dinb_4 = 32'd0;
            end
        endcase
    end

    Tile_buffer_tdp tile_buffer_4(
        .clka(clka),
        .ena(ena_4),
        .wea(wea_4),
        .regcea(1'b1),
        .addra(addra_4),
        .dina(dina_4),
        .douta(douta_4),
        .clkb(clkb),
        .enb(enb_4),
        .web( web_4 ),
        .regceb(1'b1),
        .addrb(addrb_4),
        .dinb(dinb_4),
        .doutb(tbo_core_cal_data_4)
    );
    ////////// tile 4 end //////////

    ////////// tile 5 //////////
    reg ena_5, enb_5;
    reg wea_5, web_5;
    wire [31:0] douta_5;
    reg [7:0] addra_5, addrb_5;
    reg [31:0] dina_5, dinb_5;
    // mux
    always@(*) begin
        case(tile_assign[7:5])
            cal_0, cal_1, cal_2: begin
                ena_5 = 0;
                enb_5 = core_tbo_cal_bus[8];
                wea_5 = 0;
                web_5 = 0;
                addra_5 = 8'd0;
                dina_5 = 32'd0;
                addrb_5 = core_tbo_cal_bus[7:0];
                dinb_5 = 32'd0;
            end
            load: begin
                ena_5 = 1;
                enb_5 = 0;
                wea_5 = ciu_tbo_load_bus[40];
                web_5 = 0;
                addra_5 = ciu_tbo_load_bus[39:32];
                dina_5 = ciu_tbo_load_bus[31:0];
                addrb_5 = 8'd0;
                dinb_5 = 32'd0;
            end
            cycle: begin
                ena_5 = 1;
                enb_5 = 1;
                wea_5 = ciu_tbo_cycle_bus_a[40];
                addra_5 = ciu_tbo_cycle_bus_a[39:32];
                dina_5 = ciu_tbo_cycle_bus_a[31:0];
                web_5 = ciu_tbo_cycle_bus_b[40];
                addrb_5 = ciu_tbo_cycle_bus_b[39:32];
                dinb_5 = ciu_tbo_cycle_bus_b[31:0];
            end
            store: begin
                ena_5 = 0;
                enb_5 = 1;
                wea_5 = 0;
                web_5 = core_tbo_store_bus[40];
                addra_5 = 8'd0;
                dina_5 = 32'd0;
                addrb_5 = core_tbo_store_bus[39:32];
                dinb_5 = core_tbo_store_bus[31:0];
            end
            default: begin
                ena_5 = 0;
                enb_5 = 0;
                wea_5 = 0;
                web_5 = 0;
                addra_5 = 8'd0;
                dina_5 = 32'd0;
                addrb_5 = 8'd0;
                dinb_5 = 32'd0;
            end
        endcase
    end

    Tile_buffer_tdp tile_buffer_5(
        .clka(clka),
        .ena(ena_5),
        .wea( wea_5 ),
        .regcea(1'b1),
        .addra(addra_5),
        .dina(dina_5),
        .douta(douta_5),
        .clkb(clkb),
        .enb(enb_5),
        .web( web_5 ),
        .regceb(1'b1),
        .addrb(addrb_5),
        .dinb(dinb_5),
        .doutb(tbo_core_cal_data_5)
    );
    ////////// tile 5 end //////////

    ////////// tile 6 //////////
    reg ena_6, enb_6;
    reg wea_6, web_6;
    wire [31:0] douta_6;
    reg [7:0] addra_6, addrb_6;
    reg [31:0] dina_6, dinb_6;
    // mux
    always@(*) begin
        case(tile_assign[4:2])
            cal_0, cal_1, cal_2: begin
                ena_6 = 0;
                enb_6 = core_tbo_cal_bus[8];
                wea_6 = 0;
                web_6 = 0;
                addra_6 = 8'd0;
                dina_6 = 32'd0;
                addrb_6 = core_tbo_cal_bus[7:0];
                dinb_6 = 32'd0;
            end
            load: begin
                ena_6 = 1;
                enb_6 = 0;
                wea_6 = ciu_tbo_load_bus[40];
                web_6 = 0;
                addra_6 = ciu_tbo_load_bus[39:32];
                dina_6 = ciu_tbo_load_bus[31:0];
                addrb_6 = 8'd0;
                dinb_6 = 32'd0;
            end
            cycle: begin
                ena_6 = 1;
                enb_6 = 1;
                wea_6 = ciu_tbo_cycle_bus_a[40];
                addra_6 = ciu_tbo_cycle_bus_a[39:32];
                dina_6 = ciu_tbo_cycle_bus_a[31:0];
                web_6 = ciu_tbo_cycle_bus_b[40];
                addrb_6 = ciu_tbo_cycle_bus_b[39:32];
                dinb_6 = ciu_tbo_cycle_bus_b[31:0];
            end
            store: begin
                ena_6 = 0;
                enb_6 = 1;
                wea_6 = 0;
                web_6 = core_tbo_store_bus[40];
                addra_6 = 8'd0;
                dina_6 = 32'd0;
                addrb_6 = core_tbo_store_bus[39:32];
                dinb_6 = core_tbo_store_bus[31:0];
            end
            default: begin
                ena_6 = 0;
                enb_6 = 0;
                wea_6 = 0;
                web_6 = 0;
                addra_6 = 8'd0;
                dina_6 = 32'd0;
                addrb_6 = 8'd0;
                dinb_6 = 32'd0;
            end
        endcase
    end

    Tile_buffer_tdp tile_buffer_6(
        .clka(clka),
        .ena(ena_6),
        .wea( wea_6 ),
        .regcea(1'b1),
        .addra(addra_6),
        .dina(dina_6),
        .douta(douta_6),
        .clkb(clkb),
        .enb(enb_6),
        .regceb(1'b1),
        .web( web_6 ),
        .addrb(addrb_6),
        .dinb(dinb_6),
        .doutb(tbo_core_cal_data_6)
    );
    ////////// tile 6 end //////////

    ////////// tile 7 //////////
    reg ena_7, enb_7;
    reg wea_7;
    reg [7:0] addra_7, addrb_7;
    reg [31:0] dina_7;
    // mux
    always@(*) begin
        case(tile_assign[1:0])
            1: begin // store
                ena_7 = 1;
                enb_7 = 0;
                wea_7 = core_tbo_store_bus[40];
                addra_7 = core_tbo_store_bus[39:32];
                dina_7 = core_tbo_store_bus[31:0];
                addrb_7 = 8'd0;
            end
            2: begin // out
                ena_7 = 0;
                enb_7 = ciu_tbo_wb_bus[8];
                wea_7 = 0;
                addra_7 = 8'd0;
                dina_7 = 32'd0;
                addrb_7 = ciu_tbo_wb_bus[7:0];
            end
            default: begin
                ena_7 = 0;
                enb_7 = 0;
                wea_7 = 0;
                addra_7 = 8'd0;
                dina_7 = 32'd0;
                addrb_7 = 8'd0;
            end
        endcase
    end

    Tile_buffer_sdp tile_buffer_7(
        .clka(clka),
        .ena(ena_7),
        .wea(wea_7),
        .addra(addra_7),
        .dina(dina_7),
        .clkb(clkb),
        .enb(enb_7),
        .regceb(1'b1),
        .addrb(addrb_7),
        .doutb(tbo_ciu_wb_data)
    );
    ////////// tile 7 end //////////

    ////////// cycle out //////////
    always@(*) begin
        case(tile_sel_cycle)
            1: tbo_ciu_cycle_data = douta_1;
            2: tbo_ciu_cycle_data = douta_2;
            3: tbo_ciu_cycle_data = douta_3;
            4: tbo_ciu_cycle_data = douta_4;
            5: tbo_ciu_cycle_data = douta_5;
            6: tbo_ciu_cycle_data = douta_6;
            default: tbo_ciu_cycle_data = 32'd0;
        endcase
    end
    ////////// cycle out end //////////
endmodule