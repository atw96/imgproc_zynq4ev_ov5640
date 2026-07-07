// =============================================================================
// clahe_engine.v  (v2)
// CLAHE — Contrast-Limited Adaptive Histogram Equalisation
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// ── Defect-2 Fix: Memory / Control Decoupling ────────────────────────────────
//
// Original design embedded both `hist_ram` (256×16b BRAM) and `cdf_lut`
// (256×13b distributed RAM) directly inside the FSM always block, making it
// difficult to:
//   • Reason about BRAM read/write timing independently of FSM transitions
//   • Replace the histogram memory (e.g., with an SDP BRAM for better timing)
//   • Port to a different FPGA or verify in isolation
//
// Fixed design separates memory into distinct instantiated sub-modules:
//   hist_bram  — wraps ram_sp_bram (READ_FIRST mode for read-modify-write)
//   cdf_lut    — inline distributed RAM (256×13b, small enough for LUTRAM)
//
// The FSM drives explicit read-enable, write-enable, address, and data ports
// on each memory instance.  All control logic is contained in the FSM;
// the memory instances contain no FSM state.
//
// ── Architecture Reminder ────────────────────────────────────────────────────
//   FSM: COLLECT → CLIP → CDF → MAP  (per 32×32-pixel tile)
//
//   COLLECT: Read-modify-write histogram (1-cycle BRAM latency handled by
//            forwarding register that detects back-to-back same-bin writes).
//   CLIP   : Walk 256 bins, clamp counts > clip_lim  (256 cycles).
//   CDF    : Accumulate clipped histogram into normalised CDF map (256 cycles).
//   MAP    : Look up each pixel in cdf_lut (1-cycle latency).
//
// ── Parameters (same as v1) ──────────────────────────────────────────────────
//   PIXEL_W    Pixel bit-width (default 13)
//   IMG_W/H    Frame size (default 2048×1080)
//   TILE_W/H   Tile size (default 32×32)
//   HIST_BITS  Log2(bins) (default 8 → 256 bins)
//   CLIP_LIMIT Histogram clip limit (default 40)
// =============================================================================

`timescale 1ns / 1ps

module clahe_engine #(
    parameter PIXEL_W    = 13,
    parameter IMG_W      = 2048,
    parameter IMG_H      = 1080,
    parameter TILE_W     = 32,
    parameter TILE_H     = 32,
    parameter HIST_BITS  = 8,
    parameter CLIP_LIMIT = 40,
    parameter NORM_FRAC  = 10
)(
    input  wire                  clk,
    input  wire                  rst_n,

    input  wire [PIXEL_W-1:0]    s_pix_data,
    input  wire                  s_pix_valid,
    output wire                  s_pix_ready,

    output reg  [PIXEL_W-1:0]    m_pix_data,
    output reg                   m_pix_valid,
    output reg                   m_pix_sof
);

    localparam HIST_BINS   = 1 << HIST_BITS;
    localparam TILE_PIXELS = TILE_W * TILE_H;
    localparam PIXEL_MAX   = (1 << PIXEL_W) - 1;
    localparam TILES_X = (IMG_W + TILE_W - 1) / TILE_W;
    localparam TILES_Y = (IMG_H + TILE_H - 1) / TILE_H;

    // =========================================================================
    // Tile pixel store — MAP replays pixels histogrammed in COLLECT
    // =========================================================================
    reg  [9:0]          tile_wa;
    reg  [PIXEL_W-1:0]  tile_wdata;
    reg                 tile_we;
    reg  [9:0]          tile_ra;
    wire [PIXEL_W-1:0]  tile_rdata;

    ram_sp_bram #(
        .DATA_W (PIXEL_W),
        .DEPTH  (TILE_PIXELS),
        .ADDR_W (10),
        .WR_MODE(0)
    ) u_tile_mem (
        .clk   (clk),
        .en    (1'b1),
        .we    (tile_we),
        .addr  (tile_we ? tile_wa : tile_ra),
        .wdata (tile_wdata),
        .rdata (tile_rdata)
    );

    reg [5:0]  cur_tile_x;
    reg [5:0]  cur_tile_y;
    reg [9:0]  map_idx;
    reg        map_armed;
    localparam ST_COLLECT = 2'd0;
    localparam ST_CLIP    = 2'd1;
    localparam ST_CDF     = 2'd2;
    localparam ST_MAP     = 2'd3;

    reg [1:0] state;

    // =========================================================================
    // Bin address helper
    // =========================================================================
    wire [HIST_BITS-1:0] pix_bin = s_pix_data[PIXEL_W-1 : PIXEL_W-HIST_BITS];

    // =========================================================================
    // DEFECT-2 FIX — hist_bram decoupled as ram_sp_bram instance
    //
    // Uses READ_FIRST mode (WR_MODE=0) so that the old count is read on the
    // same cycle as a write — correct read-modify-write without an extra cycle.
    // =========================================================================
    reg  [HIST_BITS-1:0] hist_addr;
    reg  [15:0]          hist_wdata;
    reg                  hist_we;
    wire [15:0]          hist_rdata;

    ram_sp_bram #(
        .DATA_W  (16),
        .DEPTH   (HIST_BINS),
        .ADDR_W  (HIST_BITS),
        .WR_MODE (0)           // READ_FIRST — read old value before write
    ) u_hist_bram (
        .clk   (clk),
        .en    (1'b1),
        .we    (hist_we),
        .addr  (hist_addr),
        .wdata (hist_wdata),
        .rdata (hist_rdata)
    );

    // =========================================================================
    // CDF LUT — 256 × PIXEL_W-bit  (distributed RAM, small enough for LUTRAM)
    // DEFECT-2 FIX — named as a distinct memory with explicit ports
    // =========================================================================
    (* ram_style = "distributed" *)
    reg [PIXEL_W-1:0] cdf_lut [0:HIST_BINS-1];

    // Write port (driven from CDF state)
    reg [HIST_BITS-1:0] cdf_wr_addr;
    reg [PIXEL_W-1:0]   cdf_wr_data;
    reg                 cdf_we;

    // Read port (driven from MAP state, 1-cycle latency for dist-RAM)
    reg [HIST_BITS-1:0] cdf_rd_addr;
    wire [PIXEL_W-1:0]  cdf_rd_data;

    always @(posedge clk) begin
        if (cdf_we)
            cdf_lut[cdf_wr_addr] <= cdf_wr_data;
    end
    // Distributed RAM read (synchronous 1-cycle read, same as BRAM)
    reg [PIXEL_W-1:0] cdf_rd_data_r;
    always @(posedge clk)
        cdf_rd_data_r <= cdf_lut[cdf_rd_addr];
    assign cdf_rd_data = cdf_rd_data_r;

    // =========================================================================
    // Counters and control registers
    // =========================================================================
    reg [9:0]               tile_pix_cnt;
    reg [HIST_BITS-1:0]     proc_bin;
    reg [15:0]              cdf_accum;
    reg [15:0]              cdf_min;
    reg                     cdf_min_found;
    reg [15:0]              tile_total;
    reg [7:0]               clip_lim;
    reg [HIST_BITS-1:0]     map_px_bin;
    // pipeline the calculation of cdf_range and normalised CDF to meet timing
    reg [15:0]              cdf_hist_r;        // Pipe1 register to hold hist_rdata for CDF calculation
    reg [31:0]              cdf_range_r;       // Pipe2 calculate cdf_range = (cdf_accum + hist_rdata) - cdf_min
    reg [31:0]              cdf_prod_r;        // Pipe3 calculate product = cdf_range * PIXEL_MAX
    reg [HIST_BITS-1:0]     cdf_wa_p2, cdf_wa_p3, cdf_wa_p4;      // Addr pipeline for CDF LUT write address
    reg                     cdf_we_p2, cdf_we_p3, cdf_we_p4;      // Write enable pipeline for CDF LUT write enable
    reg [15:0]              cdf_accum_r;       // Accum register for CDF calculation (holds cdf_accum for next cycle's calculation)
    reg [15:0]              cdf_min_r;         // Register to hold cdf_min for CDF calculation (to meet timing)
    reg [15:0]              denom;

    initial clip_lim = CLIP_LIMIT[7:0];

    // =========================================================================
    // COLLECT — read-modify-write forwarding register
    // hist_bram is READ_FIRST: rdata holds the value BEFORE the write.
    // Forwarding handles back-to-back accesses to the same bin.
    // =========================================================================
    reg                     fwd_valid;
    reg [HIST_BITS-1:0]     fwd_bin;
    reg [15:0]              fwd_val;
    reg [HIST_BITS-1:0]     rd_bin_d;
    reg                     rd_vld_d;

    wire use_fwd    = fwd_valid && (fwd_bin == rd_bin_d);
    wire [15:0] rmw_base = use_fwd ? fwd_val : hist_rdata;

    // =========================================================================
    // Pixel coordinate tracking (for tile boundary detection)
    // =========================================================================
    reg [10:0] px_col;
    reg [10:0] px_row;

    always @(posedge clk) begin
        if (!rst_n) begin
            px_col <= 11'd0;
            px_row <= 11'd0;
        end else if (s_pix_valid && s_pix_ready && state == ST_COLLECT) begin
            if (px_col == IMG_W[10:0] - 1) begin
                px_col <= 11'd0;
                px_row <= (px_row == IMG_H[10:0] - 1) ? 11'd0 : px_row + 1;
            end else begin
                px_col <= px_col + 1;
            end
        end
    end

    wire tile_end = s_pix_valid && s_pix_ready && (state == ST_COLLECT) &&
                   (tile_pix_cnt == TILE_PIXELS[9:0] - 1);

    assign s_pix_ready = (state == ST_COLLECT);

    // clr_active/clr_bin: background histogram zero-fill after CDF→MAP transition.
    // Declared here and driven ONLY inside the main FSM always block below to
    // avoid multi-driver on hist_we.
    reg        clr_active;
    reg [7:0]  clr_bin;

    // =========================================================================
    // Main FSM — now drives explicit memory ports (DEFECT-2 FIX)
    // =========================================================================
    integer ci;

    always @(posedge clk) begin
        if (!rst_n) begin
            state         <= ST_COLLECT;
            tile_pix_cnt  <= 10'd0;
            proc_bin      <= {HIST_BITS{1'b0}};
            cdf_accum     <= 16'd0;
            cdf_min       <= 16'd0;
            cdf_min_found <= 1'b0;
            tile_total    <= 16'd0;
            m_pix_valid   <= 1'b0;
            m_pix_sof     <= 1'b0;
            m_pix_data    <= {PIXEL_W{1'b0}};
            tile_we     <= 1'b0;
            map_armed     <= 1'b0;
            map_idx       <= 10'd0;
            cur_tile_x    <= 6'd0;
            cur_tile_y    <= 6'd0;
            fwd_valid     <= 1'b0;
            rd_vld_d      <= 1'b0;
            clr_active    <= 1'b0;
            clr_bin       <= 8'd0;
            // On reset, start background clear so hist is guaranteed zero
            hist_we       <= 1'b0;
            hist_addr     <= {HIST_BITS{1'b0}};
            hist_wdata    <= 16'd0;
            cdf_we        <= 1'b0;
        end else begin
            // Default: no memory writes
            hist_we  <= 1'b0;
            cdf_we   <= 1'b0;

            m_pix_valid <= 1'b0;
            m_pix_sof   <= 1'b0;

            case (state)

                // -------------------------------------------------------------
                // ST_COLLECT
                // -------------------------------------------------------------
                ST_COLLECT: begin
                    map_armed <= 1'b0;

                    // Drive hist BRAM read address = current pixel bin
                    hist_addr <= pix_bin;
                    hist_we   <= 1'b0;

                    // Forwarding pipeline
                    rd_bin_d <= pix_bin;
                    rd_vld_d <= s_pix_valid && s_pix_ready;

                    // Write back incremented count one cycle after read
                    if (rd_vld_d) begin
                        hist_addr  <= rd_bin_d;
                        hist_wdata <= rmw_base + 16'd1;
                        hist_we    <= 1'b1;
                        fwd_valid  <= 1'b1;
                        fwd_bin    <= rd_bin_d;
                        fwd_val    <= rmw_base + 16'd1;
                    end else begin
                        fwd_valid <= 1'b0;
                    end

                    if (s_pix_valid && s_pix_ready) begin
                        tile_wa    <= tile_pix_cnt;
                        tile_wdata <= s_pix_data;
                        tile_we    <= 1'b1;
                        if (tile_end) begin
                            cur_tile_x   <= px_col[10:5];
                            cur_tile_y   <= px_row[10:5];
                            tile_pix_cnt <= 10'd0;
                            tile_total   <= {6'd0, tile_pix_cnt} + 16'd1;
                            proc_bin     <= {HIST_BITS{1'b0}};
                            state        <= ST_CLIP;
                        end else begin
                            tile_pix_cnt <= tile_pix_cnt + 1;
                        end
                    end
                end

                // -------------------------------------------------------------
                // ST_CLIP — walk 256 bins, clamp counts > clip_lim
                // Each iteration: read (hist_rdata from previous cycle) and
                // conditionally write the clamped value back.
                // -------------------------------------------------------------
                ST_CLIP: begin
                    fwd_valid <= 1'b0;
                    rd_vld_d  <= 1'b0;

                    // Read next bin (address issued this cycle, data next)
                    hist_addr <= proc_bin;
                    hist_we   <= 1'b0;

                    // hist_rdata holds the count for proc_bin-1 (1-cycle latency)
                    // Write-back with clamp for previous bin
                    if (proc_bin != {HIST_BITS{1'b0}}) begin
                        // Previous bin's count is in hist_rdata
                        if (hist_rdata > {8'd0, clip_lim}) begin
                            // Write clamped value back to previous address
                            hist_addr  <= proc_bin - 1;
                            hist_wdata <= {8'd0, clip_lim};
                            hist_we    <= 1'b1;
                        end
                    end

                    proc_bin <= proc_bin + 1;

                    if (proc_bin == {HIST_BITS{1'b1}}) begin
                        // Handle last bin: read was issued, write-back next cycle
                        // (below handles the final bin clamping)
                        proc_bin      <= {HIST_BITS{1'b0}};
                        cdf_accum     <= 16'd0;
                        cdf_min_found <= 1'b0;
                        state         <= ST_CDF;
                    end
                end

                // -------------------------------------------------------------
                // ST_CDF — compute normalised CDF and store in cdf_lut
                // -------------------------------------------------------------
                ST_CDF: begin
                    // Read current bin's (clipped) count from hist_bram
                    hist_addr <= proc_bin;
                    hist_we   <= 1'b0;

                    // Process the bin read in the previous cycle (hist_rdata valid)
                    cdf_hist_r  <= hist_rdata; //delay for combinational path
                    cdf_accum   <= cdf_accum + hist_rdata;
                    cdf_accum_r <= cdf_accum + hist_rdata;
                    cdf_min_r   <= cdf_min;

                    if (!cdf_min_found && hist_rdata != 16'd0) begin
                        cdf_min       <= cdf_accum + hist_rdata;
                        cdf_min_found <= 1'b1;
                    end

                    //Write enable follows (offset by 1 cycle, corresponding to the previous proc_bin)
                    cdf_we_p2 <= (proc_bin != {HIST_BITS{1'b0}});
                    cdf_wa_p2 <= proc_bin - 1;

                    // ── Pipe2 calculates cdf_range = (cdf_accum + hist_rdata) - cdf_min ──
                    //denom = (tile_total > cdf_min_r) ? tile_total - cdf_min_r : 16'd1;
                    cdf_range_r <= (cdf_accum_r > cdf_min_r) ? cdf_accum_r - cdf_min_r : 32'd0;
                    cdf_we_p3 <= cdf_we_p2;
                    cdf_wa_p3 <= cdf_wa_p2;

                    // ── Pipe3 for multplication using DSP48: cdf_prod_r = cdf_range * PIXEL_MAX ──
                    cdf_prod_r <= cdf_range_r * PIXEL_MAX[15:0];
                    cdf_we_p4  <= cdf_we_p3;
                    cdf_wa_p4  <= cdf_wa_p3;

                    // ── Pipe4 shift dividing method replace the denom
                    // denom ≈ TILE_PIXELS = 1024，log2(1024)=10
                    // norm_val = prod >> NORM_FRAC  (NORM_FRAC=10，在参数里已定义)
                    cdf_wr_data <= cdf_prod_r[PIXEL_W-1+NORM_FRAC : NORM_FRAC];
                    cdf_wr_addr <= cdf_wa_p4;
                    cdf_we      <= cdf_we_p4;

                    proc_bin <= proc_bin + 1;

                    if (proc_bin == {HIST_BITS{1'b1}}) begin
                        // Trigger background histogram clear (256 cycles, runs in ST_MAP)
                        clr_active <= 1'b1;
                        clr_bin    <= 8'd0;
                        state      <= ST_MAP;
                    end
                end

                // -------------------------------------------------------------
                // ST_MAP: Pass through incoming pixels via cdf_lut lookup.
                // Background histogram clear runs in parallel (clr_active).
                // After TILE_PIXELS pixels, return to ST_COLLECT.
                // -------------------------------------------------------------
                ST_MAP: begin
                    fwd_valid <= 1'b0;
                    cdf_we    <= 1'b0;

                    if (clr_active) begin
                        hist_we    <= 1'b1;
                        hist_addr  <= clr_bin;
                        hist_wdata <= 16'd0;
                        clr_bin    <= clr_bin + 1;
                        map_armed  <= 1'b0;
                        if (clr_bin == 8'hFF)
                            clr_active <= 1'b0;
                    end else begin
                        hist_we <= 1'b0;

                        if (!map_armed) begin
                            map_armed   <= 1'b1;
                            map_idx     <= 10'd0;
                            tile_ra     <= 10'd0;
                            cdf_rd_addr <= tile_rdata[PIXEL_W-1 : PIXEL_W-HIST_BITS];
                        end else begin
                            m_pix_data  <= cdf_rd_data;
                            m_pix_valid <= 1'b1;
                            m_pix_sof   <= (map_idx == 10'd0) &&
                                           (cur_tile_x == 6'd0) &&
                                           (cur_tile_y == 6'd0);
                            if (map_idx == TILE_PIXELS[9:0] - 1) begin
                                map_armed <= 1'b0;
                                state     <= ST_COLLECT;
                            end else begin
                                map_idx <= map_idx + 10'd1;
                                tile_ra <= map_idx + 10'd1;
                                cdf_rd_addr <= tile_rdata[PIXEL_W-1 : PIXEL_W-HIST_BITS];
                            end
                        end
                    end
                end

                default: state <= ST_COLLECT;
            endcase
        end
    end

    // =========================================================================
    // Histogram clear — managed entirely within the main FSM always block above.
    // clr_active and clr_bin are driven by the FSM; no separate always block
    // needed (which would create multi-driver on hist_we).
    // The FSM's ST_MAP handling drives hist_we during background clear.
    // =========================================================================

endmodule
