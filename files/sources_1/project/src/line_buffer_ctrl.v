// =============================================================================
// line_buffer_ctrl.v  (v2 — Edge-Pad Edition)
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// ── Defect-1 Fix: Vertical Edge Padding ─────────────────────────────────────
//   Original behaviour: output only starts after all NUM_LINES (=11) rows are
//   buffered, so the top 5 rows and bottom 5 rows of the frame are never
//   processed by the 11×11 Wiener filter.
//
//   Fixed behaviour  : output starts after the FIRST complete row.  When the
//   ring buffer contains fewer than NUM_LINES rows, or when the window extends
//   past the last written row, the missing rows are filled by replicating the
//   nearest available row (replicate-pad / edge-pad).
//
//   Replicate-pad rule:
//     • Top edge  (window row above image row 0)        → clamp to row 0
//     • Bottom edge (window row beyond last written row) → clamp to last row
//
//   A wr_row_total counter tracks how many full rows have been written to the
//   ring.  This tells the output mux what the maximum readable row index is,
//   independent of the capped lines_filled counter.
//
// ── Defect-3 Fix (partial): Redundant Pipeline Delay ────────────────────────
//   col_y now starts from 0 (the actual image centre-row index), removing
//   the artificial +5 bias that downstream code had to account for.
//
// ── Timing (unchanged from v1) ───────────────────────────────────────────────
//   Input pixel → BRAM write : 1 clock  (wa_r stage)
//   BRAM read → col_pixels   : 2 clocks (ra_r → BRAM → col_pixels register)
//   Total read latency from rd_active: 2 clocks
//
// ── Parameters ───────────────────────────────────────────────────────────────
//   PIXEL_W    Pixel bit-width  (default 13 for Q0.13)
//   LINE_LEN   Pixels per line  (default 2048)
//   NUM_LINES  Lines in ring    (default 11)
//   IMG_H      Frame height     (default 1080) — used for bottom-edge clamping
// =============================================================================

`timescale 1ns/1ps

module line_buffer_ctrl #(
    parameter PIXEL_W   = 13,
    parameter LINE_LEN  = 2048,
    parameter NUM_LINES = 11,
    parameter IMG_H     = 1080,
    parameter ADDR_W    = $clog2(LINE_LEN)
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Input pixel stream (from img_preprocessor Y channel)
    input  wire [PIXEL_W-1:0]            s_pixel_tdata,
    input  wire                          s_pixel_tvalid,
    input  wire                          s_pixel_tlast,
    input  wire                          s_pixel_sof,
    output wire                          s_pixel_tready,

    // 11-row window output
    output reg  [PIXEL_W*11-1:0]         col_pixels,
    output reg                           col_valid,
    output reg  [ADDR_W-1:0]             col_x,
    output reg  [10:0]                   col_y,
    output reg                           col_sof,

    // Status
    output reg                           buf_full,
    output wire [3:0]                    fill_lines,
    output wire [ADDR_W-1:0]             wr_ptr_x
);

    // -------------------------------------------------------------------------
    // Derived constants
    // -------------------------------------------------------------------------
    localparam PAD_SIZE = NUM_LINES / 2;   // = 5 for 11-row window

    // BUG-FIX (v4): LINE_LEN[ADDR_W-1:0] evaluates to 0 for any power-of-2
    // LINE_LEN (e.g. 64, 2048), because the MSB that carries the '1' is at
    // bit position ADDR_W, which is OUTSIDE the [ADDR_W-1:0] slice.
    // Then  `0 - 1`  promotes to 32-bit → 32'hFFFF_FFFF, which can never
    // equal the ADDR_W-bit wr_col → line-end condition is always false.
    // Fix: pre-compute the line-end threshold as a properly-sized localparam.
    localparam [ADDR_W-1:0] LINE_END = LINE_LEN - 1;  // 64-1=63 → 6'b111111

    // Declare before continuous assignments to avoid implicit-net redeclare
    // issues in ModelSim/Verilog.
    reg [ADDR_W-1:0] wr_col;
    reg [3:0]         lines_filled;

    assign s_pixel_tready = 1'b1;
    assign fill_lines     = lines_filled;
    assign wr_ptr_x       = wr_col;

    // =========================================================================
    // Write path: ring of NUM_LINES lines
    // =========================================================================
    reg [3:0]        wr_line;
    reg [10:0]       wr_row_total;    // total rows written this frame (0-based)

    wire wr_ok = s_pixel_tvalid;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_line      <= 4'd0;
            wr_col       <= {ADDR_W{1'b0}};
            lines_filled <= 4'd0;
            buf_full     <= 1'b0;
            wr_row_total <= 11'd0;
        end else if (wr_ok) begin
            // Advance column; on line-end advance row pointers
            if (s_pixel_tlast || wr_col == LINE_END) begin
                wr_col  <= {ADDR_W{1'b0}};
                wr_line <= (wr_line == 4'd10) ? 4'd0 : wr_line + 1;

                // lines_filled: count up to NUM_LINES then hold
                if (lines_filled < 4'd11)
                    lines_filled <= lines_filled + 1;

                buf_full <= 1'b1;

                // Track total rows for bottom-edge clamping
                wr_row_total <= (wr_row_total == IMG_H[10:0] - 1) ?
                                 11'd0 : wr_row_total + 11'd1;
            end else begin
                wr_col <= wr_col + 1;
            end
        end
    end

    // Read path: follows write, starting one row in, with replicate-padding
    // =========================================================================
    reg [3:0]        rd_head;
    reg [ADDR_W-1:0] rd_col;
    reg [10:0]       rd_y;       // centre row index in image (starts at 0)
    reg              rd_active;

    // rd_head advances only when the window top has passed image row 0
    // i.e. rd_y - PAD_SIZE >= 0  →  rd_y >= PAD_SIZE
    wire rd_head_should_advance = (rd_y >= PAD_SIZE[10:0]);

    always @(posedge clk) begin
        if (!rst_n) begin
            rd_head   <= 4'd0;
            rd_col    <= {ADDR_W{1'b0}};
            rd_y      <= 11'd0;    // --- CHANGE v2: was 11'd5 ---
            rd_active <= 1'b0;
        end else begin
            // Start reading after first row is ready
            if (buf_full && !rd_active)
                rd_active <= 1'b1;

            if (rd_active) begin
                if (rd_col < LINE_END) begin
                    rd_col <= rd_col + 1;
                end else begin
                    rd_col <= {ADDR_W{1'b0}};
                    rd_y   <= rd_y + 1;
                    // --- CHANGE v2: rd_head only advances past the padding region ---
                    if (rd_head_should_advance)
                        rd_head <= (rd_head == 4'd10) ? 4'd0 : rd_head + 1;
                end
            end
        end

    end

    // =========================================================================
    // Registered addresses (clean BRAM timing — same as v1)
    // =========================================================================
    reg [ADDR_W-1:0]  wa_r;
    reg [PIXEL_W-1:0] wd_r;
    reg               we_r;
    reg [3:0]         wr_line_r;
    reg [ADDR_W-1:0]  ra_r;
    reg               re_r;

    always @(posedge clk) begin
        wa_r      <= wr_col;       wd_r      <= s_pixel_tdata;
        we_r      <= wr_ok;        wr_line_r <= wr_line;
        ra_r      <= rd_col;       re_r      <= rd_active;
    end

    // Second latency stage to match BRAM read latency
    reg [ADDR_W-1:0] ra_lat;
    reg              re_lat;
    reg [3:0]        rd_head_lat;

    always @(posedge clk) begin
        ra_lat      <= ra_r;
        re_lat      <= re_r;
        rd_head_lat <= rd_head;
    end

    // =========================================================================
    // Effective-offset computation for edge padding
    // =========================================================================
    // For window row `off` (0=top/oldest .. 10=bottom/newest):
    //   target_image_row = rd_y - PAD_SIZE + off   (may be negative or > max)
    //   max_avail_row    = wr_row_total - 1         (last completely written row)
    //   ring_base_row    = max(0, rd_y - PAD_SIZE)  (image row at ring_idx(head,0))
    //   clamped_row      = clamp(target_image_row, 0, min(max_avail_row, IMG_H-1))
    //   eff_off          = clamped_row - ring_base_row  (relative ring offset)
    //
    // Registered two stages to match ra_lat / rd_head_lat timing.
    // =========================================================================

    // Stage-1 registration (aligned with ra_r)
    reg [3:0] eff_off_r [0:10];

    // wr_row_total lags by 1 cycle from the always block above; capture here
    // at the same time as ra_r registration so timing is consistent.
    reg [10:0] wr_row_r;   // registered wr_row_total
    always @(posedge clk) wr_row_r <= wr_row_total;

    // Precompute max_avail and ring_base combinatorially to use in the registered block
    // max_avail: highest image row that has been fully written to the ring
    wire [11:0] max_avail_w =
        (wr_row_r > 11'd0) ?
            (({1'b0,wr_row_r} - 12'd1 >= IMG_H[11:0]) ? IMG_H[11:0] - 12'd1
                                                        : {1'b0,wr_row_r} - 12'd1) :
            12'd0;

    // ring_base: the image row index that ring_idx(rd_head, 0) maps to
    wire [11:0] ring_base_w = (rd_y >= PAD_SIZE[10:0]) ?
                               {1'b0, rd_y} - 12'd5 :   // PAD_SIZE = 5 (constant)
                               12'd0;

    // Compute eff_off for each of 11 window positions (combinatorial, then register)
    // Using generate/assign instead of always-with-local-regs for Verilog-2001 compat.
    // PAD_SIZE = 5 (compile-time constant), eoi unrolled by generate.
    genvar eoi;
    generate
        for (eoi = 0; eoi < 11; eoi = eoi + 1) begin : gen_eff_comb
            // Signed target row: rd_y - 5 + eoi
            // In Verilog-2001 genvar arithmetic: eoi is unrolled as a constant integer.
            // We use rd_y (11-bit) sign-extended to 13 bits, subtract 5, add eoi.
            wire signed [12:0] target_s = $signed({2'b0, rd_y})
                                        - 13'sd5
                                        + $signed(13'd0 + eoi);
            // Clamped to [0, max_avail_w]
            wire [11:0] clamped_w =
                target_s[12]                             ? 12'd0        : // negative
                ({1'b0,target_s[11:0]} > max_avail_w)   ? max_avail_w  :
                                                           target_s[11:0];
            // Effective ring offset = clamped - ring_base (always 0..10)
            wire [3:0] eff_w = clamped_w[3:0] - ring_base_w[3:0];

            always @(posedge clk)
                eff_off_r[eoi] <= eff_w;
        end
    endgenerate

    // Stage-2 registration (aligned with ra_lat / rd_head_lat)
    reg [3:0] eff_off_lat [0:10];

    always @(posedge clk) begin : p_eff_off_stage2
        integer oi;
        for (oi = 0; oi < 11; oi = oi + 1)
            eff_off_lat[oi] <= eff_off_r[oi];
    end

    // Latch rd_y two cycles (to align col_y output with col_pixels)
    reg [10:0] rd_y_r, rd_y_lat;
    reg        sof_r, sof_lat;
    always @(posedge clk) begin
        rd_y_r   <= rd_y;
        rd_y_lat <= rd_y_r;
        sof_r    <= s_pixel_sof;
        sof_lat  <= sof_r;
    end

    // =========================================================================
    // 11 TDP-BRAM instances (unchanged from v1)
    // =========================================================================
    wire [PIXEL_W-1:0] row_rd[0:10];
    wire               row_vld[0:10];

    genvar ri;
    generate
        for (ri = 0; ri < 11; ri = ri + 1) begin : gen_row
            wire row_we = we_r && (wr_line_r == ri[3:0]);

            ram_tdp_bram #(
                .DATA_W (PIXEL_W),
                .DEPTH  (LINE_LEN),
                .ADDR_W (ADDR_W),
                .DO_REG (0)
            ) u_row_bram (
                .clk_a   (clk),    .en_a(1'b1),   .we_a(row_we),
                .addr_a  (wa_r),   .wdata_a(wd_r), .rdata_a(),   .rdata_a_vld(),
                .clk_b   (clk),    .en_b(re_r),    .we_b(1'b0),
                .addr_b  (ra_r),   .wdata_b({PIXEL_W{1'b0}}),
                .rdata_b (row_rd[ri]),              .rdata_b_vld(row_vld[ri])
            );
        end
    endgenerate

    // =========================================================================
    // Ring-index function (modulo-11) — unchanged from v1
    // =========================================================================
    function [3:0] ring_idx;
        input [3:0] head;
        input [3:0] offset;
        reg   [4:0] s;
        begin
            s = {1'b0, head} + {1'b0, offset};
            ring_idx = (s >= 5'd11) ? s[3:0] - 4'd11 : s[3:0];
        end
    endfunction

    function [PIXEL_W-1:0] sel11;
        input [3:0] phys;
        input [PIXEL_W-1:0] r0,r1,r2,r3,r4,r5,r6,r7,r8,r9,r10;
        begin
            case (phys)
                4'd0:    sel11 = r0;  4'd1:  sel11 = r1;  4'd2:  sel11 = r2;
                4'd3:    sel11 = r3;  4'd4:  sel11 = r4;  4'd5:  sel11 = r5;
                4'd6:    sel11 = r6;  4'd7:  sel11 = r7;  4'd8:  sel11 = r8;
                4'd9:    sel11 = r9;  default: sel11 = r10;
            endcase
        end
    endfunction

    // =========================================================================
    // Pack col_pixels using clamped effective offsets (CHANGE v2)
    // =========================================================================
    always @(posedge clk) begin
        col_valid <= re_lat;
        col_x     <= ra_lat;
        col_y     <= rd_y_lat;
        col_sof   <= sof_lat && re_lat;

        // Window row 0 = top (oldest physical slot), row 10 = bottom (newest)
        // Use eff_off_lat instead of raw index to apply edge clamping.
        col_pixels[ 0*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 0]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 1*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 1]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 2*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 2]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 3*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 3]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 4*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 4]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 5*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 5]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 6*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 6]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 7*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 7]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 8*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 8]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[ 9*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[ 9]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
        col_pixels[10*PIXEL_W +: PIXEL_W] <= sel11(ring_idx(rd_head_lat, eff_off_lat[10]),
            row_rd[0],row_rd[1],row_rd[2],row_rd[3],row_rd[4],row_rd[5],
            row_rd[6],row_rd[7],row_rd[8],row_rd[9],row_rd[10]);
    end

endmodule
