// zynq_display_ctrl.v
// 显示控制：VGA 时序发生器 + AXI4-HP0 帧缓存写（双缓冲 A/B）
// 目标：Zynq UltraScale+ MPSoC（本工程 xczu4ev + AXU4EVB）
//
// 功能概述:
//   接收后级像素流（ddr3_pixel_buf 输出），并行完成：
//     1) 通过 AXI4-HP0 以 INCR burst 写入 PS DDR 帧缓存（双缓冲 page A/B）
//     2) 产生 VGA/HDMI 用的 hsync、vsync、de，并在 pclk 域输出 vga_pixel
//
//   PS 侧由 VDMA 或裸机驱动从 DDR 读帧缓存；frame_done_irq 表示一帧写完，
//   buf_sel 指示刚写完的页（0=A, 1=B）。
//
// 数据通路（文字框图）:
//   s_pix_data -> line FIFO(BRAM) -> AXI 64b 打包写 -> S_AXI_HP0 -> DDR4
//              -> display FIFO(BRAM, pclk) -> vga_timing_gen -> vga_hsync/vsync/de, vga_pixel
//   frame_done_irq ----------------------------------------------------> PS GIC
//
// 双缓冲:
//   buf_sel=0: 正在写 fb_addr_a；PS 可从 fb_addr_b 读
//   buf_sel=1: 正在写 fb_addr_b；PS 可从 fb_addr_a 读
//   在 frame_done_irq 处切换；建议在下一 VSYNC 更新 VDMA 地址以减少撕裂。
//
// FIFO 说明:
//   Line FIFO: pl_clk 域缓存，深度 LINE_FIFO_DEPTH（默认 2048），像素零扩展到 32b 便于 64b AXI 打包。
//   Display FIFO: 本实现为 pclk 单时钟同步 FIFO；若 pl_clk 与 pclk 异步，应改为异步 FIFO。
//
// AXI4-HP0:
//   数据位宽 64；突发 INCR；长度 BURST_LEN（默认 16）；每像素存 32b（FB_PIX_W=32）。
//
// VGA:
//   vga_timing_gen 由 res_sel[1:0] 选择 2K/1080p/720p。
//
// 资源（典型）:
//   2x RAMB36: line FIFO + display FIFO
//   ~2 DSP: 像素打包
// =============================================================================
`timescale 1ns / 1ps

module zynq_display_ctrl #(
    parameter PIXEL_W         = 13,    // Internal pixel width (Q0.13)
    parameter AXI_DW          = 64,    // AXI4 HP0 data bus width
    parameter AXI_AW          = 32,    // AXI4 address width
    parameter BURST_LEN       = 16,    // AXI4 burst length (beats)
    parameter FB_H            = 2048,  // Frame buffer width (pixels)
    parameter FB_V            = 1080,  // Frame buffer height (lines)
    parameter FB_PIX_W        = 32,    // DDR storage width per pixel (bits)
    parameter LINE_FIFO_DEPTH = 2048   // Line FIFO depth (pixels)
)(
    // -------------------------------------------------------------------------
    // Clocks and reset
    // -------------------------------------------------------------------------
    input  wire                  clk,        // PL processing clock (150 MHz)
    input  wire                  pclk,       // Pixel clock for VGA (148 MHz)
    input  wire                  rst_n,      // Active-low sync reset (clk domain)
    input  wire                  pclk_rst_n, // Active-low sync reset (pclk domain, from MMCM locked)

    // -------------------------------------------------------------------------
    // Input pixel stream -- from ddr3_pixel_buf (s_pix_data / s_pix_valid)
    // No back-pressure: upstream is free-running.
    // -------------------------------------------------------------------------
    input  wire [PIXEL_W-1:0]    s_pix_data,
    input  wire                  s_pix_valid,

    // -------------------------------------------------------------------------
    // Configuration -- from AXI4-Lite registers in imgproc_top
    // -------------------------------------------------------------------------
    input  wire [1:0]             res_sel,    // 00=2K 01=1080p 10=720p
    input  wire [AXI_AW-1:0]     fb_addr_a,  // Frame buffer A base address
    input  wire [AXI_AW-1:0]     fb_addr_b,  // Frame buffer B base address
    input  wire                   cfg_start,  // Enable write path (from ctrl reg)

    // -------------------------------------------------------------------------
    // AXI4-HP0 write master -- burst write to PS DDR frame buffer
    // Read channel not used (display reads via PS VDMA, not this module).
    // -------------------------------------------------------------------------
    output reg  [AXI_AW-1:0]     m_axi_awaddr,
    output reg  [7:0]             m_axi_awlen,
    output reg  [2:0]             m_axi_awsize,
    output reg  [1:0]             m_axi_awburst,
    output reg                    m_axi_awvalid,
    input  wire                   m_axi_awready,
    output reg  [AXI_DW-1:0]     m_axi_wdata,
    output reg  [AXI_DW/8-1:0]   m_axi_wstrb,
    output reg                    m_axi_wlast,
    output reg                    m_axi_wvalid,
    input  wire                   m_axi_wready,
    input  wire [1:0]             m_axi_bresp,
    input  wire                   m_axi_bvalid,
    output reg                    m_axi_bready,

    // -------------------------------------------------------------------------
    // VGA / HDMI timing outputs -- to top-level (HDMI register stage)
    // -------------------------------------------------------------------------
    output wire                   vga_hsync,
    output wire                   vga_vsync,
    output wire                   vga_de,
    output wire [PIXEL_W-1:0]     vga_pixel,  // 13-bit Q0.13 pixel
    output wire                   vga_active,

    // -------------------------------------------------------------------------
    // Status outputs
    // -------------------------------------------------------------------------
    output reg                    frame_done_irq,  // One-cycle pulse at frame end
    output reg                    buf_sel           // Current write buffer (0=A,1=B)
);

    // =========================================================================
    // Line FIFO: buffers pixels for AXI burst packing
    // Stores pixels as 32-bit words (pixel zero-extended to 32b).
    // Two pixels are packed into each 64-bit AXI beat.
    // =========================================================================
    localparam PACK      = AXI_DW / 32;           // 2 pixels per AXI beat
    localparam BURST_PIX = BURST_LEN * PACK;       // 32 pixels per burst
    localparam FB_BYTES  = FB_H * FB_V * (FB_PIX_W / 8); // 2048*1080*4 = 8,847,360

    // Zero-extend pixel to 32 bits for AXI compatibility
    wire [31:0]  pix32 = {{(32-PIXEL_W){1'b0}}, s_pix_data};

    wire         fifo_wr_en   = s_pix_valid && cfg_start;
    wire         fifo_rd_en;
    wire [31:0]  fifo_rd_data;
    wire         fifo_rd_vld;
    wire         fifo_full;
    wire         fifo_empty;
    wire [11:0]  fifo_cnt;

    fifo_sync #(
        .DATA_W ($clog2(LINE_FIFO_DEPTH) > 0 ? 32 : 32),  // 32-bit words
        .DEPTH  (LINE_FIFO_DEPTH),
        .ADDR_W ($clog2(LINE_FIFO_DEPTH)),
        .DO_REG (0),
        .FWFT   (0)
    ) u_line_fifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (fifo_wr_en),
        .wr_data      (pix32),
        .full         (fifo_full),
        .almost_full  (),
        .rd_en        (fifo_rd_en),
        .rd_data      (fifo_rd_data),
        .rd_data_vld  (fifo_rd_vld),
        .empty        (fifo_empty),
        .almost_empty (),
        .data_count   (fifo_cnt)
    );

    // =========================================================================
    // AXI4-HP0 write FSM: AXI_IDLE -> AXI_ADDR -> AXI_DATA -> AXI_RESP
    // Fires when LINE_FIFO holds enough pixels for a full burst.
    // Two consecutive 32-bit FIFO entries are packed into each 64-bit beat.
    // =========================================================================
    localparam AXI_IDLE = 2'd0;
    localparam AXI_ADDR = 2'd1;
    localparam AXI_DATA = 2'd2;
    localparam AXI_RESP = 2'd3;

    reg [1:0]          axi_st;
    reg [7:0]           beat_cnt;
    reg [AXI_AW-1:0]   wr_ptr;       // Byte pointer within current frame buffer
    reg                 pack_toggle;  // Alternates to collect two 32-bit words per beat
    reg [31:0]          pack_buf;     // Holds the first 32-bit word until the second arrives
    reg                 fifo_pop;

    assign fifo_rd_en = fifo_pop;

    // Fire condition: enough pixels in the FIFO for BURST_PIX pixels = BURST_LEN beats
    wire [11:0] burst_threshold = BURST_PIX[11:0];
    wire        fire = (fifo_cnt >= burst_threshold);

    wire [AXI_AW-1:0] fb_base = buf_sel ? fb_addr_b : fb_addr_a;

    always @(posedge clk) begin
        if (!rst_n) begin
            axi_st         <= AXI_IDLE;
            m_axi_awvalid  <= 1'b0;
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b1;
            m_axi_awsize   <= 3'b011;               // 8 bytes per beat
            m_axi_awburst  <= 2'b01;                // INCR burst type
            m_axi_awlen    <= BURST_LEN[7:0] - 1;
            m_axi_wstrb    <= {(AXI_DW/8){1'b1}};   // All byte-enables
            wr_ptr         <= {AXI_AW{1'b0}};
            beat_cnt       <= 8'd0;
            buf_sel        <= 1'b0;
            frame_done_irq <= 1'b0;
            pack_toggle    <= 1'b0;
            fifo_pop       <= 1'b0;
        end else begin
            fifo_pop       <= 1'b0;
            frame_done_irq <= 1'b0;

            case (axi_st)

                // Wait for enough data in the FIFO, then initiate a burst.
                AXI_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    if (cfg_start && fire) begin
                        m_axi_awaddr <= fb_base + wr_ptr;
                        axi_st       <= AXI_ADDR;
                    end
                end

                // Hold AWVALID until AWREADY is asserted by the SmartConnect.
                AXI_ADDR: begin
                    m_axi_awvalid <= 1'b1;
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        beat_cnt      <= 8'd0;
                        pack_toggle   <= 1'b0;
                        axi_st        <= AXI_DATA;
                        fifo_pop      <= 1'b1;   // Pre-fetch first 32-bit word
                    end
                end

                // Pack two 32-bit FIFO words into each 64-bit AXI beat.
                // pack_toggle=0: latch first word into pack_buf
                // pack_toggle=1: combine with second word and issue beat
                AXI_DATA: begin
                    if (fifo_rd_vld) begin
                        if (!pack_toggle) begin
                            pack_buf    <= fifo_rd_data;
                            pack_toggle <= 1'b1;
                            fifo_pop    <= 1'b1;   // Fetch second word
                        end else begin
                            m_axi_wdata  <= {fifo_rd_data, pack_buf};
                            m_axi_wvalid <= 1'b1;
                            m_axi_wlast  <= (beat_cnt == BURST_LEN[7:0] - 1);
                            pack_toggle  <= 1'b0;
                            if (m_axi_wready) begin
                                beat_cnt <= beat_cnt + 1;
                                wr_ptr   <= wr_ptr + (AXI_DW / 8);
                                if (beat_cnt < BURST_LEN[7:0] - 1) begin
                                    fifo_pop <= 1'b1;   // Fetch next word pair
                                end else begin
                                    m_axi_wvalid <= 1'b0;
                                    axi_st       <= AXI_RESP;
                                end
                            end
                        end
                    end
                end

                // Wait for write response; toggle buffer and fire IRQ at frame end.
                AXI_RESP: begin
                    m_axi_bready <= 1'b1;
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        if (wr_ptr >= FB_BYTES[AXI_AW-1:0] - (AXI_DW/8)) begin
                            // Frame complete: reset pointer, flip buffer, notify PS
                            wr_ptr         <= {AXI_AW{1'b0}};
                            frame_done_irq <= 1'b1;
                            buf_sel        <= !buf_sel;
                        end
                        axi_st <= AXI_IDLE;
                    end
                end

                default: axi_st <= AXI_IDLE;
            endcase
        end
    end

    // =========================================================================
    // VGA timing generator -- pclk domain
    // Generates hsync, vsync, de, pixel_x, pixel_y, active_region.
    // Resolution: res_sel 00=2048x1080, 01=1920x1080, 10=1280x720
    // =========================================================================
    wire        vga_active_w;
    wire [11:0] vga_px;
    wire [10:0] vga_py;
    wire        vga_frame_start;
    wire        vga_line_start;

    vga_timing_gen #(
        .H_TOTAL_2K   (2200),
        .H_ACTIVE_2K  (2048),
        .H_FRONT_2K   (88),
        .H_SYNC_2K    (44),
        .H_BACK_2K    (104),
        .V_TOTAL      (1125),
        .V_ACTIVE     (1080),
        .V_FRONT      (4),
        .V_SYNC       (5),
        .V_BACK       (36),
        .H_ACT_1080P  (1920),
        .H_ACT_720P   (1280),
        .V_ACT_720P   (720)
    ) u_vtg (
        .pclk          (pclk),
        .rst_n         (rst_n),
        .res_sel       (res_sel),
        .hsync         (vga_hsync),
        .vsync         (vga_vsync),
        .de            (vga_de),
        .pixel_x       (vga_px),
        .pixel_y       (vga_py),
        .active_region (vga_active_w),
        .frame_start   (vga_frame_start),
        .line_start    (vga_line_start),
        .mmcm_rst      ()
    );

    assign vga_active = vga_active_w;

    // =========================================================================
    // Display FIFO: bridges pl_clk to pclk domain for VGA output
    // Stores PIXEL_W=13-bit pixels; depth = 4096 to cover 2 lines of latency.
    //
    // IMPORTANT: This implementation uses a single synchronous FIFO clocked on
    // pclk for simplicity.  In the final hardware, pl_clk (150 MHz) and pclk
    // (148.5 MHz) are distinct clocks and this FIFO must be replaced with a
    // dual-clock async FIFO (e.g., ram_sdp_bram with separate rd/wr clocks).
    // For the demo/simulation, both clocks are tied to the same source.
    // =========================================================================
    localparam DISP_FIFO_D = 4096;

    wire              disp_wr_en   = s_pix_valid && cfg_start;
    wire              disp_rd_en;
    wire [PIXEL_W-1:0] disp_rd_data;
    wire              disp_rd_vld;
    wire              disp_empty;
    wire              disp_full;

    // fifo_async: wr_clk=clk (pl_clk 150MHz), rd_clk=pclk (148.5MHz)
    // fifo_async CDC: Gray pointers + 2-FF sync (pl_clk -> pclk); do not set_false_path
    fifo_async #(
        .DATA_W (PIXEL_W),
        .DEPTH  (DISP_FIFO_D),
        .ADDR_W ($clog2(DISP_FIFO_D))
    ) u_disp_fifo (
        .wr_clk      (clk),
        .wr_rst_n    (rst_n),
        .wr_en       (disp_wr_en),
        .wr_data     (s_pix_data),
        .full        (disp_full),
        .rd_clk      (pclk),
        .rd_rst_n    (pclk_rst_n),
        .rd_en       (disp_rd_en),
        .rd_data     (disp_rd_data),
        .rd_data_vld (disp_rd_vld),
        .empty       (disp_empty)
    );

    // Pop one pixel per active pixel clock during visible region
    assign disp_rd_en = vga_de && vga_active_w && !disp_empty;

    // Output pixel: valid FIFO data during active region, black otherwise
    assign vga_pixel  = (vga_active_w && disp_rd_vld) ?
                        disp_rd_data : {PIXEL_W{1'b0}};

endmodule

