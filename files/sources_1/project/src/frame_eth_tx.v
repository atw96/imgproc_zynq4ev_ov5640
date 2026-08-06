// frame_eth_tx.v — ISP RGB → AXI-Stream for PS AXI DMA S2MM
// Header 12B (3×32-bit beats, TKEEP=F) + RGBX payload
// n7r: xpm BRAM skid + prog_full → pause pattern (pat_raw_ready) so phase
//      cannot drift from silent overflow; clear ovf count each accepted SOF.

`timescale 1ns/1ps

module frame_eth_tx #(
    parameter PIXEL_W  = 13,
    parameter IMG_W    = 1920,
    parameter IMG_H    = 1080,
    parameter AXIS_DW  = 32,
    parameter FORMAT   = 8'd1,
    // 1: ignore s_pix_* and emit locked ramp from accept_sof (N8 path check)
    parameter FORCE_ETH_RAMP = 0
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [PIXEL_W-1:0] s_pix_r,
    input  wire [PIXEL_W-1:0] s_pix_g,
    input  wire [PIXEL_W-1:0] s_pix_b,
    input  wire               s_pix_valid,
    input  wire               s_pix_sof,

    output reg  [AXIS_DW-1:0] m_axis_tdata,
    output reg                m_axis_tvalid,
    input  wire               m_axis_tready,
    output reg                m_axis_tlast,
    output reg  [3:0]         m_axis_tkeep,

    input  wire [3:0]         frame_skip,
    input  wire               capture_en,
    output reg [15:0]         tx_frame_cnt,
    output reg [15:0]         skid_ovf_cnt,
    // When high, top should deassert pat_raw_ready (Bit A backpressure)
    output wire               pause_src
);

    localparam TOTAL_PIX = IMG_W * IMG_H;
    localparam HDR_WORDS = 2'd3;
    localparam [15:0] W16 = IMG_W;
    localparam [15:0] H16 = IMG_H;
    localparam [7:0]  FMT8 = FORMAT;

    localparam S_IDLE      = 3'd0;
    localparam S_HEADER    = 3'd1;
    localparam S_PAYLOAD   = 3'd2;
    localparam S_DONE      = 3'd3;
    localparam S_FLUSH_BAD = 3'd4; /* PLAN_v3 §2.2: ovf → pad zeros + TLAST, drop frame */

    localparam GAP_CYCLES = 22'd3000000;
    localparam SKID_DEPTH = 8192;
    localparam PROG_FULL_TH = 6144; // pause src when >3/4 full

    reg [2:0]  state;
    reg [1:0]  hdr_cnt;
    reg [20:0] pix_cnt;
    reg [3:0]  skip_cnt;
    reg [21:0] gap_cnt;
    reg [20:0] in_pix_idx;

    /* N12: use [12:5] (MSBs) — matches HDMI; [11:4] halved range + wrap on bright */
    wire [7:0] r8 = s_pix_r[12:5];
    wire [7:0] g8 = s_pix_g[12:5];
    wire [7:0] b8 = s_pix_b[12:5];

    wire frame_start = s_pix_valid && s_pix_sof;
    wire axis_fire   = m_axis_tvalid && m_axis_tready;
    wire axis_ready  = !m_axis_tvalid || m_axis_tready;

    wire        skid_empty;
    wire        skid_full;
    wire        skid_prog_full;
    wire [23:0] skid_dout;
    wire        skid_wr_rst_busy;
    wire        skid_rd_rst_busy;
    wire skid_rst = (!rst_n) || ((state == S_DONE) && (gap_cnt < 22'd32)) ||
                    (state == S_FLUSH_BAD);
    wire skid_rdy = !skid_wr_rst_busy && !skid_rd_rst_busy;

    wire accept_sof = (state == S_IDLE) && frame_start && (skip_cnt == frame_skip) &&
                      capture_en && m_axis_tready && skid_empty && skid_rdy;
    /* N10b: do NOT skid during HEADER — 3 header beats @ AXIS let MIPI fill 8192 and
     * force FLUSH every frame. Buffer only on SOF accept + PAYLOAD. */
    wire capturing  = (state == S_PAYLOAD) || accept_sof;
    assign pause_src = capturing && skid_prog_full;

    wire [20:0] ramp_idx = accept_sof ? 21'd0 : in_pix_idx;
    wire [10:0] ramp_col = ramp_idx % IMG_W;
    wire [7:0]  ramp8 = ramp_col[10:3];
    wire [23:0] pix24 = (FORCE_ETH_RAMP != 0) ? {ramp8, ramp8, ramp8} : {r8, g8, b8};

    wire skid_push  = s_pix_valid && capturing && !skid_full && skid_rdy && !skid_rst;
    wire skid_ovf   = s_pix_valid && capturing && skid_full && skid_rdy && !skid_rst;
    wire skid_pop   = (state == S_PAYLOAD) && !skid_empty && axis_ready && skid_rdy && !skid_rst;
    /* Abort only in payload (header may already be on AXIS); header-ovf → flush at entry. */
    wire abort_ovf  = skid_ovf && (state == S_PAYLOAD);

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE    ("0"),
        .ECC_MODE            ("no_ecc"),
        .FIFO_MEMORY_TYPE    ("block"),
        .FIFO_READ_LATENCY   (0),
        .FIFO_WRITE_DEPTH    (SKID_DEPTH),
        .FULL_RESET_VALUE    (0),
        .PROG_EMPTY_THRESH   (10),
        .PROG_FULL_THRESH    (PROG_FULL_TH),
        .RD_DATA_COUNT_WIDTH (14),
        .READ_DATA_WIDTH     (24),
        .READ_MODE           ("fwft"),
        .SIM_ASSERT_CHK      (0),
        .USE_ADV_FEATURES    ("0002"),
        .WAKEUP_TIME         (0),
        .WRITE_DATA_WIDTH    (24),
        .WR_DATA_COUNT_WIDTH (14)
    ) u_skid_fifo (
        .rst           (skid_rst),
        .wr_clk        (clk),
        .wr_en         (skid_push),
        .din           (pix24),
        .full          (skid_full),
        .wr_rst_busy   (skid_wr_rst_busy),
        .rd_en         (skid_pop),
        .dout          (skid_dout),
        .empty         (skid_empty),
        .rd_rst_busy   (skid_rd_rst_busy),
        .sleep         (1'b0),
        .injectdbiterr (1'b0),
        .injectsbiterr (1'b0),
        .almost_empty  (),
        .almost_full   (),
        .data_valid    (),
        .overflow      (),
        .underflow     (),
        .prog_empty    (),
        .prog_full     (skid_prog_full),
        .wr_ack        (),
        .wr_data_count (),
        .rd_data_count (),
        .dbiterr       (),
        .sbiterr       ()
    );

    reg [31:0] hdr_word;
    always @(*) begin
        case (hdr_cnt)
            2'd0: hdr_word = {tx_frame_cnt[7:0], tx_frame_cnt[15:8], 8'h55, 8'hAA};
            2'd1: hdr_word = {H16[7:0], H16[15:8], W16[7:0], W16[15:8]};
            default: hdr_word = {8'h00, 8'h00, 8'h00, FMT8};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            hdr_cnt       <= 2'd0;
            pix_cnt       <= 21'd0;
            skip_cnt      <= 4'd0;
            gap_cnt       <= 22'd0;
            in_pix_idx    <= 21'd0;
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tkeep  <= 4'hF;
            tx_frame_cnt  <= 16'd0;
            skid_ovf_cnt  <= 16'd0;
        end else begin
            m_axis_tlast <= 1'b0;

            if (accept_sof)
                skid_ovf_cnt <= 16'd0;
            else if (skid_ovf && (skid_ovf_cnt != 16'hFFFF))
                skid_ovf_cnt <= skid_ovf_cnt + 16'd1;

            // Index of pixel pushed into skid (for FORCE_ETH_RAMP)
            if (accept_sof)
                in_pix_idx <= 21'd1; // cycle 0 already pushed as idx 0 via combo
            else if (skid_push)
                in_pix_idx <= in_pix_idx + 21'd1;

            case (state)
            S_IDLE: begin
                m_axis_tvalid <= 1'b0;
                if (frame_start && capture_en && m_axis_tready && skid_empty && skid_rdy) begin
                    if (skip_cnt == frame_skip) begin
                        skip_cnt <= 4'd0;
                        state    <= S_HEADER;
                        hdr_cnt  <= 2'd0;
                    end else begin
                        skip_cnt <= skip_cnt + 1'b1;
                    end
                end
            end

            S_HEADER: begin
                if (axis_ready) begin
                    m_axis_tdata  <= hdr_word;
                    m_axis_tkeep  <= 4'hF;
                    m_axis_tvalid <= 1'b1;
                    if (hdr_cnt == HDR_WORDS - 1) begin
                        pix_cnt <= 21'd0;
                        state   <= S_PAYLOAD;
                    end
                    hdr_cnt <= hdr_cnt + 2'd1;
                end
            end

            S_PAYLOAD: begin
                if (abort_ovf) begin
                    state <= S_FLUSH_BAD;
                end else if (!skid_empty && axis_ready) begin
                    m_axis_tdata  <= {8'h00, skid_dout[7:0], skid_dout[15:8], skid_dout[23:16]};
                    m_axis_tkeep  <= 4'hF;
                    m_axis_tvalid <= 1'b1;
                    if (pix_cnt == TOTAL_PIX - 1) begin
                        m_axis_tlast <= 1'b1;
                        state        <= S_DONE;
                        tx_frame_cnt <= tx_frame_cnt + 16'd1;
                    end else begin
                        pix_cnt <= pix_cnt + 21'd1;
                    end
                end else if (axis_fire) begin
                    m_axis_tvalid <= 1'b0;
                end
            end

            /* Complete DMA length with zeros; do not bump tx_frame_cnt (dropped). */
            S_FLUSH_BAD: begin
                if (axis_ready) begin
                    m_axis_tdata  <= 32'd0;
                    m_axis_tkeep  <= 4'hF;
                    m_axis_tvalid <= 1'b1;
                    if (pix_cnt == TOTAL_PIX - 1) begin
                        m_axis_tlast <= 1'b1;
                        state        <= S_DONE;
                    end else begin
                        pix_cnt <= pix_cnt + 21'd1;
                    end
                end else if (axis_fire) begin
                    m_axis_tvalid <= 1'b0;
                end
            end

            S_DONE: begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                if (gap_cnt >= GAP_CYCLES) begin
                    gap_cnt <= 22'd0;
                    state   <= S_IDLE;
                end else begin
                    gap_cnt <= gap_cnt + 22'd1;
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
