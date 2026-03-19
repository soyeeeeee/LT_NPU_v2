`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module Tile_buffer_tdp (
    ///// Port A (Read/Write) /////
    input clka,
    input ena,
    input wea,
    input regcea,        // Port A 輸出暫存器 Enable
    input [7:0] addra,
    input [63:0] dina,
    output [63:0] douta, // Port A 讀取資料輸出
    
    ///// Port B (Read/Write) /////
    input clkb,
    input enb,
    input web,           // Port B 寫入 Enable
    input regceb,        // Port B 輸出暫存器 Enable
    input [7:0] addrb,
    input [63:0] dinb,   // Port B 寫入資料輸入
    output [63:0] doutb  // Port B 讀取資料輸出
);

    // -------------------------------------------------------------------------
    // XPM_MEMORY_TDPRAM: True Dual Port RAM for Block RAM
    // -------------------------------------------------------------------------
    xpm_memory_tdpram #(
        .ADDR_WIDTH_A(8),               // Port A 地址寬度: 8 bits (2^8 = 256)
        .ADDR_WIDTH_B(8),               // Port B 地址寬度: 8 bits (2^8 = 256)
        .BYTE_WRITE_WIDTH_A(64),         // Port A 寫入寬度 (不使用 Byte Enable)
        .BYTE_WRITE_WIDTH_B(64),         // Port B 寫入寬度 (不使用 Byte Enable)
        .CLOCKING_MODE("independent_clock"),  // two Clock
        .ECC_MODE("no_ecc"),             // 不需要 ECC
        .MEMORY_INIT_FILE("none"),       
        .MEMORY_OPTIMIZATION("true"),    // 讓 Vivado 自動優化
        .MEMORY_PRIMITIVE("block"),      // ★★★ 關鍵：改為 "block" (BRAM) ★★★
        .MEMORY_SIZE(16384),             // 總容量 bits = 64 * 256 = 16,384
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_A(64),          // Port A 讀取寬度
        .READ_DATA_WIDTH_B(64),          // Port B 讀取寬度
        .READ_LATENCY_A(2),              // Port A 讀取延遲 (含外部 reg)
        .READ_LATENCY_B(2),              // Port B 讀取延遲 (含外部 reg)
        .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"),
        .WRITE_DATA_WIDTH_A(64),         // Port A 寫入寬度
        .WRITE_DATA_WIDTH_B(64),         // Port B 寫入寬度
        .WRITE_MODE_A("write_first"),     // 讀寫同位置時，先寫入新值
        .WRITE_MODE_B("write_first")      // 讀寫同位置時，先寫入新值
    )
    xpm_memory_tdpram_inst (
        // Common Clock & Reset
        .clka(clka),
        .clkb(clkb),
        .rsta(1'b0),          // BRAM Port A Reset
        .rstb(1'b0),          // BRAM Port B Reset

        // Port A
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(dina),
        .douta(douta),
        .regcea(regcea),

        // Port B
        .enb(enb),
        .web(web),           
        .addrb(addrb),
        .dinb(dinb),
        .doutb(doutb),
        .regceb(regceb),
        
        // others
        .sleep(1'b0),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0),
        .injectsbiterrb(1'b0),
        .injectdbiterrb(1'b0)
    );

endmodule