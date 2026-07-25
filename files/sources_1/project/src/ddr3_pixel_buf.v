// =============================================================================
// ddr3_pixel_buf.v
// DDR Pixel Ping-Pong Buffer — AXI4 Master (HP1)
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// Purpose:
//   Decouples the PL processing pipeline from the display timing domain.
//   The CLAHE engine outputs pixels at the pipeline rate (up to 150 MHz);
//   the display controller reads at exactly the VGA pixel clock rate (148 MHz).
//   Without this buffer, any stall in either domain would corrupt the frame.
//
// Architecture:
//
//   ┌──────────────────────────────────────────────────────────────────────┐
//   │                        ddr3_pixel_buf                               │
//   │                                                                      │
//   │  Write path (CLAHE → DDR):                                          │
//   │    s_pix_data (13-bit) → pack 4px into 64-bit beat (PIXEL_W=13,    │
//   │    2 bytes/pixel, PIX_PER_BEAT=4) → write FIFO (32 × 64b BRAM)    │
//   │    → AXI4 INCR burst (BURST_LEN=16 beats = 64 pixels) → DDR page A│
//   │                                                                      │
//   │  Read path (DDR → display):                                         │
//   │    AXI4 read burst from DDR page B → read FIFO (32 × 64b BRAM)    │
//   │    → unpack 4px per beat → m_pix_data (13-bit) m_pix_valid         │
//   │                                                                      │
//   │  Ping-pong: wr_page toggles at frame boundary (when wr_ptr wraps).  │
//   │             Read path always reads the opposite page to the write.   │
//   │             This gives one-frame latency, acceptable for live video. │
//   └──────────────────────────────────────────────────────────────────────┘
//
// Packing convention (PIXEL_W=13, stored as 16-bit per pixel, 4 px/beat):
//   A 13-bit pixel is zero-extended to 16 bits before packing.
//   Beat layout (64-bit): { pix3[15:0], pix2[15:0], pix1[15:0], pix0[15:0] }
//   PIX_PER_BEAT = AXI_DW / 16 = 4  (fixed; independent of PIXEL_W to keep
//   integer arithmetic simple and avoid 64/13 non-integer truncation).
//
// Frame buffer layout in DDR (HP1):
//   Page 0: buf_base_addr + 0
//   Page 1: buf_base_addr + FB_BYTES
//   FB_BYTES = IMG_W * IMG_H * 2  (2 bytes per pixel, stored as uint16)
//
// AXI4 parameters:
//   Data width : 64-bit  (AXI_DW=64)
//   Burst type : INCR
//   Burst length: BURST_LEN beats (default 16)
//   Beat size  : 3'b011 (8 bytes per beat)
//
// Resources:
//   2 RAMB36 : write FIFO (fifo_sync, 32×64b) + read FIFO (fifo_sync, 32×64b)
//   ~2 DSP   : pack/unpack multipliers inferred by Vivado
// =============================================================================

`timescale 1ns / 1ps

module ddr3_pixel_buf #(
    parameter PIXEL_W    = 13,     // Internal pixel bit-width (Q0.13)
    parameter AXI_DW     = 64,     // AXI4 data bus width (HP1)
    parameter AXI_AW     = 32,     // AXI4 address bus width
    parameter BURST_LEN  = 16,     // AXI4 burst length (beats per transaction)
    parameter IMG_W      = 2048,   // Frame width in pixels
    parameter IMG_H      = 1080    // Frame height in lines
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // -------------------------------------------------------------------------
    // Input pixel stream — from clahe_engine (Q0.13, 1 px/clk)
    // No back-pressure: upstream pipeline is free-running.
    // -------------------------------------------------------------------------
    input  wire [PIXEL_W-1:0]    s_pix_data,
    input  wire                  s_pix_valid,

    // -------------------------------------------------------------------------
    // DDR base address — from AXI4-Lite config register (r_ddr3_base)
    // Both ping-pong pages are contiguous: page0 @ base, page1 @ base+FB_BYTES
    // -------------------------------------------------------------------------
    input  wire [AXI_AW-1:0]     buf_base_addr,

    // -------------------------------------------------------------------------
    // AXI4-HP1 write channel — driven by write FSM
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
    // AXI4-HP1 read channel — driven by read FSM
    // -------------------------------------------------------------------------
    output reg  [AXI_AW-1:0]     m_axi_araddr,
    output reg  [7:0]             m_axi_arlen,
    output reg  [2:0]             m_axi_arsize,
    output reg  [1:0]             m_axi_arburst,
    output reg                    m_axi_arvalid,
    input  wire                   m_axi_arready,
    input  wire [AXI_DW-1:0]     m_axi_rdata,
    input  wire [1:0]             m_axi_rresp,
    input  wire                   m_axi_rvalid,
    input  wire                   m_axi_rlast,
    output reg                    m_axi_rready,

    // -------------------------------------------------------------------------
    // Output pixel stream — to zynq_display_ctrl / optional ETH tap
    // rd_stall: when 1, freeze unpacker (no new m_pix_valid). Used by ETH skid
    // backpressure (PLAN_v3 scheme A minimal) so MIPI→DDR write can continue.
    // -------------------------------------------------------------------------
    input  wire                  rd_stall,
    output wire [PIXEL_W-1:0]    m_pix_data,
    output wire                  m_pix_valid,

    // -------------------------------------------------------------------------
    // Status outputs — optionally connect to AXI4-Lite status registers
    // -------------------------------------------------------------------------
    output reg                   wr_page,         // Current write page (0 or 1)
    output reg  [31:0]           wr_frame_cnt,    // Frames written to DDR
    output wire                  wr_fifo_full,    // Write FIFO full flag
    output wire                  rd_fifo_empty    // Read FIFO empty flag
);

    // =========================================================================
    // Constants
    // Pixels are stored as 16-bit words (uint16) regardless of PIXEL_W=13,
    // to keep the packing factor an exact integer (4 px per 64-bit beat).
    // FB_BYTES = IMG_W * IMG_H * 2 bytes per pixel.
    // =========================================================================
    localparam PIX_BYTES    = 2;                          // Storage bytes/pixel
    localparam PIX_PER_BEAT = AXI_DW / (PIX_BYTES * 8); // = 64/16 = 4
    localparam PACK_BITS    = 2;                          // log2(PIX_PER_BEAT)
    localparam FB_BYTES     = IMG_W * IMG_H * PIX_BYTES;  // 2048*1080*2 = 4,423,680

    // =========================================================================
    // Write packer: 4px → 64b beat → hold reg → FIFO
    // =========================================================================
    localparam WR_FIFO_D  = BURST_LEN * 2;              // 32 entries
    localparam WR_FIFO_AW = $clog2(WR_FIFO_D);          // 5 bits

    reg [PACK_BITS-1:0]  wr_pack_cnt;
    reg [AXI_DW-1:0]     wr_pack_reg;
    reg                   wr_hold_valid;
    reg [AXI_DW-1:0]     wr_hold;
    wire [WR_FIFO_AW:0]   wr_fifo_cnt;
    wire                  wr_fifo_empty;
    wire                  wr_fifo_rd_en;
    wire [AXI_DW-1:0]     wr_fifo_rdata;
    wire                  wr_fifo_rd_vld;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_pack_cnt   <= {PACK_BITS{1'b0}};
            wr_hold_valid <= 1'b0;
            wr_pack_reg   <= {AXI_DW{1'b0}};
        end else begin
            if (wr_hold_valid && !wr_fifo_full)
                wr_hold_valid <= 1'b0;

            if (s_pix_valid) begin
                if (wr_pack_cnt == PIX_PER_BEAT[PACK_BITS:0] - 1) begin
                    /* pix3 in [63:48], pix0..2 already in wr_pack_reg[47:0] */
                    wr_hold <= {{{(16-PIXEL_W){1'b0}}, s_pix_data}, wr_pack_reg[47:0]};
                    wr_hold_valid <= 1'b1;
                    wr_pack_cnt   <= {PACK_BITS{1'b0}};
                end else begin
                    wr_pack_reg[wr_pack_cnt * 16 +: 16] <= {{(16-PIXEL_W){1'b0}},
                                                             s_pix_data};
                    wr_pack_cnt <= wr_pack_cnt + 1'b1;
                end
            end
        end
    end

    wire               wr_fifo_wr_en  = wr_hold_valid && !wr_fifo_full;
    wire [AXI_DW-1:0]  wr_fifo_wdata  = wr_hold;

    fifo_sync #(
        .DATA_W (AXI_DW),
        .DEPTH  (WR_FIFO_D),
        .ADDR_W (WR_FIFO_AW),
        .DO_REG (0),
        .FWFT   (0)
    ) u_wr_fifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (wr_fifo_wr_en),
        .wr_data      (wr_fifo_wdata),
        .full         (wr_fifo_full),
        .almost_full  (),
        .rd_en        (wr_fifo_rd_en),
        .rd_data      (wr_fifo_rdata),
        .rd_data_vld  (wr_fifo_rd_vld),
        .empty        (wr_fifo_empty),
        .almost_empty (),
        .data_count   (wr_fifo_cnt)
    );

    // =========================================================================
    // Read FIFO: 32-entry × 64-bit (1 RAMB36, FWFT mode)
    // Receives AXI read data beats; unpacker reads from it.
    // =========================================================================
    localparam RD_FIFO_D  = BURST_LEN * 2;
    localparam RD_FIFO_AW = $clog2(RD_FIFO_D);

    wire               rd_fifo_wr_en  = m_axi_rvalid && m_axi_rready;
    wire [AXI_DW-1:0]  rd_fifo_wdata  = m_axi_rdata;
    wire               rd_fifo_rd_en;
    wire [AXI_DW-1:0]  rd_fifo_rdata;
    wire               rd_fifo_rd_vld;
    wire               rd_fifo_full;
    wire [RD_FIFO_AW:0] rd_fifo_cnt;

    fifo_sync #(
        .DATA_W (AXI_DW),
        .DEPTH  (RD_FIFO_D),
        .ADDR_W (RD_FIFO_AW),
        .DO_REG (0),
        .FWFT   (1)           // First-word-fall-through for low-latency output
    ) u_rd_fifo (
        .clk          (clk),
        .rst_n        (rst_n),
        .wr_en        (rd_fifo_wr_en),
        .wr_data      (rd_fifo_wdata),
        .full         (rd_fifo_full),
        .almost_full  (),
        .rd_en        (rd_fifo_rd_en),
        .rd_data      (rd_fifo_rdata),
        .rd_data_vld  (rd_fifo_rd_vld),
        .empty        (rd_fifo_empty),
        .almost_empty (),
        .data_count   (rd_fifo_cnt)
    );

    // =========================================================================
    // Read unpacker: extract PIX_PER_BEAT=4 pixels from each 64-bit beat
    // Each pixel is the lower PIXEL_W bits of a 16-bit slot.
    // N11: only accept a new beat on a real pop (rd_en→rd_vld). Never reload
    // from a sticky FWFT vld without consuming — that replayed 1 beat forever.
    // =========================================================================
    reg                   rd_beat_valid;
    reg [AXI_DW-1:0]     rd_beat_buf;

    reg [PACK_BITS-1:0] out_idx;
    reg                 beat_loaded;
    reg                 rd_pending; /* rd_en issued, waiting DO_REG=0 vld */

    assign rd_fifo_rd_en = !rd_fifo_empty && !beat_loaded && !rd_stall && !rd_pending;

    always @(posedge clk) begin
        if (!rst_n) begin
            out_idx       <= {PACK_BITS{1'b0}};
            rd_beat_valid <= 1'b0;
            beat_loaded   <= 1'b0;
            rd_pending    <= 1'b0;
            rd_beat_buf   <= {AXI_DW{1'b0}};
        end else begin
            rd_beat_valid <= 1'b0;
            if (rd_fifo_rd_en)
                rd_pending <= 1'b1;

            if (rd_stall) begin
                /* freeze: keep beat_loaded/out_idx/pending, no valid */
            end else if (beat_loaded) begin
                rd_beat_valid <= 1'b1;
                if (out_idx == PIX_PER_BEAT[PACK_BITS:0] - 1) begin
                    out_idx     <= {PACK_BITS{1'b0}};
                    beat_loaded <= 1'b0;
                end else begin
                    out_idx <= out_idx + 1'b1;
                end
            end else if (rd_fifo_rd_vld) begin
                rd_beat_buf <= rd_fifo_rdata;
                out_idx     <= {PACK_BITS{1'b0}};
                beat_loaded <= 1'b1;
                rd_pending  <= 1'b0;
            end
        end
    end

    assign m_pix_data  = rd_beat_buf[out_idx * 16 +: PIXEL_W];
    assign m_pix_valid = rd_beat_valid;

    // =========================================================================
    // AXI4 Write FSM — WS_IDLE → WS_ADDR → WS_DATA → WS_RESP
    // Fires a burst of BURST_LEN beats when the write FIFO holds enough data.
    // =========================================================================
    localparam WS_IDLE = 2'd0;
    localparam WS_ADDR = 2'd1;
    localparam WS_DATA = 2'd2;
    localparam WS_RESP = 2'd3;

    reg [1:0]          ws_state;
    reg [AXI_AW-1:0]   wr_ptr;     // Byte pointer within current DDR page
    reg [7:0]           wr_beat;   // Beat counter within current burst
    reg                 wr_fifo_pop;

    assign wr_fifo_rd_en = wr_fifo_pop;

    // Fire condition: enough beats in FIFO for a full burst
    wire wr_fire = (wr_fifo_cnt >= BURST_LEN[WR_FIFO_AW:0]);

    always @(posedge clk) begin
        if (!rst_n) begin
            ws_state       <= WS_IDLE;
            m_axi_awvalid  <= 1'b0;
            m_axi_wvalid   <= 1'b0;
            m_axi_bready   <= 1'b1;
            m_axi_awsize   <= 3'b011;               // 8 bytes per beat
            m_axi_awburst  <= 2'b01;                // INCR burst type
            m_axi_awlen    <= BURST_LEN[7:0] - 1;   // Burst length (beats-1)
            m_axi_wstrb    <= {(AXI_DW/8){1'b1}};   // All byte-enables active
            wr_ptr         <= {AXI_AW{1'b0}};
            wr_beat        <= 8'd0;
            wr_page        <= 1'b0;
            wr_frame_cnt   <= 32'd0;
            wr_fifo_pop    <= 1'b0;
        end else begin
            wr_fifo_pop <= 1'b0;

            case (ws_state)

                // Wait for enough data in the write FIFO, then start a burst.
                WS_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    if (wr_fire) begin
                        // Write address = page base + byte pointer
                        m_axi_awaddr <= buf_base_addr
                                      + (wr_page ? FB_BYTES[AXI_AW-1:0] : 0)
                                      + wr_ptr;
                        ws_state <= WS_ADDR;
                    end
                end

                // Issue AW transaction; wait for AWREADY handshake.
                WS_ADDR: begin
                    m_axi_awvalid <= 1'b1;
                    if (m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        wr_beat       <= 8'd0;
                        wr_fifo_pop   <= 1'b1;   // Pre-fetch first beat
                        ws_state      <= WS_DATA;
                    end
                end

                // Stream BURST_LEN beats; latch beat until WREADY (don't depend on 1-cycle rd_vld).
                WS_DATA: begin
                    if (wr_fifo_rd_vld && !m_axi_wvalid) begin
                        m_axi_wdata  <= wr_fifo_rdata;
                        m_axi_wvalid <= 1'b1;
                        m_axi_wlast  <= (wr_beat == BURST_LEN[7:0] - 1);
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        wr_beat      <= wr_beat + 1;
                        wr_ptr       <= wr_ptr + (AXI_DW/8);
                        if (wr_beat < BURST_LEN[7:0] - 1) begin
                            wr_fifo_pop <= 1'b1;
                        end else begin
                            ws_state <= WS_RESP;
                            if (wr_ptr + (AXI_DW/8) >= FB_BYTES[AXI_AW-1:0]) begin
                                wr_ptr       <= {AXI_AW{1'b0}};
                                wr_page      <= !wr_page;
                                wr_frame_cnt <= wr_frame_cnt + 1;
                            end
                        end
                    end
                end

                // Wait for write response (B channel); ignore BRESP for demo.
                WS_RESP: begin
                    m_axi_bready <= 1'b1;
                    if (m_axi_bvalid) begin
                        m_axi_bready <= 1'b0;
                        ws_state     <= WS_IDLE;
                    end
                end

                default: ws_state <= WS_IDLE;
            endcase
        end
    end

    // =========================================================================
    // AXI4 Read FSM — RS_IDLE → RS_ADDR → RS_DATA
    // Prefetches a burst from the DDR read page whenever the read FIFO is low.
    // The read page is always the opposite of wr_page to avoid tearing.
    // =========================================================================
    localparam RS_IDLE = 2'd0;
    localparam RS_ADDR = 2'd1;
    localparam RS_DATA = 2'd2;

    reg [1:0]          rs_state;
    reg [AXI_AW-1:0]   rd_ptr;    // Byte pointer within current DDR read page

    // Prefetch trigger: read FIFO below half-full and not currently fetching
    wire rd_fire = (rd_fifo_cnt < RD_FIFO_D[RD_FIFO_AW:0] / 2)
                && !rd_fifo_full
                && (rs_state == RS_IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            rs_state      <= RS_IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_arsize  <= 3'b011;               // 8 bytes per beat
            m_axi_arburst <= 2'b01;                // INCR
            m_axi_arlen   <= BURST_LEN[7:0] - 1;
            m_axi_rready  <= 1'b0;
            rd_ptr        <= {AXI_AW{1'b0}};
        end else begin
            case (rs_state)

                // Issue read address when prefetch is needed.
                // Read from the page that write is NOT currently writing to.
                RS_IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    if (rd_fire) begin
                        m_axi_araddr <= buf_base_addr
                                      + (wr_page ? 0 : FB_BYTES[AXI_AW-1:0])
                                      + rd_ptr;
                        rs_state <= RS_ADDR;
                    end
                end

                // Issue AR transaction; wait for ARREADY handshake.
                RS_ADDR: begin
                    m_axi_arvalid <= 1'b1;
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        m_axi_rready  <= 1'b1;
                        rs_state      <= RS_DATA;
                    end
                end

                // Accept R channel beats into the read FIFO via rd_fifo_wr_en.
                RS_DATA: begin
                    if (m_axi_rvalid) begin
                        rd_ptr <= rd_ptr + (AXI_DW/8);
                        if (m_axi_rlast) begin   // rlast from PS
                            m_axi_rready <= 1'b0;
                            rs_state     <= RS_IDLE;
                            // Wrap read pointer at frame boundary
                            if (rd_ptr + (AXI_DW/8) >= FB_BYTES[AXI_AW-1:0])
                                rd_ptr <= {AXI_AW{1'b0}};
                        end
                    end
                end

                default: rs_state <= RS_IDLE;
            endcase
        end
    end

endmodule
