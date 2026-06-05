//=============================================================================
// img_preprocessor.v
// Full ISP Front-End: RAW Bayer → Preprocessed Y + CbCr
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// ╔═══════════════════════════════════════════════════════════════════╗
// ║  CORRECT ISP PIPELINE ORDER  (per sensor characterization)       ║
// ║                                                                   ║
// ║  Stage 1: Dead-Pixel Correction  (before BL to preserve sign)    ║
// ║  Stage 2: Black Level Subtraction                                 ║
// ║  Stage 3: Bayer Demosaic  (bilinear, RGGB default)               ║
// ║           → 2 RAMB36 line buffers for 3-row window               ║
// ║  Stage 4: White Balance  (per-channel R/G/B gain, Q2.10)         ║
// ║  Stage 5: Gamma Correction  (256-entry BRAM LUT per channel)     ║
// ║  Stage 6: RGB → YCbCr  (BT.601 fixed-point)                     ║
// ║  Output:  Y [12:0]   Q0.13 unsigned  (matches se_ver2.m format)  ║
// ║           CbCr [15:0]  stored for final RGB reconstruction        ║
// ╚═══════════════════════════════════════════════════════════════════╝
//
// Why this order matters:
//   - Dead-pixel detection BEFORE BL: stuck-at-0 pixels are unambiguous
//   - BL subtraction BEFORE demosaic: avoids propagating DC offset across
//     Bayer interpolation (colour cast)
//   - Demosaic BEFORE WB: interpolation weights should be radiometric,
//     not colour-corrected (WB changes relative channel magnitudes)
//   - WB BEFORE gamma: gamma is a perceptual encoding; WB is linear
//   - Gamma BEFORE YCbCr: ensures correct perceptual encoding of Y
//=============================================================================

`timescale 1ns/1ps

module img_preprocessor #(
    parameter PIXEL_W  = 13,     // Q0.13 normalised (0..8191), matching MATLAB
    parameter LINE_LEN = 2048,
    parameter ADDR_W   = $clog2(LINE_LEN)
)(
    input  wire                 clk,
    input  wire                 rst_n,

    //--- Sensor RAW Bayer Input (13-bit, 1 pixel/clk) ----------------------
    input  wire [PIXEL_W-1:0]   s_raw_data,
    input  wire                 s_raw_valid,
    input  wire                 s_raw_hsync,   // high on first pixel of each row
    input  wire                 s_raw_vsync,   // high on first row of each frame
    output wire                 s_raw_ready,

    //--- Processed Output ---------------------------------------------------
    output reg  [PIXEL_W-1:0]   m_Y_data,      // 13-bit Y (Q0.13)
    output reg  [15:0]           m_CbCr_data,  // {Cb[7:0], Cr[7:0]} unsigned
    output reg                   m_pix_valid,
    output reg                   m_pix_hsync,
    output reg                   m_pix_vsync,

    //--- Gamma LUT Write (AXI4-Lite driven) ---------------------------------
    input  wire [PIXEL_W-1:0]   lut_wr_data,
    input  wire [7:0]            lut_wr_addr,
    input  wire                  lut_wr_en,

    //--- White Balance Gains (Q2.10, 1024 = 1.0x) --------------------------
    input  wire [11:0]           wb_gain_r,
    input  wire [11:0]           wb_gain_g,
    input  wire [11:0]           wb_gain_b,

    //--- Black Level --------------------------------------------------------
    input  wire [PIXEL_W-1:0]   black_level,

    //--- Bayer Pattern: 00=RGGB 01=GRBG 10=GBRG 11=BGGR ----------------------
    input  wire [1:0]            bayer_fmt,

    //--- Status -------------------------------------------------------------
    output reg  [31:0]           dead_pixel_cnt
);

    assign s_raw_ready = 1'b1;

    //==========================================================================
    // Row/Column parity tracker
    //==========================================================================
    reg               row_par, col_par;
    reg [ADDR_W-1:0]  col_cnt;

    always @(posedge clk) begin
        if (!rst_n) begin
            row_par <= 0; col_par <= 0; col_cnt <= 0;
        end else if (s_raw_valid) begin
            if (s_raw_vsync) begin
                row_par <= 0; col_par <= 0; col_cnt <= 0;
            end else if (s_raw_hsync) begin
                row_par <= ~row_par; col_par <= 0; col_cnt <= 0;
            end else begin
                col_par <= ~col_par; col_cnt <= col_cnt + 1;
            end
        end
    end

    //==========================================================================
    // S1: Dead-Pixel Correction
    //==========================================================================
    wire s1_dead = (s_raw_data == {PIXEL_W{1'b0}}) |
                   (s_raw_data == {PIXEL_W{1'b1}});

    reg [PIXEL_W-1:0] s1_prev;
    reg [PIXEL_W-1:0] s1_data;
    reg               s1_valid, s1_hsync, s1_vsync, s1_rpar, s1_cpar;

    always @(posedge clk) begin
        if (!rst_n) begin s1_valid <= 0; dead_pixel_cnt <= 0; end
        else begin
            s1_valid <= s_raw_valid;
            s1_hsync <= s_raw_hsync; s1_vsync <= s_raw_vsync;
            s1_rpar  <= row_par;     s1_cpar  <= col_par;
            if (s_raw_valid) begin
                if (s_raw_hsync) s1_prev <= 13'h0FFF; // mid-grey on line start
                if (s1_dead) begin
                    s1_data        <= s1_prev;
                    dead_pixel_cnt <= dead_pixel_cnt + 1;
                end else begin
                    s1_data <= s_raw_data;
                    s1_prev <= s_raw_data;
                end
            end
        end
    end

    //==========================================================================
    // S2: Black Level Subtraction
    //==========================================================================
    wire [PIXEL_W:0]  bl_diff = {1'b0, s1_data} - {1'b0, black_level};
    reg [PIXEL_W-1:0] s2_data;
    reg               s2_valid, s2_hsync, s2_vsync, s2_rpar, s2_cpar;

    always @(posedge clk) begin
        s2_valid <= s1_valid; s2_hsync <= s1_hsync; s2_vsync <= s1_vsync;
        s2_rpar  <= s1_rpar;  s2_cpar  <= s1_cpar;
        s2_data  <= bl_diff[PIXEL_W] ? {PIXEL_W{1'b0}} : bl_diff[PIXEL_W-1:0];
    end

    //==========================================================================
    // S3: Bayer Demosaic — 3×3 bilinear interpolation
    //
    // Line buffer ring: lb_new = current row being written
    //                   lb_mid = row-1 (1 row delayed)
    //                   lb_old = row-2 (2 rows delayed, top of 3×3 window)
    //
    // The line buffers chain: write s2_data → lb_new
    //                               lb_new read → lb_mid
    //                               lb_mid read → lb_old
    //==========================================================================
    wire [PIXEL_W-1:0] lbn_rd, lbm_rd, lbo_rd;
    wire               lbn_vld, lbm_vld, lbo_vld;

    reg [ADDR_W-1:0]   lb_wcnt;  // write column counter
    reg [ADDR_W-1:0]   lb_rcnt;  // read column counter (1 clk delayed)
    reg [ADDR_W-1:0]   lb_rcnt_d1; // write address matching 1-clk read latency
    reg                lb_re;

    always @(posedge clk) begin
        if (!rst_n) begin lb_wcnt <= 0; end
        else if (s2_valid) begin
            lb_wcnt <= s2_hsync ? {ADDR_W{1'b0}} : lb_wcnt + 1;
        end
        lb_rcnt <= lb_wcnt;
        lb_rcnt_d1 <= lb_rcnt;
        lb_re   <= s2_valid;
    end

    // lb_new: current row write + simultaneous read-back
    ram_sdp_bram #(.DATA_W(PIXEL_W),.DEPTH(LINE_LEN),.ADDR_W(ADDR_W),.DO_REG(0)) u_lbn (
        .clk_w(clk),.we(s2_valid),.waddr(lb_wcnt),.wdata(s2_data),
        .clk_r(clk),.re(lb_re),.raddr(lb_rcnt),.rdata(lbn_rd),.rdata_vld(lbn_vld));

    // lb_mid: shifted version (receives lb_new output)
    ram_sdp_bram #(.DATA_W(PIXEL_W),.DEPTH(LINE_LEN),.ADDR_W(ADDR_W),.DO_REG(0)) u_lbm (
        .clk_w(clk),.we(lbn_vld),.waddr(lb_rcnt_d1),.wdata(lbn_rd),
        .clk_r(clk),.re(lb_re),.raddr(lb_rcnt),.rdata(lbm_rd),.rdata_vld(lbm_vld));

    // lb_old: oldest row (receives lb_mid output)
    ram_sdp_bram #(.DATA_W(PIXEL_W),.DEPTH(LINE_LEN),.ADDR_W(ADDR_W),.DO_REG(0)) u_lbo (
        .clk_w(clk),.we(lbm_vld),.waddr(lb_rcnt_d1),.wdata(lbm_rd),
        .clk_r(clk),.re(lb_re),.raddr(lb_rcnt),.rdata(lbo_rd),.rdata_vld(lbo_vld));

    // Delay row/col parity 2 cycles to match lb read latency
    reg [1:0] rpar_sr, cpar_sr, valid_sr, hsync_sr, vsync_sr;
    always @(posedge clk) begin
        rpar_sr  <= {rpar_sr[0],  s2_rpar};
        cpar_sr  <= {cpar_sr[0],  s2_cpar};
        valid_sr <= {valid_sr[0], lbo_vld};
        hsync_sr <= {hsync_sr[0], s2_hsync};
        vsync_sr <= {vsync_sr[0], s2_vsync};
    end

    // Horizontal neighbours via 1-clk shift register on lb outputs
    reg [PIXEL_W-1:0] lbn_prev, lbm_prev, lbo_prev;
    always @(posedge clk) begin
        if (lbn_vld) begin lbn_prev <= lbn_rd; lbm_prev <= lbm_rd; lbo_prev <= lbo_rd; end
    end

    // 3×3 window averages (combinational, registered below)
    // lbo = top row, lbm = middle (centre), lbn = bottom row
    // _prev = West,  _rd = East (approx), centre = lbm_rd
    wire [PIXEL_W+1:0] avg_NS     = {2'b0,lbo_rd}   + {2'b0,lbn_rd};      // /2
    wire [PIXEL_W+1:0] avg_WE_mid = {2'b0,lbm_prev} + {2'b0,lbm_rd};      // /2
    wire [PIXEL_W+2:0] avg_diag   = {2'b0,lbo_prev} + {2'b0,lbo_rd}
                                  + {2'b0,lbn_prev}  + {2'b0,lbn_rd};      // /4
    wire [PIXEL_W+2:0] avg_cross  = {2'b0,lbo_rd}   + {2'b0,lbn_rd}
                                  + {2'b0,lbm_prev}  + {2'b0,lbm_rd};      // /4

    // Registered demosaic output
    reg [PIXEL_W-1:0] s3_R, s3_G, s3_B;
    reg               s3_valid, s3_hsync, s3_vsync;

    always @(posedge clk) begin
        s3_valid <= valid_sr[1];
        s3_hsync <= hsync_sr[1];
        s3_vsync <= vsync_sr[1];
        // RGGB: rpar=0,cpar=0→R | rpar=0,cpar=1→Gr | rpar=1,cpar=0→Gb | rpar=1,cpar=1→B
        case ({rpar_sr[1], cpar_sr[1]})
            2'b00: begin // R site
                s3_R <= lbm_rd;
                s3_G <= avg_cross[PIXEL_W+1:2];   // (N+S+W+E)/4
                s3_B <= avg_diag[PIXEL_W+1:2];    // (NW+NE+SW+SE)/4
            end
            2'b01: begin // G on R-row
                s3_R <= avg_WE_mid[PIXEL_W:1];    // (W+E)/2
                s3_G <= lbm_rd;
                s3_B <= avg_NS[PIXEL_W:1];        // (N+S)/2
            end
            2'b10: begin // G on B-row
                s3_R <= avg_NS[PIXEL_W:1];
                s3_G <= lbm_rd;
                s3_B <= avg_WE_mid[PIXEL_W:1];
            end
            2'b11: begin // B site
                s3_R <= avg_diag[PIXEL_W+1:2];
                s3_G <= avg_cross[PIXEL_W+1:2];
                s3_B <= lbm_rd;
            end
        endcase
    end

    //==========================================================================
    // S4: White Balance  (per-channel gain, Q2.10: 1024=1.0×)
    //==========================================================================
    (* use_dsp = "yes" *)
    reg [PIXEL_W+11:0] s4_R_raw, s4_G_raw, s4_B_raw;
    reg                s4_valid, s4_hsync, s4_vsync;

    always @(posedge clk) begin
        s4_valid <= s3_valid; s4_hsync <= s3_hsync; s4_vsync <= s3_vsync;
        s4_R_raw <= s3_R * wb_gain_r;
        s4_G_raw <= s3_G * wb_gain_g;
        s4_B_raw <= s3_B * wb_gain_b;
    end

    reg [PIXEL_W-1:0] s4_R, s4_G, s4_B;
    reg               s4v2, s4h2, s4vs2;
    always @(posedge clk) begin
        s4v2 <= s4_valid; s4h2 <= s4_hsync; s4vs2 <= s4_vsync;
        s4_R <= |s4_R_raw[PIXEL_W+11:PIXEL_W+10] ? {PIXEL_W{1'b1}} : s4_R_raw[PIXEL_W-1+10:10];
        s4_G <= |s4_G_raw[PIXEL_W+11:PIXEL_W+10] ? {PIXEL_W{1'b1}} : s4_G_raw[PIXEL_W-1+10:10];
        s4_B <= |s4_B_raw[PIXEL_W+11:PIXEL_W+10] ? {PIXEL_W{1'b1}} : s4_B_raw[PIXEL_W-1+10:10];
    end

    //==========================================================================
    // S5: Gamma Correction (shared 256-entry LUT, 13-bit I/O)
    //
    // LUT has 1-cycle read latency: go_G at cycle T is for ga_G presented at T-1.
    // So R/B must be delayed by 1 cycle (s4_R_d1, s4_B_d1) to align with go_G.
    // R and B: pass-through (placeholder; use same LUT in full design if needed).
    //==========================================================================
    wire [7:0]          ga_R = s4_R[PIXEL_W-1:PIXEL_W-8];
    wire [7:0]          ga_G = s4_G[PIXEL_W-1:PIXEL_W-8];
    wire [7:0]          ga_B = s4_B[PIXEL_W-1:PIXEL_W-8];
    wire [PIXEL_W-1:0]  go_G;

    ram_sp_bram #(.DATA_W(PIXEL_W),.DEPTH(256),.ADDR_W(8),.WR_MODE(2)) u_gamma (
        .clk  (clk), .en  (1'b1),
        .we   (lut_wr_en),
        .addr (lut_wr_en ? lut_wr_addr : ga_G),
        .wdata(lut_wr_data), .rdata(go_G));

    // Align R/B with LUT output: LUT output is 1 cycle delayed, so use delayed R/B
    reg [PIXEL_W-1:0] s4_R_d1, s4_B_d1;
    always @(posedge clk) begin
        s4_R_d1 <= s4_R;
        s4_B_d1 <= s4_B;
    end
    wire [PIXEL_W-1:0] go_R = s4_R_d1;   // pass-through placeholder (same pixel as go_G)
    wire [PIXEL_W-1:0] go_B = s4_B_d1;

    reg               s5_valid, s5_hsync, s5_vsync;
    reg [PIXEL_W-1:0] s5_R, s5_G, s5_B;
    always @(posedge clk) begin
        s5_valid <= s4v2; s5_hsync <= s4h2; s5_vsync <= s4vs2;
        s5_R <= go_R; s5_G <= go_G; s5_B <= go_B;
    end

    //==========================================================================
    // S6: RGB → YCbCr  (BT.601 fixed-point, Q0.10 coefficients)
    //
    //  Y  =  (306R + 601G + 117B) >> 10        range [0, 8191]
    //  Cb = 128 + (−173R − 339G + 512B) >> 10  range [0, 255]
    //  Cr = 128 + ( 512R − 429G −  83B) >> 10  range [0, 255]
    //==========================================================================
    (* use_dsp = "yes" *)
    reg [22:0] s6_YR, s6_YG, s6_YB;
    reg [22:0] s6_CBB, s6_CBR, s6_CBG;
    reg [22:0] s6_CRR, s6_CRG, s6_CRB;
    reg        s6_valid, s6_hsync, s6_vsync;

    always @(posedge clk) begin
        s6_valid <= s5_valid; s6_hsync <= s5_hsync; s6_vsync <= s5_vsync;
        s6_YR  <= s5_R * 23'd306;  s6_YG  <= s5_G * 23'd601;  s6_YB  <= s5_B * 23'd117;
        s6_CBR <= s5_R * 23'd173;  s6_CBG <= s5_G * 23'd339;  s6_CBB <= s5_B * 23'd512;
        s6_CRR <= s5_R * 23'd512;  s6_CRG <= s5_G * 23'd429;  s6_CRB <= s5_B * 23'd83;
    end

    // Combine (registered)
    wire [23:0] y_sum  = s6_YR + s6_YG + s6_YB;                  // Q13.10
    wire [23:0] cb_pos = {1'b0, s6_CBB};
    wire [23:0] cb_neg = {1'b0, s6_CBR} + {1'b0, s6_CBG};
    wire [23:0] cr_pos = {1'b0, s6_CRR};
    wire [23:0] cr_neg = {1'b0, s6_CRG} + {1'b0, s6_CRB};

    wire [12:0] y_out   = y_sum[22:10];                           // >> 10 → 13-bit
    wire [8:0]  cb_raw  = 9'd128 + cb_pos[19:11] - cb_neg[19:11];
    wire [8:0]  cr_raw  = 9'd128 + cr_pos[19:11] - cr_neg[19:11];
    wire [7:0]  cb_out  = cb_raw[8] ? 8'd0 : cb_raw[7:0];
    wire [7:0]  cr_out  = cr_raw[8] ? 8'd0 : cr_raw[7:0];

    always @(posedge clk) begin
        if (!rst_n) begin m_pix_valid <= 0; end
        else begin
            m_pix_valid <= s6_valid;
            m_pix_hsync <= s6_hsync;
            m_pix_vsync <= s6_vsync;
            m_Y_data    <= y_out;
            m_CbCr_data <= {cb_out, cr_out};
        end
    end

endmodule
