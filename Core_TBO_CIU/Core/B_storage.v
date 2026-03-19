`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module B_storage (
    ///// Port A (Write Only: 64-bit) /////
    input clka,
    input ena,
    input wea,
    input [6:0] addra,
    input [63:0] dina,
    
    ///// Port B (Read Only: 32-bit) /////
    input clkb,
    input enb,
    input regceb,        // Port B 輸出暫存器 Enable
    input [7:0] addrb,
    output [31:0] doutb  // Port B 讀取資料輸出
);

    // -------------------------------------------------------------------------
    // XPM_MEMORY_SDPRAM: Simple Dual Port RAM for Block RAM (Mixed-Width)
    // -------------------------------------------------------------------------
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(7),               // Port A 地址寬度: 7 bits (2^7 = 128)
        .ADDR_WIDTH_B(8),               // Port B 地址寬度: 8 bits (2^8 = 256)
        .BYTE_WRITE_WIDTH_A(64),        // Port A 寫入寬度 (不使用 Byte Enable)
        .CLOCKING_MODE("independent_clock"),  // 獨立時鐘域
        .ECC_MODE("no_ecc"),            // 不需要 ECC
        .MEMORY_INIT_FILE("none"),       
        .MEMORY_OPTIMIZATION("true"),   // 讓 Vivado 自動優化
        .MEMORY_PRIMITIVE("block"),     // 指定 "block" (BRAM)
        .MEMORY_SIZE(8192),             // 總容量 bits = 64 * 128 = 8,192
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_B(32),         // Port B 讀取寬度
        .READ_LATENCY_B(2),             // Port B 讀取延遲 (含外部 reg)
        .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"),
        .WRITE_DATA_WIDTH_A(64),       // ★ 修正：Port A 寫入寬度必須對應 dina
        .WRITE_MODE_B("read_first")     // 讀取碰撞模式
    )
    xpm_memory_sdpram_inst (
        // Clocks & Reset
        .clka(clka),
        .clkb(clkb),
        .rstb(1'b0),          // 關閉 Port B Output Register Reset

        // Port A (Write Only)
        .ena(ena),
        .wea(wea),
        .addra(addra),
        .dina(dina),

        // Port B (Read Only)
        .enb(enb),         
        .addrb(addrb),
        .doutb(doutb),
        .regceb(regceb),
        
        // Error Injection
        .sleep(1'b0),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0)
    );

endmodule