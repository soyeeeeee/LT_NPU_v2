`timescale 1ns / 1ps

(* DONT_TOUCH = "TRUE" *)
module W_storage (
    input CLK,
    input rst,         // Reset (只重置輸出 Register，不清除內部陣列資料)
    ///// Port A (Write) /////
    input ena,
    input wea,
    input [12:0] addra,
    input [31:0] dina,
    ///// Port B (Read) /////
    input enb,
    input regceb,
    input [12:0] addrb,
    output [31:0] doutb
);

    // -------------------------------------------------------------------------
    // XPM_MEMORY_SDPRAM: Simple Dual Port RAM for UltraRAM
    // -------------------------------------------------------------------------
    xpm_memory_sdpram #(
        .ADDR_WIDTH_A(13),               // 修正：地址寬度 13 bits (2^13 = 8192)
        .ADDR_WIDTH_B(13),               // 修正：讀取端與寫入端一致
        .BYTE_WRITE_WIDTH_A(32),         // 64: 不使用 Byte Enable (一次寫64bit)
        .CLOCKING_MODE("common_clock"),  // 讀寫共用同一個 Clock
        .ECC_MODE("no_ecc"),             // 不需要 ECC
        .MEMORY_INIT_FILE("none"),       // URAM 不支援初始值檔案
        .MEMORY_OPTIMIZATION("true"),    // 讓 Vivado 自動優化
        .MEMORY_PRIMITIVE("ultra"),      // ★★★ 關鍵：強制指定 "ultra" (URAM) ★★★
        .MEMORY_SIZE(262144),            // 總容量 bits = 32 * 8192 = 262144
        .MESSAGE_CONTROL(0),
        .READ_DATA_WIDTH_B(32),          // 讀取寬度
        .READ_LATENCY_B(2),              // already has core output reg outside the GLB
        .USE_MEM_INIT(0),
        .WAKEUP_TIME("disable_sleep"),
        .WRITE_DATA_WIDTH_A(32),         // 寫入寬度
        .WRITE_MODE_B("read_first")      // 讀取時不干擾 (效能最好)
    )
    xpm_memory_sdpram_inst (
        // Common Clock
        .clka(CLK),
        .clkb(CLK),
        .rstb(rst),          // URAM 的 Reset 主要是清空 Output Register

        // Port A (Write)
        .ena(ena),          
        .wea(wea),          
        .addra(addra),
        .dina(dina),
        
        // Port B (Read)
        .enb(enb),          
        .addrb(addrb),
        .doutb(doutb),
        
        // others
        .regceb(regceb),
        .sleep(1'b0),
        .injectsbiterra(1'b0),
        .injectdbiterra(1'b0)
    );

endmodule