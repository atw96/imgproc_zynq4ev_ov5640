// =============================================================================
// bilateral_filter.v
// 5-row Bilateral (vertical tap) — Spatial + Range Gaussian Denoising
//
// Fixes vs previous:
//   1) Per-row range LUT: use |centre - win_row[i]| (not delta_r[2]==0).
//   2) Normalize with Q16 reciprocal of sum_w (not fixed NORM_SHIFT wrap).
//   3) Wider default range LUT (stronger denoise / less noise).
// =============================================================================

`timescale 1ns / 1ps

module bilateral_filter #(
    parameter PIXEL_W    = 13,
    parameter LINE_LEN   = 2048,
    parameter WIN_HALF   = 2,
    parameter NORM_SHIFT = 8
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [PIXEL_W-1:0]    s_pix_data,
    input  wire                  s_pix_valid,
    input  wire                  s_pix_sof,
    input  wire                  s_pix_hsync,

    input  wire [7:0]            lut_wr_addr,
    input  wire [7:0]            lut_wr_data,
    input  wire                  lut_wr_en,

    output reg  [PIXEL_W-1:0]    m_pix_data,
    output reg                   m_pix_valid,
    output reg                   m_pix_sof,
    output reg                   m_pix_hsync
);

    localparam ADDR_W = $clog2(LINE_LEN);

    // =========================================================================
    // Stage 1: 5-row line buffer ring
    // =========================================================================

    reg [3:0]        wr_row;
    reg [ADDR_W-1:0] wr_col;

    always @(posedge clk) begin
        if (!rst_n) begin
            wr_row  <= 4'd0;
            wr_col  <= {ADDR_W{1'b0}};
        end else if (s_pix_valid) begin
            if (wr_col == LINE_LEN[ADDR_W-1:0] - 1) begin
                wr_col  <= {ADDR_W{1'b0}};
                wr_row  <= (wr_row == 4'd4) ? 4'd0 : wr_row + 1;
            end else begin
                wr_col  <= wr_col + 1;
            end
        end
    end

    reg [3:0]        rd_head;
    reg [ADDR_W-1:0] rd_col;
    reg              rd_active;
    reg [3:0]        rows_filled;

    always @(posedge clk) begin
        if (!rst_n) begin
            rows_filled <= 4'd0;
            rd_active   <= 1'b0;
            rd_head     <= 4'd0;
            rd_col      <= {ADDR_W{1'b0}};
        end else begin
            if (s_pix_valid && wr_col == LINE_LEN[ADDR_W-1:0] - 1) begin
                if (rows_filled < 4'd5) rows_filled <= rows_filled + 1;
            end
            if (rows_filled >= 4'd5 && !rd_active)
                rd_active <= 1'b1;
            if (rd_active && s_pix_valid) begin
                if (rd_col == LINE_LEN[ADDR_W-1:0] - 1) begin
                    rd_col  <= {ADDR_W{1'b0}};
                    rd_head <= (rd_head == 4'd4) ? 4'd0 : rd_head + 1;
                end else begin
                    rd_col  <= rd_col + 1;
                end
            end
        end
    end

    reg [ADDR_W-1:0]  wa_r, ra_r;
    reg [PIXEL_W-1:0] wd_r;
    reg               we_r;
    reg [3:0]         wr_row_r;
    reg               re_r;
    reg               sof_r, hsync_r;
    reg               sof_pend;

    always @(posedge clk) begin
        wa_r     <= wr_col;
        wd_r     <= s_pix_data;
        we_r     <= s_pix_valid;
        wr_row_r <= wr_row;
        ra_r     <= rd_col;
        re_r     <= rd_active & s_pix_valid;
        sof_r    <= s_pix_sof;
        hsync_r  <= s_pix_hsync;
    end

    wire [PIXEL_W-1:0] row_rd[0:4];

    genvar ri;
    generate
        for (ri = 0; ri < 5; ri = ri + 1) begin : g_row
            wire row_we = we_r && (wr_row_r == ri[3:0]);
            ram_tdp_bram #(
                .DATA_W (PIXEL_W),
                .DEPTH  (LINE_LEN),
                .ADDR_W (ADDR_W),
                .DO_REG (0)
            ) u_lb (
                .clk_a   (clk),   .en_a(1'b1),  .we_a(row_we),
                .addr_a  (wa_r),  .wdata_a(wd_r),
                .rdata_a (),      .rdata_a_vld(),
                .clk_b   (clk),   .en_b(re_r),   .we_b(1'b0),
                .addr_b  (ra_r),  .wdata_b({PIXEL_W{1'b0}}),
                .rdata_b (row_rd[ri]), .rdata_b_vld()
            );
        end
    endgenerate

    function [3:0] ring5;
        input [3:0] head;
        input [2:0] k;
        reg   [4:0] s;
        begin
            s     = {1'b0, head} + {2'b0, k};
            ring5 = (s >= 5'd5) ? s[3:0] - 4'd5 : s[3:0];
        end
    endfunction

    function [PIXEL_W-1:0] sel5;
        input [3:0] idx;
        input [PIXEL_W-1:0] r0, r1, r2, r3, r4;
        begin
            case (idx)
                4'd0:    sel5 = r0;
                4'd1:    sel5 = r1;
                4'd2:    sel5 = r2;
                4'd3:    sel5 = r3;
                default: sel5 = r4;
            endcase
        end
    endfunction

    reg [3:0] rd_head_lat;
    reg       re_lat;
    reg       sof_lat, hsync_lat;
    always @(posedge clk) begin
        rd_head_lat <= rd_head;
        re_lat      <= re_r;
        sof_lat     <= sof_r;
        hsync_lat   <= hsync_r;
    end

    wire [PIXEL_W-1:0] win_row[0:4];
    genvar gi;
    generate
        for (gi = 0; gi < 5; gi = gi + 1) begin : g_win
            assign win_row[gi] = sel5(ring5(rd_head_lat, gi[2:0]),
                                      row_rd[0], row_rd[1], row_rd[2],
                                      row_rd[3], row_rd[4]);
        end
    endgenerate

    wire [PIXEL_W-1:0] centre = win_row[2];

    // =========================================================================
    // Stage 2: Per-row range LUT
    // Wider sigma_r default to reduce noise (slower falloff).
    // =========================================================================

    wire [PIXEL_W-1:0] delta_r[0:4];
    genvar di;
    generate
        for (di = 0; di < 5; di = di + 1) begin : g_delta
            assign delta_r[di] = (centre > win_row[di]) ?
                                  centre - win_row[di] :
                                  win_row[di] - centre;
        end
    endgenerate

    (* ram_style = "distributed" *)
    reg [7:0] range_lut[0:255];

    integer li;
    initial begin
        for (li = 0; li < 256; li = li + 1) begin
            // Wider denoise curve (approx sigma_r ~ 80 in 8-bit delta space)
            if      (li < 16)  range_lut[li] = 8'd255;
            else if (li < 32)  range_lut[li] = 8'd240;
            else if (li < 48)  range_lut[li] = 8'd210;
            else if (li < 64)  range_lut[li] = 8'd170;
            else if (li < 96)  range_lut[li] = 8'd120;
            else if (li < 128) range_lut[li] = 8'd70;
            else if (li < 176) range_lut[li] = 8'd35;
            else               range_lut[li] = 8'd12;
        end
    end

    always @(posedge clk) begin
        if (lut_wr_en)
            range_lut[lut_wr_addr] <= lut_wr_data;
    end

    reg [7:0]         range_w_r[0:4];
    reg               p2_valid;
    reg               p2_sof, p2_hsync;
    reg [PIXEL_W-1:0] p2_centre;
    reg [PIXEL_W-1:0] p2_row[0:4];

    always @(posedge clk) begin
        p2_valid     <= re_lat;
        p2_sof       <= sof_lat;
        p2_hsync     <= hsync_lat;
        p2_centre    <= centre;
        p2_row[0]    <= win_row[0];
        p2_row[1]    <= win_row[1];
        p2_row[2]    <= win_row[2];
        p2_row[3]    <= win_row[3];
        p2_row[4]    <= win_row[4];
        range_w_r[0] <= range_lut[delta_r[0][7:0]];
        range_w_r[1] <= range_lut[delta_r[1][7:0]];
        range_w_r[2] <= range_lut[delta_r[2][7:0]];
        range_w_r[3] <= range_lut[delta_r[3][7:0]];
        range_w_r[4] <= range_lut[delta_r[4][7:0]];
    end

    // =========================================================================
    // Stage 3/4: Spatial * range, accumulate
    // =========================================================================

    wire [3:0] sp_w[0:4];
    assign sp_w[0] = 4'd4;
    assign sp_w[1] = 4'd10;
    assign sp_w[2] = 4'd15;
    assign sp_w[3] = 4'd10;
    assign sp_w[4] = 4'd4;

    reg [11:0]         comb_w[0:4];
    reg [PIXEL_W+11:0] wpix[0:4];
    reg                p3_valid;
    reg                p3_sof, p3_hsync;
    reg [PIXEL_W-1:0]  p3_centre;

    always @(posedge clk) begin
        p3_valid  <= p2_valid;
        p3_sof    <= p2_sof;
        p3_hsync  <= p2_hsync;
        p3_centre <= p2_centre;
        comb_w[0] <= sp_w[0] * range_w_r[0];
        comb_w[1] <= sp_w[1] * range_w_r[1];
        comb_w[2] <= sp_w[2] * range_w_r[2];
        comb_w[3] <= sp_w[3] * range_w_r[3];
        comb_w[4] <= sp_w[4] * range_w_r[4];
        wpix[0]   <= sp_w[0] * range_w_r[0] * p2_row[0];
        wpix[1]   <= sp_w[1] * range_w_r[1] * p2_row[1];
        wpix[2]   <= sp_w[2] * range_w_r[2] * p2_row[2];
        wpix[3]   <= sp_w[3] * range_w_r[3] * p2_row[3];
        wpix[4]   <= sp_w[4] * range_w_r[4] * p2_row[4];
    end

    reg [PIXEL_W+13:0] sum_wpix;
    reg [13:0]         sum_w;
    reg                p4_valid;
    reg                p4_sof, p4_hsync;
    reg [PIXEL_W-1:0]  p4_centre;

    always @(posedge clk) begin
        p4_valid  <= p3_valid;
        p4_sof    <= p3_sof;
        p4_hsync  <= p3_hsync;
        p4_centre <= p3_centre;
        sum_wpix  <= wpix[0] + wpix[1] + wpix[2] + wpix[3] + wpix[4];
        sum_w     <= comb_w[0] + comb_w[1] + comb_w[2] + comb_w[3] + comb_w[4];
    end

    // =========================================================================
    // Stage 5: out = sum_wpix / sum_w via Q16 reciprocal LUT
    // =========================================================================

    (* ram_style = "block" *)
    reg [15:0] recip_lut[0:2047];

    integer rii;
    integer bin_c;
    initial begin
        recip_lut[0] = 16'hFFFF;
        for (rii = 1; rii < 2048; rii = rii + 1) begin
            bin_c = (rii << 3) + 4;
            recip_lut[rii] = (32'h10000 + (bin_c / 2)) / bin_c;
        end
    end

    wire [10:0]        recip_idx = (sum_w < 14'd8) ? 11'd0 : sum_w[13:3];
    reg  [15:0]        recip_q16;
    reg                p5_valid;
    reg                p5_sof, p5_hsync;
    reg [PIXEL_W-1:0]  p5_centre;
    reg [PIXEL_W+13:0] p5_sum_wpix;
    reg [13:0]         p5_sum_w;

    always @(posedge clk) begin
        p5_valid    <= p4_valid;
        p5_sof      <= p4_sof;
        p5_hsync    <= p4_hsync;
        p5_centre   <= p4_centre;
        p5_sum_wpix <= sum_wpix;
        p5_sum_w    <= sum_w;
        recip_q16   <= recip_lut[recip_idx];
    end

    // Sticky SOF: input pulse may arrive before rd_active; release on first output
    always @(posedge clk) begin
        if (!rst_n)
            sof_pend <= 1'b0;
        else if (p5_valid && sof_pend)
            sof_pend <= 1'b0;
        else if (s_pix_valid && s_pix_sof)
            sof_pend <= 1'b1;
    end

    wire [PIXEL_W+29:0] norm_prod  = p5_sum_wpix * recip_q16;
    wire [PIXEL_W+13:0] norm_full  = norm_prod[PIXEL_W+29:16];
    wire                use_centre = (p5_sum_w < 14'd16);
    wire [PIXEL_W-1:0]  norm_clamp =
        (norm_full[PIXEL_W+13:PIXEL_W] != 0) ? {PIXEL_W{1'b1}} :
         norm_full[PIXEL_W-1:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            m_pix_valid <= 1'b0;
            m_pix_sof   <= 1'b0;
            m_pix_hsync <= 1'b0;
        end else begin
            m_pix_valid <= p5_valid;
            m_pix_sof   <= p5_valid & sof_pend;
            m_pix_hsync <= p5_valid & p5_hsync;
            m_pix_data  <= use_centre ? p5_centre : norm_clamp;
        end
    end

endmodule
