`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module IS_storage (
    input clka,
    input ena,
    input regcea,        // 輸出暫存器 Enable
    input [7:0] addra,   // 地址寬度: 8 bits (對應 256 個 address)
    output [39:0] douta  // 讀取資料輸出: 40 bits
);

    // -------------------------------------------------------------------------
    // XPM_MEMORY_SPROM: Single Port ROM
    // -------------------------------------------------------------------------
    xpm_memory_sprom #(
        .ADDR_WIDTH_A(8),               // 地址寬度: 8 bits (2^8 = 256)
        .ECC_MODE("no_ecc"),            // 不需要 ECC
        .MEMORY_INIT_FILE("is_data.mem"), // ★★★ 指定你的初始化檔案名稱
        .MEMORY_INIT_PARAM(""),         // 使用檔案的話，這裡保持空白
        .MEMORY_OPTIMIZATION("true"),   // 讓 Vivado 自動優化
        .MEMORY_PRIMITIVE("block"),     // 指定 "block" (BRAM)
        .MEMORY_SIZE(10240),            // ★ 總容量 bits = 256 * 40 = 10,240
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_A(40),         // 讀取寬度: 40 bits
        .READ_LATENCY_A(2),             // 讀取延遲 (含外部 reg)
        .USE_MEM_INIT(1),               // ★★★ 關鍵：設為 1 才會去讀取初始化檔案
        .WAKEUP_TIME("disable_sleep")
    )
    xpm_memory_sprom_inst (
        // Clock & Reset
        .clka(clka),
        .rsta(1'b0),          // 關閉 Output Register Reset

        // Port A (Read Only)
        .ena(ena),
        .regcea(regcea),
        .addra(addra),
        .douta(douta),
        
        // Others
        .sleep(1'b0),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0)
    );

endmodule