//=============================================================================
// img_preprocessor.v
// Full ISP Front-End: RAW Bayer → Preprocessed Y + CbCr + RGB
// Academic Research Demo — Zynq UltraScale+ (AXU4EVB)
//
// Pipeline: Dead-pixel → BL → Demosaic (edge pad) → WB → Gamma RGB → YCbCr
//=============================================================================

`timescale 1ns/1ps

module img_preprocessor #(
    parameter PIXEL_W  = 13,
    parameter LINE_LEN = 2048,
    parameter ADDR_W   = $clog2(LINE_LEN)
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire [PIXEL_W-1:0]   s_raw_data,
    input  wire                 s_raw_valid,
    input  wire                 s_raw_hsync,
    input  wire                 s_raw_vsync,
    output wire                 s_raw_ready,

    output reg  [PIXEL_W-1:0]   m_Y_data,
    output reg  [15:0]          m_CbCr_data,
    output reg  [PIXEL_W-1:0]   m_R_data,
    output reg  [PIXEL_W-1:0]   m_G_data,
    output reg  [PIXEL_W-1:0]   m_B_data,
    output reg                  m_pix_valid,
    output reg                  m_pix_hsync,
    output reg                  m_pix_vsync,

    input  wire [PIXEL_W-1:0]   lut_wr_data,
    input  wire [7:0]           lut_wr_addr,
    input  wire                 lut_wr_en,

    input  wire [11:0]          wb_gain_r,
    input  wire [11:0]          wb_gain_g,
    input  wire [11:0]          wb_gain_b,

    input  wire [PIXEL_W-1:0]   black_level,
    input  wire [1:0]           bayer_fmt, // reserved (RGGB via row/col parity)

    output reg  [31:0]          dead_pixel_cnt
);

    assign s_raw_ready = 1'b1;
    wire _unused_bayer = |bayer_fmt;

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
                if (s_raw_hsync) s1_prev <= 13'h0FFF;
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
    reg [ADDR_W-1:0]  s2_col;
    reg [10:0]        s2_row;

    always @(posedge clk) begin
        s2_valid <= s1_valid; s2_hsync <= s1_hsync; s2_vsync <= s1_vsync;
        s2_rpar  <= s1_rpar;  s2_cpar  <= s1_cpar;
        s2_data  <= bl_diff[PIXEL_W] ? {PIXEL_W{1'b0}} : bl_diff[PIXEL_W-1:0];
        if (!rst_n) begin
            s2_col <= {ADDR_W{1'b0}};
            s2_row <= 11'd0;
        end else if (s1_valid) begin
            if (s1_vsync) begin
                s2_col <= {ADDR_W{1'b0}};
                s2_row <= 11'd0;
            end else if (s1_hsync) begin
                s2_col <= {ADDR_W{1'b0}};
                s2_row <= s2_row + 11'd1;
            end else begin
                s2_col <= s2_col + 1'b1;
            end
        end
    end

    //==========================================================================
    // S3: Bayer Demosaic — 3×3 bilinear + replicate-pad edges
    //==========================================================================
    wire [PIXEL_W-1:0] lbn_rd, lbm_rd, lbo_rd;
    wire               lbn_vld, lbm_vld, lbo_vld;

    reg [ADDR_W-1:0]   lb_wcnt;
    reg [ADDR_W-1:0]   lb_rcnt;
    reg [ADDR_W-1:0]   lb_rcnt_d1;
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

    ram_sdp_bram #(.DATA_W(PIXEL_W),.DEPTH(LINE_LEN),.ADDR_W(ADDR_W),.DO_REG(0)) u_lbn (
        .clk_w(clk),.we(s2_valid),.waddr(lb_wcnt),.wdata(s2_data),
        .clk_r(clk),.re(lb_re),.raddr(lb_rcnt),.rdata(lbn_rd),.rdata_vld(lbn_vld));

    ram_sdp_bram #(.DATA_W(PIXEL_W),.DEPTH(LINE_LEN),.ADDR_W(ADDR_W),.DO_REG(0)) u_lbm (
        .clk_w(clk),.we(lbn_vld),.waddr(lb_rcnt_d1),.wdata(lbn_rd),
        .clk_r(clk),.re(lb_re),.raddr(lb_rcnt),.rdata(lbm_rd),.rdata_vld(lbm_vld));

    ram_sdp_bram #(.DATA_W(PIXEL_W),.DEPTH(LINE_LEN),.ADDR_W(ADDR_W),.DO_REG(0)) u_lbo (
        .clk_w(clk),.we(lbm_vld),.waddr(lb_rcnt_d1),.wdata(lbm_rd),
        .clk_r(clk),.re(lb_re),.raddr(lb_rcnt),.rdata(lbo_rd),.rdata_vld(lbo_vld));

    reg [1:0] rpar_sr, cpar_sr, valid_sr, hsync_sr, vsync_sr;
    reg [ADDR_W-1:0] col_sr0, col_sr1;
    reg [10:0]       row_sr0, row_sr1;

    always @(posedge clk) begin
        rpar_sr  <= {rpar_sr[0],  s2_rpar};
        cpar_sr  <= {cpar_sr[0],  s2_cpar};
        valid_sr <= {valid_sr[0], lbo_vld};
        hsync_sr <= {hsync_sr[0], s2_hsync};
        vsync_sr <= {vsync_sr[0], s2_vsync};
        col_sr0  <= s2_col;
        col_sr1  <= col_sr0;
        row_sr0  <= s2_row;
        row_sr1  <= row_sr0;
    end

    reg [PIXEL_W-1:0] lbn_prev, lbm_prev, lbo_prev;
    always @(posedge clk) begin
        if (lbn_vld) begin
            lbn_prev <= lbn_rd;
            lbm_prev <= lbm_rd;
            lbo_prev <= lbo_rd;
        end
    end

    // Replicate-pad: left edge (col==0 / hsync), top rows (row<2)
    wire left_edge = hsync_sr[1] || (col_sr1 == {ADDR_W{1'b0}});
    wire top_edge  = (row_sr1 < 11'd2);

    wire [PIXEL_W-1:0] lbn_w = left_edge ? lbn_rd : lbn_prev;
    wire [PIXEL_W-1:0] lbm_w = left_edge ? lbm_rd : lbm_prev;
    wire [PIXEL_W-1:0] lbo_w = left_edge ? lbo_rd : lbo_prev;

    wire [PIXEL_W-1:0] lbo_c = top_edge ? lbm_rd : lbo_rd;
    wire [PIXEL_W-1:0] lbo_wp = top_edge ? lbm_w : lbo_w;

    wire [PIXEL_W+1:0] avg_NS     = {2'b0,lbo_c}   + {2'b0,lbn_rd};
    wire [PIXEL_W+1:0] avg_WE_mid = {2'b0,lbm_w}   + {2'b0,lbm_rd};
    wire [PIXEL_W+2:0] avg_diag   = {2'b0,lbo_wp}  + {2'b0,lbo_c}
                                  + {2'b0,lbn_w}   + {2'b0,lbn_rd};
    wire [PIXEL_W+2:0] avg_cross  = {2'b0,lbo_c}   + {2'b0,lbn_rd}
                                  + {2'b0,lbm_w}   + {2'b0,lbm_rd};

    reg [PIXEL_W-1:0] s3_R, s3_G, s3_B;
    reg               s3_valid, s3_hsync, s3_vsync;

    always @(posedge clk) begin
        s3_valid <= valid_sr[1];
        s3_hsync <= hsync_sr[1];
        s3_vsync <= vsync_sr[1];
        // bayer_fmt reserved; RGGB via row/col parity
        case ({rpar_sr[1], cpar_sr[1]})
            2'b00: begin
                s3_R <= lbm_rd;
                s3_G <= avg_cross[PIXEL_W+1:2];
                s3_B <= avg_diag[PIXEL_W+1:2];
            end
            2'b01: begin
                s3_R <= avg_WE_mid[PIXEL_W:1];
                s3_G <= lbm_rd;
                s3_B <= avg_NS[PIXEL_W:1];
            end
            2'b10: begin
                s3_R <= avg_NS[PIXEL_W:1];
                s3_G <= lbm_rd;
                s3_B <= avg_WE_mid[PIXEL_W:1];
            end
            2'b11: begin
                s3_R <= avg_diag[PIXEL_W+1:2];
                s3_G <= avg_cross[PIXEL_W+1:2];
                s3_B <= lbm_rd;
            end
        endcase
    end

    //==========================================================================
    // S4: White Balance
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
    // S5: Gamma Correction — R/G/B each with INIT_FILE gamma22_13b.mem
    //==========================================================================
    wire [7:0]          ga_R = s4_R[PIXEL_W-1:PIXEL_W-8];
    wire [7:0]          ga_G = s4_G[PIXEL_W-1:PIXEL_W-8];
    wire [7:0]          ga_B = s4_B[PIXEL_W-1:PIXEL_W-8];
    wire [PIXEL_W-1:0]  go_R_lut, go_G_lut, go_B_lut;

    ram_sp_bram #(
        .DATA_W(PIXEL_W), .DEPTH(256), .ADDR_W(8), .WR_MODE(2),
        .INIT_FILE("gamma22_13b.mem")
    ) u_gamma_r (
        .clk(clk), .en(1'b1),
        .we(lut_wr_en), .addr(lut_wr_en ? lut_wr_addr : ga_R),
        .wdata(lut_wr_data), .rdata(go_R_lut));

    ram_sp_bram #(
        .DATA_W(PIXEL_W), .DEPTH(256), .ADDR_W(8), .WR_MODE(2),
        .INIT_FILE("gamma22_13b.mem")
    ) u_gamma_g (
        .clk(clk), .en(1'b1),
        .we(lut_wr_en), .addr(lut_wr_en ? lut_wr_addr : ga_G),
        .wdata(lut_wr_data), .rdata(go_G_lut));

    ram_sp_bram #(
        .DATA_W(PIXEL_W), .DEPTH(256), .ADDR_W(8), .WR_MODE(2),
        .INIT_FILE("gamma22_13b.mem")
    ) u_gamma_b (
        .clk(clk), .en(1'b1),
        .we(lut_wr_en), .addr(lut_wr_en ? lut_wr_addr : ga_B),
        .wdata(lut_wr_data), .rdata(go_B_lut));

    reg [PIXEL_W-1:0] s4_R_d1, s4_G_d1, s4_B_d1;
    reg               lut_ever_wr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            s4_R_d1 <= {PIXEL_W{1'b0}};
            s4_G_d1 <= {PIXEL_W{1'b0}};
            s4_B_d1 <= {PIXEL_W{1'b0}};
            lut_ever_wr <= 1'b0;
        end else begin
            s4_R_d1 <= s4_R;
            s4_G_d1 <= s4_G;
            s4_B_d1 <= s4_B;
            if (lut_wr_en)
                lut_ever_wr <= 1'b1;
        end
    end

    wire [PIXEL_W-1:0] go_R_eff = (lut_ever_wr || (|go_R_lut)) ? go_R_lut : s4_R_d1;
    wire [PIXEL_W-1:0] go_G_eff = (lut_ever_wr || (|go_G_lut)) ? go_G_lut : s4_G_d1;
    wire [PIXEL_W-1:0] go_B_eff = (lut_ever_wr || (|go_B_lut)) ? go_B_lut : s4_B_d1;

    reg               s5_valid, s5_hsync, s5_vsync;
    reg [PIXEL_W-1:0] s5_R, s5_G, s5_B;
    always @(posedge clk) begin
        s5_valid <= s4v2; s5_hsync <= s4h2; s5_vsync <= s4vs2;
        s5_R <= go_R_eff; s5_G <= go_G_eff; s5_B <= go_B_eff;
    end

    //==========================================================================
    // S6: RGB → YCbCr (BT.601)
    //==========================================================================
    (* use_dsp = "yes" *)
    reg [22:0] s6_YR, s6_YG, s6_YB;
    reg [22:0] s6_CBB, s6_CBR, s6_CBG;
    reg [22:0] s6_CRR, s6_CRG, s6_CRB;
    reg        s6_valid, s6_hsync, s6_vsync;
    reg [PIXEL_W-1:0] s6_R, s6_G, s6_B;

    always @(posedge clk) begin
        s6_valid <= s5_valid; s6_hsync <= s5_hsync; s6_vsync <= s5_vsync;
        s6_R <= s5_R; s6_G <= s5_G; s6_B <= s5_B;
        s6_YR  <= s5_R * 23'd306;  s6_YG  <= s5_G * 23'd601;  s6_YB  <= s5_B * 23'd117;
        s6_CBR <= s5_R * 23'd173;  s6_CBG <= s5_G * 23'd339;  s6_CBB <= s5_B * 23'd512;
        s6_CRR <= s5_R * 23'd512;  s6_CRG <= s5_G * 23'd429;  s6_CRB <= s5_B * 23'd83;
    end

    wire [23:0] y_sum  = s6_YR + s6_YG + s6_YB;
    wire [23:0] cb_pos = {1'b0, s6_CBB};
    wire [23:0] cb_neg = {1'b0, s6_CBR} + {1'b0, s6_CBG};
    wire [23:0] cr_pos = {1'b0, s6_CRR};
    wire [23:0] cr_neg = {1'b0, s6_CRG} + {1'b0, s6_CRB};

    wire [12:0] y_out   = y_sum[22:10];
    wire [8:0]  cb_raw  = 9'd128 + cb_pos[19:11] - cb_neg[19:11];
    wire [8:0]  cr_raw  = 9'd128 + cr_pos[19:11] - cr_neg[19:11];
    wire [7:0]  cb_out  = cb_raw[8] ? 8'd0 : cb_raw[7:0];
    wire [7:0]  cr_out  = cr_raw[8] ? 8'd0 : cr_raw[7:0];

    always @(posedge clk) begin
        if (!rst_n) begin
            m_pix_valid <= 0;
        end else begin
            m_pix_valid <= s6_valid;
            m_pix_hsync <= s6_hsync;
            m_pix_vsync <= s6_vsync;
            m_Y_data    <= y_out;
            m_CbCr_data <= {cb_out, cr_out};
            m_R_data    <= s6_R;
            m_G_data    <= s6_G;
            m_B_data    <= s6_B;
        end
    end

endmodule
