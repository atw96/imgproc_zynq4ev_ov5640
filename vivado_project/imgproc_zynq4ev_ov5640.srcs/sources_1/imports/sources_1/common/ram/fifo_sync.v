//=============================================================================
// fifo_sync.v
// Synchronous FIFO — Generic Parameterisable First-In First-Out Queue
//
// Architecture: control logic (this module) + storage (ram_sdp_bram instance) decoupled.
//
//   ┌──────────────────────────────────────────────────────┐
//   │                  fifo_sync                           │
//   │  ┌─────────────┐        ┌────────────────────────┐  │
// [see README for description]
//   │  │ wr_ptr      │──we────│ clk_w / we / waddr /   │  │
//   │  │ rd_ptr      │──re────│ wdata                  │  │
//   │  │ count       │        │ clk_r / re / raddr /   │  │
//   │  │ full/empty  │        │ rdata / rdata_vld      │  │
//   │  └─────────────┘        └────────────────────────┘  │
//   └──────────────────────────────────────────────────────┘
//
// Parameters:
//   DATA_W   data width
//   DEPTH    FIFO depth (must be power-of-2 for pointer wrap simplicity)
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//
// [see README for description]
// [see README for description]
//=============================================================================

`timescale 1ns/1ps

module fifo_sync #(
    parameter DATA_W = 8,
    parameter DEPTH  = 64,                  // Must be a power of two!
    parameter ADDR_W = $clog2(DEPTH),
    parameter DO_REG = 0,
    parameter FWFT   = 0
)(
    input  wire              clk,
    input  wire              rst_n,

    // [see README for description]
    input  wire              wr_en,
    input  wire [DATA_W-1:0] wr_data,
    output wire              full,
    output wire              almost_full,    // Free space <= 2

    // [see README for description]
    input  wire              rd_en,
    output wire [DATA_W-1:0] rd_data,
    output wire              rd_data_vld,
    output wire              empty,
    output wire              almost_empty,   // Occupancy <= 2

    // [see README for description]
    output wire [ADDR_W:0]   data_count      // Current entry count (0 .. DEPTH)
);

// ─────────────────────────────────────────────
// [see README for description]
// [see README for description]
// ─────────────────────────────────────────────
reg [ADDR_W:0] wr_ptr;   // Write pointer (ADDR_W+1 bits)
reg [ADDR_W:0] rd_ptr;   // Read pointer

wire [ADDR_W:0] count_w = wr_ptr - rd_ptr;

assign data_count   = count_w;
assign full         = (count_w == DEPTH);
assign almost_full  = (count_w >= DEPTH - 2);
assign empty        = (count_w == 0);
assign almost_empty = (count_w <= 2);

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
wire wr_ok = wr_en && !full;
wire rd_ok = rd_en && !empty;

always @(posedge clk) begin
    if (!rst_n)
        wr_ptr <= {(ADDR_W+1){1'b0}};
    else if (wr_ok)
        wr_ptr <= wr_ptr + 1'b1;
end

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
always @(posedge clk) begin
    if (!rst_n)
        rd_ptr <= {(ADDR_W+1){1'b0}};
    else if (rd_ok)
        rd_ptr <= rd_ptr + 1'b1;
end

// ─────────────────────────────────────────────
// [see README for description]
// [see README for description]
// [see README for description]
// ─────────────────────────────────────────────
wire [DATA_W-1:0] bram_rdata;
wire              bram_rdata_vld;

ram_sdp_bram #(
    .DATA_W (DATA_W),
    .DEPTH  (DEPTH),
    .ADDR_W (ADDR_W),
    .DO_REG (DO_REG)
) u_bram (
    .clk_w     (clk),
    .we        (wr_ok),
    .waddr     (wr_ptr[ADDR_W-1:0]),   // Low ADDR_W bits are physical address
    .wdata     (wr_data),
    .clk_r     (clk),
    .re        (rd_ok),
    .raddr     (rd_ptr[ADDR_W-1:0]),
    .rdata     (bram_rdata),
    .rdata_vld (bram_rdata_vld)
);

// ─────────────────────────────────────────────
// [see README for description]
// [see README for description]
// [see README for description]
// ─────────────────────────────────────────────
generate
    if (FWFT == 0) begin : gen_std_mode
        assign rd_data     = bram_rdata;
        assign rd_data_vld = bram_rdata_vld;
    end else begin : gen_fwft_mode
        // [see README for description]
        // [see README for description]
        reg  [DATA_W-1:0] fwft_reg;
        reg               fwft_vld;

        always @(posedge clk) begin
            if (!rst_n) begin
                fwft_vld <= 1'b0;
            end else begin
                if (bram_rdata_vld)
                    fwft_reg <= bram_rdata;
                // [see README for description]
                if (!empty)
                    fwft_vld <= 1'b1;
                else if (rd_en)
                    fwft_vld <= 1'b0;
            end
        end
        assign rd_data     = fwft_vld ? fwft_reg : bram_rdata;
        assign rd_data_vld = fwft_vld;
    end
endgenerate

endmodule
