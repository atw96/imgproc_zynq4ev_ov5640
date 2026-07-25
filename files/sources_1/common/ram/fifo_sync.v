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
    parameter DEPTH  = 64,                  // 必须为 2 的幂次！
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
    output wire              almost_full,    // 剩余空间 ≤ 2

    // [see README for description]
    input  wire              rd_en,
    output wire [DATA_W-1:0] rd_data,
    output wire              rd_data_vld,
    output wire              empty,
    output wire              almost_empty,   // 剩余数据 ≤ 2

    // [see README for description]
    output wire [ADDR_W:0]   data_count      // 当前条目数（0~DEPTH）
);

// ─────────────────────────────────────────────
// [see README for description]
// [see README for description]
// ─────────────────────────────────────────────
reg [ADDR_W:0] wr_ptr;   // 写指针（ADDR_W+1 位）
reg [ADDR_W:0] rd_ptr;   // 读指针

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
    .waddr     (wr_ptr[ADDR_W-1:0]),   // 低 ADDR_W 位为实际地址
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
        /* Show-ahead: vld tracks a held word. MUST clear when empty after pop.
         * Old bug: `if (!empty) vld<=1` left vld stuck high after empty, so
         * consumers (ddr3_pixel_buf unpacker) replayed the last beat forever
         * → whole-frame 4px vertical stripe; PS DDR fills ignored. */
        reg  [DATA_W-1:0] fwft_reg;
        reg               fwft_vld;

        always @(posedge clk) begin
            if (!rst_n) begin
                fwft_vld <= 1'b0;
                fwft_reg <= {DATA_W{1'b0}};
            end else begin
                if (bram_rdata_vld) begin
                    fwft_reg <= bram_rdata;
                    fwft_vld <= 1'b1;
                end else if (rd_en && fwft_vld) begin
                    /* Consumed held word; only stay valid if another word remains.
                     * count_w still includes the word being popped this cycle. */
                    fwft_vld <= (count_w > {{ADDR_W{1'b0}}, 1'b1});
                end
            end
        end
        assign rd_data     = fwft_reg;
        assign rd_data_vld = fwft_vld;
    end
endgenerate

endmodule
