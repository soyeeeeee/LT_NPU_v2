`timescale 1ns / 1ps

module Processing_V1 (
    input  wire        aclk,
    input  wire        aresetn,

    input  wire [63:0] s_axis_tdata,
    input  wire        s_axis_tvalid,
    input  wire        s_axis_tlast,
    output wire        s_axis_tready,

    output reg  [63:0]  m_axis_tdata, 
    output reg          m_axis_tvalid, 
    output reg          m_axis_tlast,
    input  wire         m_axis_tready
);

    // =========================================================================
    // 1. Parameters
    // =========================================================================
    localparam H_TOTAL_W      = 640;
    localparam H_CROP_LEFT    = 128;
    localparam H_ACTIVE_W     = 384; 
    localparam CNT_CROP_END   = (H_CROP_LEFT / 4); 
    localparam CNT_ACTIVE_END = CNT_CROP_END + (H_ACTIVE_W / 4);

    localparam signed [17:0] R_CONST = -56992;
    localparam signed [17:0] G_CONST =  34784;
    localparam signed [17:0] B_CONST = -70688;

    // =========================================================================
    // 2. Internal Signals
    // =========================================================================
    wire ce; 
    assign s_axis_tready = m_axis_tready; 
    assign ce = s_axis_tvalid && m_axis_tready;

    // Stage 0
    reg [9:0] x_clk_cnt;
    reg [9:0] y_line_cnt;
    reg [1:0] mod3_cnt;
    reg [1:0] phase_cnt;
    
    // Stage 1 Inputs
    reg signed [12:0] s1_y_a, s1_u_a, s1_v_a;
    reg signed [12:0] s1_y_b, s1_u_b, s1_v_b;
    reg                s1_valid_a, s1_valid_b;
    reg [1:0]          s1_phase_ref;

    // 🌟 核心修改：新增 Pipeline Stage (乘法器暫存)
    reg signed [24:0] p1_mult_y_298_a, p1_mult_u_100_a, p1_mult_u_516_a, p1_mult_v_208_a, p1_mult_v_409_a;
    reg signed [24:0] p1_mult_y_298_b, p1_mult_u_100_b, p1_mult_u_516_b, p1_mult_v_208_b, p1_mult_v_409_b;
    reg               p1_valid_a, p1_valid_b;
    reg [1:0]         p1_phase_ref;

    // Stage 1a: Summation Data
    reg signed [24:0] r_sum_a_reg, g_sum_a_reg, b_sum_a_reg;
    reg signed [24:0] r_sum_b_reg, g_sum_b_reg, b_sum_b_reg;
    reg               p2_valid_a, p2_valid_b;
    reg [1:0]         p2_phase_ref;

    // Stage 2: Outputs
    reg signed [24:0] s2_r_a, s2_g_a, s2_b_a;
    reg signed [24:0] s2_r_b, s2_g_b, s2_b_b;
    reg                s2_valid_a, s2_valid_b;
    reg [1:0]          s2_phase_ref;

    reg [31:0] pending_pixel_reg;
    reg [6:0]  out_x_cnt; 
    reg [6:0]  out_y_cnt; 

    // Input slicing
    wire [7:0] in_u0 = s_axis_tdata[7:0];
    wire [7:0] in_y0 = s_axis_tdata[15:8];
    wire [7:0] in_v0 = s_axis_tdata[23:16];
    wire [7:0] in_y1 = s_axis_tdata[31:24];
    wire [7:0] in_u2 = s_axis_tdata[39:32];
    wire [7:0] in_y2 = s_axis_tdata[47:40];
    wire [7:0] in_v2 = s_axis_tdata[55:48];
    wire [7:0] in_y3 = s_axis_tdata[63:56];

    // =========================================================================
    // 3. Stage 0: Sampling (維持不變)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            x_clk_cnt  <= 0;
            y_line_cnt <= 0;
            mod3_cnt   <= 0; 
            phase_cnt  <= 0;
            s1_valid_a <= 0;
            s1_valid_b <= 0;
        end else if (ce) begin
            if (s_axis_tlast || x_clk_cnt == (H_TOTAL_W/4 - 1)) begin
                x_clk_cnt <= 0;
                if (s_axis_tlast) begin 
                    y_line_cnt <= 0;
                    mod3_cnt   <= 0; 
                end else begin 
                    y_line_cnt <= y_line_cnt + 1;
                    if (mod3_cnt == 2'd2) mod3_cnt <= 2'd0;
                    else mod3_cnt <= mod3_cnt + 1'b1;
                end
            end else begin
                x_clk_cnt <= x_clk_cnt + 1;
            end

            if ((mod3_cnt == 2'd1) && (x_clk_cnt >= CNT_CROP_END) && (x_clk_cnt < CNT_ACTIVE_END)) begin
                s1_phase_ref <= phase_cnt; 
                case (phase_cnt)
                    2'd0: begin
                        s1_y_a <= {5'd0, in_y1}; s1_u_a <= {5'd0, in_u0}; s1_v_a <= {5'd0, in_v0};
                        s1_valid_a <= 1; s1_valid_b <= 0;
                        phase_cnt <= 2'd1;
                    end
                    2'd1: begin
                        s1_y_a <= {5'd0, in_y0}; s1_u_a <= {5'd0, in_u0}; s1_v_a <= {5'd0, in_v0};
                        s1_valid_a <= 1;
                        s1_y_b <= {5'd0, in_y3}; s1_u_b <= {5'd0, in_u2}; s1_v_b <= {5'd0, in_v2};
                        s1_valid_b <= 1;
                        phase_cnt <= 2'd2;
                    end
                    2'd2: begin
                        s1_y_a <= {5'd0, in_y2}; s1_u_a <= {5'd0, in_u2}; s1_v_a <= {5'd0, in_v2};
                        s1_valid_a <= 1; s1_valid_b <= 0;
                        phase_cnt <= 2'd0;
                    end
                endcase
            end else begin
                s1_valid_a <= 0;
                s1_valid_b <= 0;
                if (x_clk_cnt == CNT_CROP_END - 1) phase_cnt <= 0; 
            end
        end else if (!m_axis_tready) begin
        end else begin
            s1_valid_a <= 0;
            s1_valid_b <= 0;
        end
    end

    // =========================================================================
    // 4. 🌟 新增 Pipeline: Stage 1 (DSP Multiplication 暫存)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            p1_valid_a <= 0;
            p1_valid_b <= 0;
        end else if (m_axis_tready) begin
            // 讓 Vivado 自動將這些乘法映射進 DSP48 且啟用內部暫存器 (MREG=1)
            p1_mult_y_298_a <= s1_y_a * 298;
            p1_mult_u_100_a <= s1_u_a * 100;
            p1_mult_u_516_a <= s1_u_a * 516;
            p1_mult_v_208_a <= s1_v_a * 208;
            p1_mult_v_409_a <= s1_v_a * 409;

            p1_mult_y_298_b <= s1_y_b * 298;
            p1_mult_u_100_b <= s1_u_b * 100;
            p1_mult_u_516_b <= s1_u_b * 516;
            p1_mult_v_208_b <= s1_v_b * 208;
            p1_mult_v_409_b <= s1_v_b * 409;

            // 同步傳遞控制訊號
            p1_valid_a <= s1_valid_a;
            p1_valid_b <= s1_valid_b;
            p1_phase_ref <= s1_phase_ref;
        end
    end

    // =========================================================================
    // Stage 1a: Summation Logic (加法器暫存)
    // =========================================================================
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            p2_valid_a <= 0;
            p2_valid_b <= 0;
            s2_valid_a <= 0;
            s2_valid_b <= 0;
        end else if (m_axis_tready) begin 
            // 這裡的加法只吃剛剛存好的 p1_mult 暫存器，大幅縮短 Combinational Path
            if (p1_valid_a) begin
                r_sum_a_reg <= p1_mult_y_298_a + p1_mult_v_409_a + R_CONST; 
                g_sum_a_reg <= p1_mult_y_298_a - p1_mult_u_100_a - p1_mult_v_208_a + G_CONST;
                b_sum_a_reg <= p1_mult_y_298_a + p1_mult_u_516_a + B_CONST;
            end
            if (p1_valid_b) begin
                r_sum_b_reg <= p1_mult_y_298_b + p1_mult_v_409_b + R_CONST;
                g_sum_b_reg <= p1_mult_y_298_b - p1_mult_u_100_b - p1_mult_v_208_b + G_CONST;
                b_sum_b_reg <= p1_mult_y_298_b + p1_mult_u_516_b + B_CONST;
            end
            
            p2_valid_a <= p1_valid_a; 
            p2_valid_b <= p1_valid_b;
            p2_phase_ref <= p1_phase_ref;

            s2_r_a <= r_sum_a_reg; 
            s2_g_a <= g_sum_a_reg;
            s2_b_a <= b_sum_a_reg;
            
            s2_r_b <= r_sum_b_reg;
            s2_g_b <= g_sum_b_reg;
            s2_b_b <= b_sum_b_reg;
            
            s2_valid_a   <= p2_valid_a; 
            s2_valid_b   <= p2_valid_b;
            s2_phase_ref <= p2_phase_ref;
        end
    end

    // =========================================================================
    // 5. Stage 2: INT8 Output Packing
    // =========================================================================
    function [7:0] clamp_to_8bit;
        input signed [24:0] val;
        begin
            if (val[24]) clamp_to_8bit = 8'd0;       
            else if (|val[23:16]) clamp_to_8bit = 8'd255; 
            else clamp_to_8bit = val[15:8];   
        end
    endfunction

    // Pixel format: {R[7:0], G[7:0], B[7:0], Padding[7:0]}, Padding = 0
    wire [31:0] pixel_a = {clamp_to_8bit(s2_r_a), clamp_to_8bit(s2_g_a), clamp_to_8bit(s2_b_a), 8'd0};
    wire [31:0] pixel_b = {clamp_to_8bit(s2_r_b), clamp_to_8bit(s2_g_b), clamp_to_8bit(s2_b_b), 8'd0};

    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) begin
            m_axis_tvalid <= 0;
            m_axis_tdata  <= 0;
            m_axis_tlast  <= 0;
            out_x_cnt <= 0;
            out_y_cnt <= 0;
            pending_pixel_reg <= 0;
        end else if (m_axis_tready) begin
            
            m_axis_tvalid <= 0;
            m_axis_tlast  <= 0;

            if (s2_valid_a) begin
                case (s2_phase_ref)
                    2'd0: begin
                        pending_pixel_reg <= pixel_a;
                        m_axis_tvalid <= 0; 
                    end

                    2'd1: begin
                        m_axis_tdata  <= {pixel_a, pending_pixel_reg};
                        m_axis_tvalid <= 1;
                        pending_pixel_reg <= pixel_b;

                        if (out_x_cnt == 63) begin
                            out_x_cnt <= 0;
                            if (out_y_cnt == 127) begin
                                m_axis_tlast <= 1; 
                                out_y_cnt <= 0;
                            end else begin
                                out_y_cnt <= out_y_cnt + 1;
                            end
                        end else begin
                            out_x_cnt <= out_x_cnt + 1;
                        end
                    end

                    2'd2: begin
                        m_axis_tdata  <= {pixel_a, pending_pixel_reg};
                        m_axis_tvalid <= 1;
                        
                        if (out_x_cnt == 63) begin
                            out_x_cnt <= 0;
                            if (out_y_cnt == 127) begin
                                m_axis_tlast <= 1; 
                                out_y_cnt <= 0;
                            end else begin
                                out_y_cnt <= out_y_cnt + 1;
                            end
                        end else begin
                            out_x_cnt <= out_x_cnt + 1;
                        end
                    end
                endcase
            end
        end
    end

endmodule