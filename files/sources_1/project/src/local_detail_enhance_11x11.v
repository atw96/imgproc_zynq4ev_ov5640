// =============================================================================
// local_detail_enhance_11x11.v  (v2)
// Local Adaptive Wiener Detail Enhancement  — 11×11 window
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// ── Three Defects Fixed in v2 ────────────────────────────────────────────────
//
//  DEFECT-1 FIX — Horizontal Edge Padding
//    The column sliding-window FIFO (csf[], sqf[]) previously contained zeros
//    for the first 10 column positions (left edge), causing incorrect μ/σ²
//    estimates near the left border.  Similarly, the last 5 column positions
//    are affected at the right border.
//
//    Fix strategy — replicate-pad:
//      LEFT  edge (col_x < PAD_SIZE):
//        When the FIFO does not yet contain PAD_SIZE entries, subtracting the
//        oldest FIFO entry would remove a zero.  Instead we use the CURRENT
//        col_sum/col_sq as the "old" entry (i.e., effectively the incoming
//        column is counted an extra time), matching the replicate-pad semantics.
//
//      RIGHT edge (col_x > LINE_LEN - 1 - PAD_SIZE):
//        After the last real column, the window tries to include columns that
//        do not exist.  We replicate the CURRENT column's value by NOT
//        subtracting the exiting FIFO entry (same trick as left edge).
//        The right-edge detection uses the col_x passed downstream (rs_x).
//        Because the sliding window is 11 wide, the last 5 columns in the
//        image would benefit; we apply the clamp for the last PAD_SIZE columns.
//        NOTE: exact replicate behaviour requires knowing LINE_LEN; the check
//        rs_x >= LINE_LEN - PAD_SIZE is evaluated at PIPE-2 timing using rs_x.
//
//  DEFECT-2 FIX — Memory / Control Decoupling
//    k-LUT: Previously a (* ram_style="block" *) array inferred inside this
//    module's always block, mixing BRAM initialisation with control FSM logic.
//    Now instantiated as a separate k_lut_rom module.  The s(Y) LUT was already
//    decoupled via ram_sp_bram; no change needed there.
//
//  DEFECT-3 FIX — Redundant Pipeline Delay Elimination
//    Every pipeline stage (S1…S9) manually propagated _x and _y coordinate
//    registers through 9 pairs of 11-bit registers (18 × 11 = 198 FFs).
//    Replaced with two shift_reg instances of depth = PIPE_DEPTH (11 cycles
//    from col_valid to output register).  Vivado maps these to SRL16/SRL32
//    primitives inside SLICEM (~22 FFs equivalent vs 198 FFs, ~89% saving).
//
//    PIPE_DEPTH = 11:
//      PIPE-1  col_sum adder tree: 3 stages (S1, S2, S3)
//      PIPE-2  row FIFO sliding sum:       1 stage  (rs)
//      PIPE-3  1/121 multiply (μ, E[y²]):  1 stage  (e)
//      PIPE-4  variance σ²:                1 stage  (v)
//      PIPE-5  k-LUT read:                 1 stage  (k)
//      PIPE-6  base layer y_bp:            1 stage  (ybp)
//      PIPE-7  detail layer yt:            1 stage  (yt)
//      PIPE-8  s(Y) LUT read:             1 stage  (sy)
//      PIPE-9  enhancement product:        1 stage  (ep)
//      Output register:                    1 stage
//      Total = 3+1+1+1+1+1+1+1+1 = 11  → shift_reg DEPTH = 11
//
// ── Algorithm (unchanged from v1) ──────────────────────────────────────────
//   Faithful RTL of se_ver2.m (11×11 Wiener adaptive sharpening):
//   Step 1 : μ, σ²   via column-accumulator decomposition
//   Step 2 : k = σ² / (σ² + σ_n²) from BRAM LUT
//   Step 3 : y_bp = k·μ + (1−k)·y
//   Step 4 : yt = max(y − y_bp, PARA_3)
//   Step 5 : out = clamp(y + yt · s(y), 0, 8191)
// =============================================================================

`timescale 1ns/1ps

module local_detail_enhance_11x11 #(
    parameter PIXEL_W       = 13,
    parameter WIN_SIZE      = 11,
    parameter LINE_LEN      = 2048,
    parameter [13:0] INV_WIN_SQ   = 14'd8666,    // round(2^20 / 121)
    parameter signed [13:0] PARA3 = -14'sd256,   // −0.03125 in Q1.13
    parameter [25:0] SIGMA_N_SQ   = 26'd1536,    // σ_n² in Q0.26
    parameter [8:0]  SIGMA_STEPS  = 9'd6         // 1536/256 = 6
)(
    input  wire                          clk,
    input  wire                          rst_n,

    // Window input (from line_buffer_ctrl, 11 rows × PIXEL_W)
    input  wire [PIXEL_W*WIN_SIZE-1:0]   col_pixels,
    input  wire                          col_valid,
    input  wire [10:0]                   col_x,
    input  wire [10:0]                   col_y,
    input  wire                          col_sof,

    // Centre pixel (row 5 of the 11-row window)
    input  wire [PIXEL_W-1:0]            centre_pix,

    // s(Y) LUT write port (loaded from AXI4-Lite)
    input  wire [PIXEL_W-1:0]            lut_wr_data,
    input  wire [9:0]                    lut_wr_addr,
    input  wire                          lut_wr_en,

    // Enhanced output
    output reg  [PIXEL_W-1:0]            m_enh_data,
    output reg                           m_enh_valid,
    output reg  [10:0]                   m_enh_x,
    output reg  [10:0]                   m_enh_y,
    output reg                           m_enh_sof
);

    // =========================================================================
    // Derived constants
    // =========================================================================
    localparam PAD_SIZE  = WIN_SIZE / 2;          // = 5
    localparam ADDR_W_LB = $clog2(LINE_LEN);      // = 11
    // Total pipeline depth from col_valid input to m_enh_valid output
    localparam PIPE_DEPTH = 11;
    // ep_valid is 11 stages from col_valid (s1..ep). shift_reg DEPTH=11 aligns
    // dly_* with ep_valid in the output always; both then get +1 to m_enh_*.
    // (Header "Total=11 includes output" was wrong — that would be DEPTH=10.)

    // =========================================================================
    // Unpack 11 pixels from the column bus
    // =========================================================================
    wire [PIXEL_W-1:0] p[0:10];
    genvar gi;
    generate
        for (gi = 0; gi < WIN_SIZE; gi = gi + 1) begin : g_unpack
            assign p[gi] = col_pixels[gi*PIXEL_W +: PIXEL_W];
        end
    endgenerate

    // =========================================================================
    // DEFECT-3 FIX — Coordinate and control shift registers
    // Replace the 9-stage manual x/y/valid propagation with shift_reg instances.
    // =========================================================================
    wire [10:0] dly_x, dly_y;
    wire        dly_valid;
    wire        dly_sof;

    shift_reg #(.W(11),         .DEPTH(PIPE_DEPTH)) u_dly_x     (.clk(clk), .din(col_x),     .dout(dly_x));
    shift_reg #(.W(11),         .DEPTH(PIPE_DEPTH)) u_dly_y     (.clk(clk), .din(col_y),     .dout(dly_y));
    shift_reg #(.W(1),          .DEPTH(PIPE_DEPTH)) u_dly_valid (.clk(clk), .din(col_valid), .dout(dly_valid));
    shift_reg #(.W(1),          .DEPTH(PIPE_DEPTH)) u_dly_sof   (.clk(clk), .din(col_sof),   .dout(dly_sof));
    // Also delay centre_pix by PIPE_DEPTH to align with the output stage
    // Note: individual cen_at_pipeN shift registers are instantiated at each stage below.
    // (dly_centre removed — per-stage depths are more precise)

    // =========================================================================
    // PIPE-1: Column Sum — 11-input balanced adder tree  (3 register stages)
    // =========================================================================
    // Level-0 (combinational)
    wire [PIXEL_W:0] a0 = {1'b0,p[0]} + {1'b0,p[1]};
    wire [PIXEL_W:0] a1 = {1'b0,p[2]} + {1'b0,p[3]};
    wire [PIXEL_W:0] a2 = {1'b0,p[4]} + {1'b0,p[5]};
    wire [PIXEL_W:0] a3 = {1'b0,p[6]} + {1'b0,p[7]};
    wire [PIXEL_W:0] a4 = {1'b0,p[8]} + {1'b0,p[9]};

    // Level-1 (S1 registers)
    reg [PIXEL_W+1:0] b0, b1, b2;
    reg               s1_valid;

    always @(posedge clk) begin
        s1_valid <= col_valid;
        b0 <= {1'b0,a0} + {1'b0,a1};
        b1 <= {1'b0,a2} + {1'b0,a3};
        b2 <= {1'b0,a4} + {2'b0,p[10]};
    end

    // Level-2 (S2 registers)
    reg [PIXEL_W+2:0] c0;
    reg [PIXEL_W+1:0] c1;
    reg               s2_valid;

    always @(posedge clk) begin
        s2_valid <= s1_valid;
        c0 <= {1'b0,b0} + {1'b0,b1};
        c1 <= b2;
    end

    // Level-3 (col_sum)
    reg [PIXEL_W+3:0] col_sum_r;   // 17-bit: max 11×8191 = 90101
    reg               s3_valid;
    reg [10:0]        s3_x;        // used for horizontal edge detection

    always @(posedge clk) begin
        s3_valid <= s2_valid;
        // Capture col_x at S3 timing (shifted 3 cycles from input)
        // We use a 3-stage shift register for col_x to get the right timing.
        col_sum_r <= {1'b0,c0} + {2'b0,c1};
    end

    // Delay col_x by 3 cycles for s3_x (needed for edge detection at PIPE-2)
    wire [10:0] s3_x_wire;
    shift_reg #(.W(11), .DEPTH(3)) u_s3x (.clk(clk), .din(col_x), .dout(s3_x_wire));
    always @(posedge clk) s3_x <= s3_x_wire;

    // =========================================================================
    // PIPE-1b: Column Sum-of-Squares (parallel, aligned to S3)
    // Truncate each pixel to 7 MSBs for DSP budget (7×7 = 14-bit squares)
    // =========================================================================
    (* use_dsp = "yes" *)
    reg [13:0] sq[0:10];
    integer si;
    always @(posedge clk) begin
        for (si = 0; si < 11; si = si + 1)
            sq[si] <= p[si][PIXEL_W-1:PIXEL_W-7] * p[si][PIXEL_W-1:PIXEL_W-7];
    end

    reg [16:0] sq_s0, sq_s1, sq_s2, sq_s3;
    always @(posedge clk) begin
        sq_s0 <= {1'b0,sq[0]} + {1'b0,sq[1]} + {1'b0,sq[2]};
        sq_s1 <= {1'b0,sq[3]} + {1'b0,sq[4]} + {1'b0,sq[5]};
        sq_s2 <= {1'b0,sq[6]} + {1'b0,sq[7]} + {1'b0,sq[8]};
        sq_s3 <= {1'b0,sq[9]} + {1'b0,sq[10]};
    end

    reg [18:0] col_sq_r;   // 18-bit: max 11×127² = 177419
    always @(posedge clk) begin
        col_sq_r <= ({1'b0,sq_s0} + {1'b0,sq_s1}) + ({1'b0,sq_s2} + {2'b0,sq_s3});
    end
    // col_sq_r aligned with s3_valid and col_sum_r ✓

    // =========================================================================
    // PIPE-2: Horizontal sliding-window accumulator
    // DEFECT-1 FIX — Horizontal Edge Padding
    //
    // row_sum = Σ(last 11 col_sums)   [20-bit]
    // row_sq  = Σ(last 11 col_sqs)    [21-bit]
    //
    // Left-edge replicate: when rs_x < PAD_SIZE, the FIFO hasn't been filled
    // with real data yet.  Use the current column value as the "old" entry to
    // subtract (net effect: window fills with replicated first column).
    //
    // Right-edge replicate: when rs_x >= LINE_LEN - PAD_SIZE, the window
    // extends beyond the image.  Again use the current value as the subtractee
    // so the last valid column is effectively replicated.
    // =========================================================================
    reg [PIXEL_W+3:0] csf[0:10];  // col_sum FIFO, 17-bit entries
    reg [18:0]        sqf[0:10];  // col_sq  FIFO, 19-bit entries
    reg [3:0]         fifo_ptr;

    reg [PIXEL_W+6:0] row_sum;    // 20-bit
    reg [20:0]        row_sq;     // 21-bit
    reg               rs_valid;
    reg [10:0]        rs_x;

    // Edge detect (at S3 timing, before FIFO update):
    wire left_edge  = (s3_x < PAD_SIZE[10:0]);
    wire right_edge = (s3_x >= LINE_LEN[10:0] - PAD_SIZE[10:0]);
    wire edge_pad   = left_edge | right_edge;

    // When padding: don't subtract the outgoing FIFO entry — use current value.
    wire [PIXEL_W+3:0] old_col_sum = edge_pad ? col_sum_r : csf[fifo_ptr];
    wire [18:0]        old_col_sq  = edge_pad ? col_sq_r  : sqf[fifo_ptr];

    always @(posedge clk) begin
        if (!rst_n) begin
            row_sum  <= 0;  row_sq <= 0;  fifo_ptr <= 4'd0;
        end else if (s3_valid) begin
            row_sum  <= row_sum + {{3{1'b0}},col_sum_r} - {{3{1'b0}},old_col_sum};
            row_sq   <= row_sq  + {{2{1'b0}},col_sq_r}  - {{2{1'b0}},old_col_sq};
            csf[fifo_ptr] <= col_sum_r;
            sqf[fifo_ptr] <= col_sq_r;
            fifo_ptr <= (fifo_ptr == 4'd10) ? 4'd0 : fifo_ptr + 1;
        end
        rs_valid <= s3_valid;
        rs_x     <= s3_x;
    end

    // =========================================================================
    // PIPE-3: Mean μ and E[y²] via multiplication by INV_WIN_SQ (1/121 Q0.20)
    // =========================================================================
    (* use_dsp = "yes" *)
    reg [33:0] mu_raw;
    reg [34:0] e2_raw;
    reg        e_valid;

    always @(posedge clk) begin
        e_valid  <= rs_valid;
        mu_raw  <= row_sum * INV_WIN_SQ;
        e2_raw  <= {1'b0,row_sq} * INV_WIN_SQ;
    end

    wire [PIXEL_W-1:0] mu_q13 = mu_raw[PIXEL_W-1+20 : 20];
    wire [PIXEL_W-1:0] e2_q13 = e2_raw[PIXEL_W-1+20 : 20];

    // =========================================================================
    // PIPE-4: Variance  σ² = E[y²] − μ²   (Q0.26, clipped to 0)
    // =========================================================================
    (* use_dsp = "yes" *)
    reg [25:0] mu_sq;
    reg        v_valid;
    reg [PIXEL_W-1:0] v_mu, v_e2;

    always @(posedge clk) begin
        v_valid <= e_valid;
        v_mu    <= mu_q13;  v_e2 <= e2_q13;
        mu_sq   <= mu_q13 * mu_q13;
    end

    wire [25:0] e2_q26  = {v_e2, 13'b0};
    wire [25:0] var_q26 = (e2_q26 > mu_sq) ? e2_q26 - mu_sq : 26'd0;

    // =========================================================================
    // PIPE-5: Wiener weight  k = σ²/(σ²+σ_n²)
    // DEFECT-2 FIX — k_lut_rom instantiated as separate module
    // =========================================================================
    wire [8:0]  k_lut_addr = var_q26[16:8];
    wire [12:0] k_rom_out;

    k_lut_rom u_k_lut (
        .clk  (clk),
        .addr (k_lut_addr),
        .dout (k_rom_out)
    );

    reg [12:0] k_val;
    reg        k_valid;
    reg [PIXEL_W-1:0] k_mu;

    always @(posedge clk) begin
        k_valid <= v_valid;
        k_val   <= k_rom_out;
        k_mu    <= v_mu;
    end

    // =========================================================================
    // PIPE-6: Base layer  y_bp = k·μ + (1−k)·y
    // Registered at posedge cy8; centre_pix[cy0] needed → depth=8
    // =========================================================================
    (* use_dsp = "yes" *)
    reg [25:0] ybp_t1, ybp_t2;
    reg        ybp_valid;

    wire [12:0] one_minus_k = 13'd8192 - k_val;

    wire [PIXEL_W-1:0] cen_at_pipe6;
    shift_reg #(.W(PIXEL_W), .DEPTH(8)) u_cen6 (
        .clk(clk), .din(centre_pix), .dout(cen_at_pipe6));

    always @(posedge clk) begin
        ybp_valid <= k_valid;
        ybp_t1    <= k_val       * k_mu;
        ybp_t2    <= one_minus_k * cen_at_pipe6;
    end

    wire [25:0] ybp_q26 = ybp_t1 + ybp_t2;
    wire [12:0] ybp_q13 = ybp_q26[25:13];

    // =========================================================================
    // PIPE-7: Detail layer  yt = y − y_bp,  clipped at PARA_3
    // Registered at posedge cy9; centre_pix[cy0] needed → depth=9
    // =========================================================================
    reg signed [13:0] yt_r;
    reg               yt_valid;

    wire [PIXEL_W-1:0] cen_at_pipe7;
    shift_reg #(.W(PIXEL_W), .DEPTH(9)) u_cen7 (
        .clk(clk), .din(centre_pix), .dout(cen_at_pipe7));

    wire signed [13:0] yt_raw = $signed({1'b0, cen_at_pipe7}) - $signed({1'b0, ybp_q13});

    always @(posedge clk) begin
        yt_valid <= ybp_valid;
        yt_r     <= (yt_raw < $signed(PARA3)) ? $signed(PARA3) : yt_raw;
    end

    // =========================================================================
    // PIPE-8: s(Y) LUT lookup  (ram_sp_bram — already decoupled in v1)
    // sy_addr driven by cen_at_pipe8 at cy8 → BRAM output valid cy9
    // sy_valid/sy_yt registered at cy10 (from yt_valid@cy9)
    // =========================================================================
    wire [PIXEL_W-1:0] cen_at_pipe8;
    shift_reg #(.W(PIXEL_W), .DEPTH(8)) u_cen8 (
        .clk(clk), .din(centre_pix), .dout(cen_at_pipe8));

    wire [9:0] sy_addr = cen_at_pipe8[PIXEL_W-1 : PIXEL_W-10];

    wire [PIXEL_W-1:0] sy_rdata;

    ram_sp_bram #(
        .DATA_W  (PIXEL_W),
        .DEPTH   (1024),
        .ADDR_W  (10),
        .WR_MODE (2)
    ) u_sy_lut (
        .clk  (clk),
        .en   (1'b1),
        .we   (lut_wr_en),
        .addr (lut_wr_en ? lut_wr_addr : sy_addr),
        .wdata(lut_wr_data),
        .rdata(sy_rdata)
    );

    reg               sy_valid;
    reg signed [13:0] sy_yt;

    always @(posedge clk) begin
        sy_valid <= yt_valid;
        sy_yt    <= yt_r;
    end

    // =========================================================================
    // PIPE-9: Enhancement product  temp3 = yt × mat_sy
    // Registered at cy10; eyt_clamp uses cen_at_pipe9 (centre_pix[cy0] at cy10 → depth=10)
    // =========================================================================
    wire [PIXEL_W-1:0] cen_at_pipe9;
    shift_reg #(.W(PIXEL_W), .DEPTH(10)) u_cen9 (
        .clk(clk), .din(centre_pix), .dout(cen_at_pipe9));

    (* use_dsp = "yes" *)
    reg signed [26:0] enh_prod;
    reg               ep_valid;

    always @(posedge clk) begin
        ep_valid <= sy_valid;
        enh_prod <= $signed(sy_yt) * $signed({1'b0, sy_rdata});
    end

    // Extract fractional part (Q1.13)
    wire signed [13:0] temp5  = $signed({enh_prod[26], enh_prod[12:0]});
    wire signed [14:0] eyt_s  = $signed({1'b0, cen_at_pipe9}) + $signed({temp5[13], temp5});

    // Clamp to [0, 8191]
    wire [PIXEL_W-1:0] eyt_clamp =
        eyt_s[14]                   ? {PIXEL_W{1'b0}} :
        (eyt_s[13:0] >= 14'd8192)   ? 13'h1FFF        :
        eyt_s[12:0];

    // =========================================================================
    // Output register (cy11) — x/y/valid from shift_reg (DEFECT-3 FIX)
    // =========================================================================
    always @(posedge clk) begin
        if (!rst_n) begin
            m_enh_valid <= 1'b0;
            m_enh_sof   <= 1'b0;
        end else begin
            m_enh_valid <= ep_valid;
            m_enh_x     <= dly_x;
            m_enh_y     <= dly_y;
            m_enh_sof   <= dly_sof & ep_valid;
            m_enh_data  <= eyt_clamp;
        end
    end

endmodule
