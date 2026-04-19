//=============================================================================
// sensor_if.v
// CMOS Image Sensor Interface — RAW Bayer to Internal Pixel Stream
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// ╔══════════════════════════════════════════════════════════════════╗
// ║  SENSOR → FPGA DATA PATH  (Bayer RAW → 13-bit Q0.13 stream)   ║
// ║                                                                  ║
// ║  Physical Interface Options                                      ║
// ║  ─────────────────────────────────────────────────────────────  ║
// ║  A) Parallel DVP (this module implements)                        ║
// ║     · PCLK  : pixel clock from sensor (typ. 74.25–150 MHz)     ║
// ║     · HREF  : line valid (high while pixel data valid)          ║
// ║     · VSYNC : frame sync (polarity configurable)                ║
// ║     · D[11:0]: 12-bit RAW data per clock                        ║
// ║     · Sensors: OmniVision OV9281, Sony IMX296 parallel mode     ║
// ║                                                                  ║
// ║  B) MIPI CSI-2 (common on modern endoscope sensors)             ║
// ║     · Handled by Xilinx MIPI CSI-2 RX Subsystem IP (PG232)     ║
// ║     · Outputs: AXI4-Stream pixel data + end-of-frame signal     ║
// ║     · Use mipi_csi2_rx_subsystem in Block Design,               ║
// ║       then connect its m_axis_* to this module's                ║
// ║       MIPI-mode input (see MIPI_MODE parameter)                 ║
// ║                                                                  ║
// ║  RAW Bayer Format (RGGB default, configurable)                  ║
// ║  ─────────────────────────────────────────────────────────────  ║
// ║    Pixel data from sensor is RAW12 (12-bit per pixel)           ║
// ║    Bayer pattern (RGGB, 2×2 unit cell):                        ║
// ║                                                                  ║
// ║      col:   0    1    2    3    4    5  ...                      ║
// ║      row 0: R    Gr   R    Gr   R    Gr                         ║
// ║      row 1: Gb   B    Gb   B    Gb   B                          ║
// ║      row 2: R    Gr   R    Gr   R    Gr                         ║
// ║      row 3: Gb   B    Gb   B    Gb   B                          ║
// ║                                                                  ║
// ║    Each pixel is ONE raw colour channel (not demosaiced).        ║
// ║    Demosaicing is done downstream in img_preprocessor Stage 3.  ║
// ║                                                                  ║
// ║  Bit-Width Conversion                                            ║
// ║  ─────────────────────────────────────────────────────────────  ║
// ║    Sensor RAW12 [11:0] → Internal Q0.13 [12:0]                  ║
// ║    Method: left-shift by 1 (= multiply by 2, MSB-align in 13b)  ║
// ║    Q0.13 range: 0 = black, 8191 = full scale (1.0 − 1/8192)    ║
// ║    This matches MATLAB: pi_y = hex2dec(Y_short.txt) / 2^13      ║
// ║                                                                  ║
// ║  Internal Output Stream Signals                                  ║
// ║  ─────────────────────────────────────────────────────────────  ║
// ║    m_raw_data  [12:0] : 13-bit Bayer pixel (Q0.13)              ║
// ║    m_raw_valid        : pixel data valid                         ║
// ║    m_raw_hsync        : HIGH on first pixel of each row          ║
// ║    m_raw_vsync        : HIGH on first pixel of each frame        ║
// ║    bayer_phase [1:0]  : current pixel's Bayer channel:          ║
// ║                         00=R  01=Gr  10=Gb  11=B  (RGGB)        ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Clock domain:
//   All outputs are in the PCLK domain (sensor pixel clock).
//   The downstream img_preprocessor runs in pl_clk (150 MHz).
//   A 2-FF sync handshake on VSYNC detects frame boundaries.
//   For robust CDC, insert an async FIFO between sensor_if and img_preprocessor
//   when PCLK ≠ pl_clk. (Not included here; add fifo_async wrapper if needed.)
//
// Integration with img_preprocessor:
//   sensor_if → (optional async FIFO) → img_preprocessor.s_raw_*
//   img_preprocessor outputs Y[12:0] + CbCr[15:0] after full ISP pipeline.
//=============================================================================

`timescale 1ns/1ps

module sensor_if #(
    // Sensor RAW bit-width (12 for RAW12, 10 for RAW10)
    parameter RAW_W       = 12,
    // Internal pixel width (Q0.13)
    parameter PIXEL_W     = 13,
    // Image resolution
    parameter IMG_W       = 2048,
    parameter IMG_H       = 1080,
    // Bayer pattern: 0=RGGB, 1=GRBG, 2=GBRG, 3=BGGR
    parameter BAYER_FMT   = 0,
    // VSYNC polarity: 0 = active-high, 1 = active-low
    parameter VSYNC_POL   = 0,
    // HREF  polarity: 0 = active-high, 1 = active-low
    parameter HREF_POL    = 0,
    // Interface mode: 0 = parallel DVP, 1 = AXI4-Stream (from MIPI CSI-2 IP)
    parameter MIPI_MODE   = 0
)(
    //=========================================================================
    // Mode 0: Parallel DVP sensor signals (connect directly to FPGA I/O)
    //=========================================================================
    input  wire                 pclk,         // sensor pixel clock
    input  wire                 rst_n,

    // --- DVP parallel interface (MIPI_MODE=0) --------------------------------
    input  wire [RAW_W-1:0]     dvp_data,     // RAW pixel data
    input  wire                 dvp_href,     // line valid
    input  wire                 dvp_vsync,    // frame sync
    input  wire                 dvp_pclk_en,  // optional: pixel clock enable

    // --- MIPI AXI4-Stream interface (MIPI_MODE=1, from CSI-2 RX IP) ---------
    // Connect Xilinx MIPI CSI-2 RX Subsystem m_axis_video_* here:
    input  wire [RAW_W*2-1:0]   mipi_tdata,   // 2 pixels per beat (packed)
    input  wire                 mipi_tvalid,
    input  wire                 mipi_tlast,   // end of line
    input  wire                 mipi_tuser,   // start of frame (SOF)

    //=========================================================================
    // Output: internal Bayer pixel stream (to img_preprocessor)
    //=========================================================================
    output reg  [PIXEL_W-1:0]   m_raw_data,   // 13-bit Q0.13 Bayer pixel
    output reg                  m_raw_valid,  // pixel valid
    output reg                  m_raw_hsync,  // high on first pixel of line
    output reg                  m_raw_vsync,  // high on first pixel of frame
    output wire [1:0]            bayer_phase,  // current pixel Bayer channel

    //=========================================================================
    // Status and configuration
    //=========================================================================
    output reg  [15:0]           frame_width,  // pixels per line (measured)
    output reg  [15:0]           frame_height, // lines per frame (measured)
    output reg  [31:0]           frame_cnt,    // frames captured since reset
    output reg                   locked        // 1 = stable video stream
);

    //==========================================================================
    // Internal pixel stream selection (DVP or MIPI)
    //==========================================================================
    wire [RAW_W-1:0] raw_in;
    wire             raw_in_valid;
    wire             raw_in_href;
    wire             raw_in_vsync;

    generate
        if (MIPI_MODE == 0) begin : g_dvp
            // ── DVP Mode ────────────────────────────────────────────────────
            // Register sensor signals to ensure clean sampling
            reg [RAW_W-1:0] dvp_data_r1, dvp_data_r2;
            reg              dvp_href_r1, dvp_href_r2;
            reg              dvp_vs_r1,   dvp_vs_r2;

            always @(posedge pclk) begin
                dvp_data_r1 <= dvp_data;   dvp_data_r2 <= dvp_data_r1;
                dvp_href_r1 <= dvp_href ^ HREF_POL[0];
                dvp_href_r2 <= dvp_href_r1;
                dvp_vs_r1   <= dvp_vsync ^ VSYNC_POL[0];
                dvp_vs_r2   <= dvp_vs_r1;
            end

            assign raw_in       = dvp_data_r2;
            assign raw_in_valid = dvp_href_r2;
            assign raw_in_href  = dvp_href_r2;
            assign raw_in_vsync = dvp_vs_r2;

        end else begin : g_mipi
            // ── MIPI CSI-2 Mode ─────────────────────────────────────────────
            // Xilinx MIPI CSI-2 RX Subsystem outputs pixel data on AXI4-Stream.
            // Data packing for RAW12: 2 pixels per 32-bit beat (12b+12b packed).
            // Here we de-pack to 1 pixel/clock for the downstream pipeline.
            // Extend/replace this block if using a different CSI-2 IP variant.

            reg [RAW_W-1:0] mipi_pix;
            reg              mipi_sel;   // 0 = first pixel, 1 = second pixel
            reg              mipi_valid_r;
            reg              mipi_last_r;
            reg              mipi_sof_r;

            always @(posedge pclk) begin
                if (!rst_n) begin
                    mipi_sel <= 1'b0;
                end else if (mipi_tvalid) begin
                    mipi_sel <= ~mipi_sel;
                    mipi_last_r <= mipi_tlast & mipi_sel;   // last of pair
                    mipi_sof_r  <= mipi_tuser & ~mipi_sel;  // SOF on first pixel
                    mipi_pix    <= mipi_sel ? mipi_tdata[RAW_W*2-1:RAW_W]
                                           : mipi_tdata[RAW_W-1:0];
                    mipi_valid_r<= 1'b1;
                end else begin
                    mipi_valid_r <= 1'b0;
                end
            end

            assign raw_in       = mipi_pix;
            assign raw_in_valid = mipi_valid_r;
            assign raw_in_href  = mipi_valid_r;
            assign raw_in_vsync = mipi_sof_r;
        end
    endgenerate

    //==========================================================================
    // Line/Frame counter and edge detection
    //==========================================================================
    reg              href_d1;
    reg              vsync_d1;
    wire             href_rise  = raw_in_href  & ~href_d1;   // start of line
    wire             href_fall  = ~raw_in_href &  href_d1;   // end of line
    wire             vsync_rise = raw_in_vsync & ~vsync_d1;  // start of frame

    reg [15:0] col_cnt;    // pixels per line counter
    reg [15:0] row_cnt;    // lines per frame counter
    reg [15:0] col_max_r;  // measured line width
    reg [15:0] row_max_r;  // measured frame height

    always @(posedge pclk) begin
        href_d1  <= raw_in_href;
        vsync_d1 <= raw_in_vsync;
    end

    always @(posedge pclk) begin
        if (!rst_n) begin
            col_cnt <= 0;  row_cnt <= 0;
        end else begin
            if (href_rise)  col_cnt <= 16'd1;   // start counting pixels
            else if (raw_in_href) col_cnt <= col_cnt + 1;

            if (href_fall) begin
                col_max_r   <= col_cnt;         // latch line width
                frame_width <= col_cnt;
            end

            if (href_rise && !vsync_d1) begin   // new line, not first
                row_cnt <= row_cnt + 1;
            end
            if (vsync_rise) begin
                row_max_r    <= row_cnt;
                frame_height <= row_cnt;
                row_cnt      <= 16'd0;
                frame_cnt    <= frame_cnt + 1;
            end
        end
    end

    // Lock detection: stable for 4 consecutive frames
    reg [2:0] lock_cnt;
    always @(posedge pclk) begin
        if (!rst_n) begin locked <= 0; lock_cnt <= 0; end
        else if (vsync_rise) begin
            if (row_cnt == IMG_H[15:0] && col_max_r == IMG_W[15:0]) begin
                if (lock_cnt < 3'd4) lock_cnt <= lock_cnt + 1;
                else locked <= 1'b1;
            end else begin
                lock_cnt <= 0; locked <= 1'b0;
            end
        end
    end

    //==========================================================================
    // Bayer phase tracker
    // Tracks position (row_par, col_par) within the 2×2 Bayer unit cell
    // Phase is re-synced at every VSYNC (frame start) and HREF (line start)
    //
    // RGGB:  row_par=0,col_par=0 → R   row_par=0,col_par=1 → Gr
    //         row_par=1,col_par=0 → Gb  row_par=1,col_par=1 → B
    //
    // bayer_phase: 00=R  01=Gr  10=Gb  11=B  (for RGGB)
    //==========================================================================
    reg  row_par;    // 0 = R/Gr row, 1 = Gb/B row
    reg  col_par;    // 0 = even column, 1 = odd column

    always @(posedge pclk) begin
        if (!rst_n) begin
            row_par <= 1'b0; col_par <= 1'b0;
        end else if (vsync_rise) begin
            row_par <= 1'b0; col_par <= 1'b0;   // re-sync at frame start
        end else if (href_rise) begin
            row_par <= ~row_par;                 // flip row parity each line
            col_par <= 1'b0;
        end else if (raw_in_valid) begin
            col_par <= ~col_par;
        end
    end

    // bayer_phase output depends on BAYER_FMT
    reg [1:0] bayer_phase_r;
    always @(*) begin
        case (BAYER_FMT)
            2'd0: // RGGB
                bayer_phase_r = {row_par, col_par};
                // 00=R, 01=Gr, 10=Gb, 11=B
            2'd1: // GRBG
                bayer_phase_r = {row_par, ~col_par};
            2'd2: // GBRG
                bayer_phase_r = {~row_par, col_par};
            2'd3: // BGGR
                bayer_phase_r = {~row_par, ~col_par};
            default:
                bayer_phase_r = {row_par, col_par};
        endcase
    end
    assign bayer_phase = bayer_phase_r;

    //==========================================================================
    // Bit-width conversion: RAW12 → 13-bit Q0.13
    //
    // Sensor output: D[11:0], where D=4095 = full scale
    // Internal:      P[12:0], where P=8191 = full scale (1.0 − LSB)
    //
    // Conversion:    P = {D[11:0], 1'b0}  (left-shift 1, pad with 0)
    //   → P = D × 2,  max = 4095 × 2 = 8190 ≤ 8191  ✓
    //   → LSB of P is always 0 (fine for this pipeline)
    //
    // For RAW10 sensors: P = {D[9:0], 3'b0}  (left-shift 3)
    // For RAW14 sensors: P = D[13:1]          (right-shift 1)
    // For RAW16 sensors: P = D[15:3]          (right-shift 3)
    //==========================================================================
    wire [PIXEL_W-1:0] raw13;
    generate
        if (RAW_W == 12) begin : g_raw12
            // RAW12 → Q0.13: left-shift 1, pad LSB
            assign raw13 = {raw_in[RAW_W-1:0], 1'b0};
        end else if (RAW_W == 10) begin : g_raw10
            // RAW10 → Q0.13: left-shift 3, pad 3 LSBs
            assign raw13 = {raw_in[RAW_W-1:0], 3'b0};
        end else if (RAW_W == 14) begin : g_raw14
            // RAW14 → Q0.13: right-shift 1
            assign raw13 = raw_in[RAW_W-1:1];
        end else begin : g_rawN
            // Generic: truncate or zero-extend to PIXEL_W
            assign raw13 = (RAW_W >= PIXEL_W) ?
                           raw_in[RAW_W-1:RAW_W-PIXEL_W] :
                           {{(PIXEL_W-RAW_W){1'b0}}, raw_in};
        end
    endgenerate

    //==========================================================================
    // Generate m_raw_hsync and m_raw_vsync control signals
    //
    // m_raw_hsync: HIGH only on the FIRST pixel of each row
    // m_raw_vsync: HIGH only on the FIRST pixel of each frame
    // Both are single-cycle pulses (not sustained highs).
    //==========================================================================
    reg  first_pix_of_line;   // registered: fires on first valid pixel of line
    reg  first_pix_of_frame;  // registered: fires on first valid pixel of frame
    reg  new_line_pending;
    reg  new_frame_pending;

    always @(posedge pclk) begin
        if (!rst_n) begin
            new_line_pending  <= 1'b0;
            new_frame_pending <= 1'b0;
        end else begin
            if (href_rise)  new_line_pending  <= 1'b1;
            if (vsync_rise) new_frame_pending <= 1'b1;

            // Clear pending flags when the first pixel arrives
            if (raw_in_valid && new_line_pending)  new_line_pending  <= 1'b0;
            if (raw_in_valid && new_frame_pending) new_frame_pending <= 1'b0;
        end
    end

    wire fire_hsync = raw_in_valid & new_line_pending;
    wire fire_vsync = raw_in_valid & new_frame_pending;

    //==========================================================================
    // Output register (1 pipeline stage to ease timing)
    //==========================================================================
    always @(posedge pclk) begin
        if (!rst_n) begin
            m_raw_valid <= 1'b0;
            m_raw_hsync <= 1'b0;
            m_raw_vsync <= 1'b0;
            m_raw_data  <= {PIXEL_W{1'b0}};
        end else begin
            m_raw_valid <= raw_in_valid;
            m_raw_hsync <= fire_hsync;
            m_raw_vsync <= fire_vsync;
            m_raw_data  <= raw13;
        end
    end

endmodule
