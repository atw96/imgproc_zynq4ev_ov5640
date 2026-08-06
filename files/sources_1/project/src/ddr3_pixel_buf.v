// =============================================================================
// ddr3_pixel_buf.v
// DDR Pixel Ping-Pong Buffer — AXI4 Master (HP1)
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// N12: RGBX 4 bytes/pixel (PIX_PER_BEAT=2). Storage little-endian:
//   byte0=R, byte1=G, byte2=B, byte3=0  → Verilog word {8'h00,b8,g8,r8}
// N11i: burst write with first AW+W overlap (SmartConnect requirement).
// N11k→N12: remove rd_starving write gate (AXI-R deadlocked writes on this board).
// N16/N16d: crop each input line to IMG_W (drop trailing px; expose measured_line_px).
// N16c GAP_EOL blank detect FAIL on board (bestW still ~1988). N16d: fixed DROP_EXTRA
// valid-count after each IMG_W + SOF resync (no H-blank assumption).
// N23: deepen wr FIFO (block RAM), AXI write outstanding (no WS_RESP stall),
//      crop to IMG_H rows, wr_drop_cnt + prog_full for MIPI backpressure.
// =============================================================================

`timescale 1ns / 1ps

module ddr3_pixel_buf #(
    parameter PIXEL_W    = 13,     // kept for FORCE_RAMP / compat (unused on RGB ports)
    parameter AXI_DW     = 64,
    parameter AXI_AW     = 32,
    parameter BURST_LEN  = 16,
    parameter IMG_W      = 2048,
    parameter IMG_H      = 1080,
    /* N16d: ISP/bilat emits ~IMG_W+DROP_EXTRA valids/line (measured ≈1988 → 68).
     * N16e: CROP_EN=0 + LINE_STRIDE_PX=1988 — keep raw stride in DDR; PS crops.
     * (N16c/d blank/fixed-drop crop failed on board; FW crop already PASS.) */
    parameter LINE_STRIDE_PX = 1988,
    parameter DROP_EXTRA = 68,
    parameter CROP_EN    = 0,
    parameter FORCE_RAMP_OUT = 0,
    /* N12: 1 = disable AXI-R (2B PS-read path; avoid HP1 R/W contention) */
    parameter DISABLE_AXI_R  = 1,
    /* N23: write FIFO depth in AXI beats (2 px/beat); absorb BRESP latency */
    parameter WR_FIFO_DEPTH  = 2048,
    parameter MAX_OUTSTANDING = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,

    // Input RGB888 stream (from bilat / clahe gray replicated)
    input  wire [7:0]            s_pix_r,
    input  wire [7:0]            s_pix_g,
    input  wire [7:0]            s_pix_b,
    input  wire                  s_pix_valid,
    input  wire                  s_pix_sof,
    /* N20: line-start pulse (same cycle as first valid of line) for hsync crop */
    input  wire                  s_pix_hsync,

    input  wire [AXI_AW-1:0]     buf_base_addr,

    // AXI4-HP1 write
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

    // AXI4-HP1 read
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

    input  wire                  rd_stall,
    output wire [7:0]            m_pix_r,
    output wire [7:0]            m_pix_g,
    output wire [7:0]            m_pix_b,
    output wire                  m_pix_valid,

    output reg                   wr_page,
    output reg  [31:0]           wr_frame_cnt,
    output wire                  wr_fifo_full,
    /* N23: early almost-full for upstream MIPI / ISP backpressure */
    output wire                  wr_fifo_prog_full,
    output wire                  rd_fifo_empty,
    /* diag: {b_hs[7:0], w_hs[7:0], ar_hs[7:0], r_hs[7:0]} */
    output reg  [31:0]           axi_diag_cnt,
    /* N16: last completed input line length (valid pulses before crop) */
    output reg  [15:0]           measured_line_px,
    /* N23: pixels dropped because packer could not accept (FIFO full) */
    output reg  [31:0]           wr_drop_cnt
);

    localparam PIX_BYTES    = 4;
    localparam PIX_PER_BEAT = AXI_DW / (PIX_BYTES * 8); // = 2
    localparam PACK_BITS    = 1;
    /* N16e: page holds full measured stride × H (PS crops to IMG_W) */
    localparam FB_BYTES     = LINE_STRIDE_PX * IMG_H * PIX_BYTES;

    localparam WR_FIFO_D  = WR_FIFO_DEPTH;
    localparam WR_FIFO_AW = $clog2(WR_FIFO_D);
    /* leave ~256 beats headroom for pipeline drain after stall asserts */
    localparam WR_PROG_FULL_THRESH = (WR_FIFO_D > 256) ? (WR_FIFO_D - 256) : (WR_FIFO_D - 5);

    // ---- N20/N23: hsync-aligned CAP IMG_W, DROP rest; crop to IMG_H rows ----
    /* N16d DROP_EXTRA counter (no hsync) falsely reported measured_line_px=IMG_W
     * while still writing extras when CROP_EN=0. N20 gates on line starts.
     * N23: wr_row drops lines >= IMG_H so frame == FB_BYTES exactly. */
    localparam ST_CAP  = 1'b0;
    localparam ST_DROP = 1'b1;
    reg        line_st;
    reg [15:0] wr_col;
    reg [15:0] line_px_cnt;
    reg [15:0] wr_row;

    wire line_start = s_pix_valid && (s_pix_sof || s_pix_hsync);
    /* Combinational row check so SOF line is accepted in the same cycle */
    wire row_ok = line_start ? (s_pix_sof || ((wr_row + 16'd1) < IMG_H[15:0]))
                             : (wr_row < IMG_H[15:0]);

    always @(posedge clk) begin
        if (!rst_n) begin
            line_st          <= ST_CAP;
            wr_col           <= 16'd0;
            line_px_cnt      <= 16'd0;
            measured_line_px <= 16'd0;
            wr_row           <= 16'd0;
        end else if (FORCE_RAMP_OUT) begin
            line_st          <= ST_CAP;
            wr_col           <= 16'd0;
            line_px_cnt      <= 16'd0;
            measured_line_px <= IMG_W[15:0];
            wr_row           <= 16'd0;
        end else if (line_start) begin
            /* New line: publish previous length; accept this pixel as col0 */
            if (line_px_cnt != 16'd0)
                measured_line_px <= line_px_cnt;
            if (s_pix_sof)
                wr_row <= 16'd0;
            else
                wr_row <= wr_row + 16'd1;
            line_st     <= ST_CAP;
            wr_col      <= 16'd1;
            line_px_cnt <= 16'd1;
        end else if (s_pix_valid) begin
            line_px_cnt <= line_px_cnt + 16'd1;
            if (line_st == ST_CAP) begin
                if (wr_col < IMG_W[15:0]) begin
                    wr_col <= wr_col + 16'd1;
                    if (wr_col == (IMG_W[15:0] - 16'd1))
                        line_st <= ST_DROP;
                end
            end
            /* ST_DROP: wait for next line_start (hsync/sof) */
        end
    end

    // ---- write packer: 2×RGBX → 64b beat ----
    reg [7:0]  wr_ramp;
    wire [7:0] wr_r = FORCE_RAMP_OUT ? wr_ramp : s_pix_r;
    wire [7:0] wr_g = FORCE_RAMP_OUT ? wr_ramp : s_pix_g;
    wire [7:0] wr_b = FORCE_RAMP_OUT ? wr_ramp : s_pix_b;
    /* Gate: CAP first IMG_W of each hsync line and only first IMG_H rows */
    wire       wr_pix_valid = FORCE_RAMP_OUT ? 1'b1
                            : (!CROP_EN) ? (s_pix_valid && row_ok)
                            : (s_pix_valid && row_ok && (line_start
                                || ((line_st == ST_CAP) && (wr_col < IMG_W[15:0]))));
    /* little-endian RGBX word: {X,B,G,R} */
    wire [31:0] wr_pix32 = {8'h00, wr_b, wr_g, wr_r};

    always @(posedge clk) begin
        if (!rst_n)
            wr_ramp <= 8'd0;
        else if (FORCE_RAMP_OUT)
            wr_ramp <= wr_ramp + 8'd1;
    end

    reg [PACK_BITS-1:0]  wr_pack_cnt;
    reg [31:0]           wr_pack_lo;
    reg                   wr_hold_valid;
    reg [AXI_DW-1:0]     wr_hold;
    wire [WR_FIFO_AW:0]   wr_fifo_cnt;
    wire                  wr_fifo_empty;
    wire                  wr_fifo_rd_en;
    wire [AXI_DW-1:0]     wr_fifo_rdata;

    wire packer_blocked = wr_hold_valid && wr_fifo_full;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_pack_cnt   <= {PACK_BITS{1'b0}};
            wr_hold_valid <= 1'b0;
            wr_pack_lo    <= 32'd0;
            wr_drop_cnt   <= 32'd0;
        end else begin
            if (wr_hold_valid && !wr_fifo_full)
                wr_hold_valid <= 1'b0;

            if (wr_pix_valid && packer_blocked) begin
                /* N23: count silent drops (should be 0 after outstanding+deep FIFO) */
                wr_drop_cnt <= wr_drop_cnt + 32'd1;
            end else if (wr_pix_valid && !packer_blocked) begin
                if (wr_pack_cnt == PIX_PER_BEAT[PACK_BITS:0] - 1) begin
                    wr_hold       <= {wr_pix32, wr_pack_lo};
                    wr_hold_valid <= 1'b1;
                    wr_pack_cnt   <= {PACK_BITS{1'b0}};
                end else begin
                    wr_pack_lo  <= wr_pix32;
                    wr_pack_cnt <= wr_pack_cnt + 1'b1;
                end
            end
        end
    end

    wire               wr_fifo_wr_en  = wr_hold_valid && !wr_fifo_full;
    wire [AXI_DW-1:0]  wr_fifo_wdata  = wr_hold;

    /* N23: "0406" = prog_full + wr_data_count + rd_data_count */
    xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("block"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (WR_FIFO_D),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (5),
        .PROG_FULL_THRESH    (WR_PROG_FULL_THRESH),
        .RD_DATA_COUNT_WIDTH (WR_FIFO_AW + 1),
        .READ_DATA_WIDTH     (AXI_DW),
        .READ_MODE           ("fwft"),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0406"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (AXI_DW),
        .WR_DATA_COUNT_WIDTH (WR_FIFO_AW + 1)
    ) u_wr_fifo (
        .rst           (~rst_n),
        .wr_clk        (clk),
        .wr_en         (wr_fifo_wr_en),
        .din           (wr_fifo_wdata),
        .full          (wr_fifo_full),
        .wr_rst_busy   (),
        .rd_en         (wr_fifo_rd_en),
        .dout          (wr_fifo_rdata),
        .empty         (wr_fifo_empty),
        .rd_rst_busy   (),
        .wr_data_count (wr_fifo_cnt),
        .rd_data_count (),
        .prog_full     (wr_fifo_prog_full),
        .prog_empty    (),
        .data_valid    (),
        .overflow      (),
        .underflow     (),
        .almost_full   (),
        .almost_empty  (),
        .injectsbiterr (1'b0),
        .injectdbiterr (1'b0),
        .sbiterr       (),
        .dbiterr       (),
        .sleep         (1'b0)
    );

    // ---- read FIFO + unpacker ----
    localparam RD_FIFO_D  = BURST_LEN * 2;
    localparam RD_FIFO_AW = $clog2(RD_FIFO_D);

    wire               rd_fifo_wr_en  = m_axi_rvalid && m_axi_rready;
    wire               rd_fifo_rd_en;
    wire [AXI_DW-1:0]  rd_fifo_dout;
    wire               rd_fifo_full;
    wire [RD_FIFO_AW:0] rd_fifo_cnt;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("block"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (RD_FIFO_D),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (5),
        .PROG_FULL_THRESH    (RD_FIFO_D - 4),
        .RD_DATA_COUNT_WIDTH (RD_FIFO_AW + 1),
        .READ_DATA_WIDTH     (AXI_DW),
        .READ_MODE           ("fwft"),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0404"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (AXI_DW),
        .WR_DATA_COUNT_WIDTH (RD_FIFO_AW + 1)
    ) u_rd_fifo (
        .rst           (~rst_n),
        .wr_clk        (clk),
        .wr_en         (rd_fifo_wr_en),
        .din           (m_axi_rdata),
        .full          (rd_fifo_full),
        .wr_rst_busy   (),
        .rd_en         (rd_fifo_rd_en),
        .dout          (rd_fifo_dout),
        .empty         (rd_fifo_empty),
        .rd_rst_busy   (),
        .wr_data_count (rd_fifo_cnt),
        .rd_data_count (),
        .prog_full     (),
        .prog_empty    (),
        .data_valid    (),
        .overflow      (),
        .underflow     (),
        .almost_full   (),
        .almost_empty  (),
        .injectsbiterr (1'b0),
        .injectdbiterr (1'b0),
        .sbiterr       (),
        .dbiterr       (),
        .sleep         (1'b0)
    );

    reg                   rd_beat_valid;
    reg [AXI_DW-1:0]     rd_beat_buf;
    reg [PACK_BITS-1:0]  out_idx;
    reg                  beat_loaded;

    assign rd_fifo_rd_en = !rd_fifo_empty && !beat_loaded && !rd_stall;

    always @(posedge clk) begin
        if (!rst_n) begin
            out_idx       <= {PACK_BITS{1'b0}};
            rd_beat_valid <= 1'b0;
            beat_loaded   <= 1'b0;
            rd_beat_buf   <= {AXI_DW{1'b0}};
        end else begin
            rd_beat_valid <= 1'b0;
            if (rd_stall) begin
                /* freeze */
            end else if (beat_loaded) begin
                rd_beat_valid <= 1'b1;
                if (out_idx == PIX_PER_BEAT[PACK_BITS:0] - 1) begin
                    out_idx     <= {PACK_BITS{1'b0}};
                    beat_loaded <= 1'b0;
                end else begin
                    out_idx <= out_idx + 1'b1;
                end
            end else if (rd_fifo_rd_en) begin
                rd_beat_buf <= rd_fifo_dout;
                out_idx     <= {PACK_BITS{1'b0}};
                beat_loaded <= 1'b1;
            end
        end
    end

    reg [7:0] ramp_pix;
    reg       ramp_valid;
    always @(posedge clk) begin
        if (!rst_n) begin
            ramp_pix   <= 8'd0;
            ramp_valid <= 1'b0;
        end else if (FORCE_RAMP_OUT) begin
            ramp_valid <= !rd_stall;
            if (!rd_stall)
                ramp_pix <= ramp_pix + 8'd1;
        end else begin
            ramp_valid <= 1'b0;
        end
    end

    wire [31:0] rd_pix32 = rd_beat_buf[out_idx * 32 +: 32];
    assign m_pix_r     = FORCE_RAMP_OUT ? ramp_pix : rd_pix32[7:0];
    assign m_pix_g     = FORCE_RAMP_OUT ? ramp_pix : rd_pix32[15:8];
    assign m_pix_b     = FORCE_RAMP_OUT ? ramp_pix : rd_pix32[23:16];
    assign m_pix_valid = FORCE_RAMP_OUT ? ramp_valid : rd_beat_valid;

    // ---- AXI write FSM (N11i AW+W overlap; N23 outstanding, no WS_RESP stall) ----
    localparam WS_IDLE = 2'd0;
    localparam WS_ADDR = 2'd1;
    localparam WS_DATA = 2'd2;

    reg [1:0]          ws_state;
    reg [AXI_AW-1:0]   wr_ptr;
    reg [7:0]           wr_beat;
    reg [3:0]           outstanding_cnt;

    wire aw_hs = m_axi_awvalid && m_axi_awready;
    wire b_hs  = m_axi_bvalid && m_axi_bready;

    /* N12: never gate writes on read FIFO — N11k interlock deadlocked when AXI-R fails
     * N23: allow up to MAX_OUTSTANDING bursts in flight (do not wait for B in FSM) */
    wire wr_fire = (wr_fifo_cnt >= BURST_LEN[WR_FIFO_AW:0])
                && (outstanding_cnt < MAX_OUTSTANDING[3:0]);

    assign wr_fifo_rd_en = m_axi_wvalid && m_axi_wready &&
                           ((ws_state == WS_ADDR) || (ws_state == WS_DATA));

    always @(posedge clk) begin
        if (!rst_n) begin
            ws_state         <= WS_IDLE;
            m_axi_awvalid    <= 1'b0;
            m_axi_wvalid     <= 1'b0;
            m_axi_bready     <= 1'b1;
            m_axi_awsize     <= 3'b011;
            m_axi_awburst    <= 2'b01;
            m_axi_awlen      <= BURST_LEN[7:0] - 1;
            m_axi_wstrb      <= {(AXI_DW/8){1'b1}};
            wr_ptr           <= {AXI_AW{1'b0}};
            wr_beat          <= 8'd0;
            wr_page          <= 1'b0;
            wr_frame_cnt     <= 32'd0;
            axi_diag_cnt     <= 32'd0;
            outstanding_cnt  <= 4'd0;
        end else begin
            m_axi_bready <= 1'b1;

            /* N23b: safe SOF realign — only when write path fully idle.
             * Fixes FB circular phase after dbg_src switch / boot bilat junk.
             * N19b forbade unconditional SOF realign (raced AXI drain). */
            if (s_pix_valid && s_pix_sof &&
                (ws_state == WS_IDLE) &&
                (outstanding_cnt == 4'd0) &&
                wr_fifo_empty && !wr_hold_valid) begin
                wr_ptr <= {AXI_AW{1'b0}};
            end

            /* Independent B-channel retire + AW issue tracking */
            case ({aw_hs, b_hs})
                2'b10: outstanding_cnt <= outstanding_cnt + 4'd1;
                2'b01: outstanding_cnt <= outstanding_cnt - 4'd1;
                default: ; /* 2'b11 cancels; 2'b00 hold */
            endcase
            if (b_hs) begin
                if (axi_diag_cnt[31:24] != 8'hFF)
                    axi_diag_cnt[31:24] <= axi_diag_cnt[31:24] + 8'd1;
            end

            /* N19b: do NOT SOF-realign wr_ptr — races AXI drain and truncates
             * frames (black_rows / skew). Page flip only on FB_BYTES fill.
             * Requires gated line length == LINE_STRIDE_PX so frame == FB. */

            case (ws_state)
                WS_IDLE: begin
                    m_axi_awvalid <= 1'b0;
                    m_axi_wvalid  <= 1'b0;
                    if (wr_fire && !wr_fifo_empty) begin
                        m_axi_awaddr  <= buf_base_addr
                                       + (wr_page ? FB_BYTES[AXI_AW-1:0] : 0)
                                       + wr_ptr;
                        m_axi_wdata   <= wr_fifo_rdata;
                        m_axi_wlast   <= (BURST_LEN == 1);
                        m_axi_awvalid <= 1'b1;
                        m_axi_wvalid  <= 1'b1;
                        wr_beat       <= 8'd0;
                        ws_state      <= WS_ADDR;
                    end
                end

                WS_ADDR: begin
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        if (axi_diag_cnt[23:16] != 8'hFF)
                            axi_diag_cnt[23:16] <= axi_diag_cnt[23:16] + 8'd1;
                        wr_ptr  <= wr_ptr + (AXI_DW/8);
                        wr_beat <= 8'd1;
                    end
                    if (!m_axi_awvalid && !m_axi_wvalid) begin
                        if (BURST_LEN == 1) begin
                            /* N23: do not wait for BRESP — return to IDLE */
                            ws_state <= WS_IDLE;
                            if (wr_ptr >= FB_BYTES[AXI_AW-1:0]) begin
                                wr_ptr       <= {AXI_AW{1'b0}};
                                wr_page      <= !wr_page;
                                wr_frame_cnt <= wr_frame_cnt + 1;
                            end
                        end else
                            ws_state <= WS_DATA;
                    end
                end

                WS_DATA: begin
                    if (!m_axi_wvalid && !wr_fifo_empty) begin
                        m_axi_wdata  <= wr_fifo_rdata;
                        m_axi_wvalid <= 1'b1;
                        m_axi_wlast  <= (wr_beat == BURST_LEN[7:0] - 1);
                    end
                    if (m_axi_wvalid && m_axi_wready) begin
                        if (axi_diag_cnt[23:16] != 8'hFF)
                            axi_diag_cnt[23:16] <= axi_diag_cnt[23:16] + 8'd1;
                        m_axi_wvalid <= 1'b0;
                        wr_ptr       <= wr_ptr + (AXI_DW/8);
                        if (wr_beat < BURST_LEN[7:0] - 1) begin
                            wr_beat <= wr_beat + 8'd1;
                        end else begin
                            /* N23: burst done — immediately allow next AW */
                            ws_state <= WS_IDLE;
                            if (wr_ptr + (AXI_DW/8) >= FB_BYTES[AXI_AW-1:0]) begin
                                wr_ptr       <= {AXI_AW{1'b0}};
                                wr_page      <= !wr_page;
                                wr_frame_cnt <= wr_frame_cnt + 1;
                            end
                        end
                    end
                end

                default: ws_state <= WS_IDLE;
            endcase
        end
    end

    // ---- AXI read FSM (optional; DISABLE_AXI_R=1 for 2B) ----
    localparam RS_IDLE = 2'd0;
    localparam RS_ADDR = 2'd1;
    localparam RS_DATA = 2'd2;

    reg [1:0]          rs_state;
    reg [AXI_AW-1:0]   rd_ptr;

    wire rd_fire = !FORCE_RAMP_OUT && !DISABLE_AXI_R
                && (rd_fifo_cnt < RD_FIFO_D[RD_FIFO_AW:0] / 2)
                && !rd_fifo_full
                && (rs_state == RS_IDLE);

    always @(posedge clk) begin
        if (!rst_n) begin
            rs_state      <= RS_IDLE;
            m_axi_arvalid <= 1'b0;
            m_axi_arsize  <= 3'b011;
            m_axi_arburst <= 2'b01;
            m_axi_arlen   <= BURST_LEN[7:0] - 1;
            m_axi_rready  <= 1'b0;
            rd_ptr        <= {AXI_AW{1'b0}};
        end else begin
            case (rs_state)
                RS_IDLE: begin
                    m_axi_arvalid <= 1'b0;
                    if (rd_fire) begin
                        m_axi_araddr <= buf_base_addr
                                      + (wr_page ? 0 : FB_BYTES[AXI_AW-1:0])
                                      + rd_ptr;
                        rs_state <= RS_ADDR;
                    end
                end

                RS_ADDR: begin
                    m_axi_arvalid <= 1'b1;
                    if (m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        if (axi_diag_cnt[15:8] != 8'hFF)
                            axi_diag_cnt[15:8] <= axi_diag_cnt[15:8] + 8'd1;
                        m_axi_rready  <= 1'b1;
                        rs_state      <= RS_DATA;
                    end
                end

                RS_DATA: begin
                    m_axi_rready <= !rd_fifo_full;
                    if (m_axi_rvalid && m_axi_rready) begin
                        if (axi_diag_cnt[7:0] != 8'hFF)
                            axi_diag_cnt[7:0] <= axi_diag_cnt[7:0] + 8'd1;
                        rd_ptr <= rd_ptr + (AXI_DW/8);
                        if (m_axi_rlast) begin
                            m_axi_rready <= 1'b0;
                            rs_state     <= RS_IDLE;
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
