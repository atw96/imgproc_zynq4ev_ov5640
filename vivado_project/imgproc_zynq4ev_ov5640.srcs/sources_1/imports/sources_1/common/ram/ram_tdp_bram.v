//=============================================================================
// ram_tdp_bram.v
// True Dual-Port Block RAM — Generic TDP BRAM Wrapper
//
// Two fully independent read/write ports (A and B), each with its own clock.
// Typical use cases:
//   - Line buffer (Port A writes new row, Port B reads old row)
//   - Ping-pong buffer (Port A write, Port B read, no switch logic needed)
//   - Cross-clock-domain data exchange
//
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//=============================================================================

`timescale 1ns/1ps

module ram_tdp_bram #(
    parameter DATA_W = 8,
    parameter DEPTH  = 1024,
    parameter ADDR_W = $clog2(DEPTH),
    parameter DO_REG = 0        // 0: 1-cycle read  1: 2-cycle read
)(
    // ── Port A ───────────────────────────────────────────────────
    input  wire              clk_a,
    input  wire              en_a,
    input  wire              we_a,
    input  wire [ADDR_W-1:0] addr_a,
    input  wire [DATA_W-1:0] wdata_a,
    output wire [DATA_W-1:0] rdata_a,
    output wire              rdata_a_vld,

    // ── Port B ───────────────────────────────────────────────────
    input  wire              clk_b,
    input  wire              en_b,
    input  wire              we_b,
    input  wire [ADDR_W-1:0] addr_b,
    input  wire [DATA_W-1:0] wdata_b,
    output wire [DATA_W-1:0] rdata_b,
    output wire              rdata_b_vld
);

// [see README for description]
(* ram_style = "block" *)
reg [DATA_W-1:0] mem [0:DEPTH-1];

// [see README for description]
reg [DATA_W-1:0] rda_s1;
reg              vld_a_s1;

always @(posedge clk_a) begin
    if (en_a) begin
        if (we_a)
            mem[addr_a] <= wdata_a;
        rda_s1 <= mem[addr_a];
    end
    vld_a_s1 <= en_a & ~we_a;  // Do not assert vld during write
end

// [see README for description]
reg [DATA_W-1:0] rdb_s1;
reg              vld_b_s1;

always @(posedge clk_b) begin
    if (en_b) begin
        if (we_b)
            mem[addr_b] <= wdata_b;
        rdb_s1 <= mem[addr_b];
    end
    vld_b_s1 <= en_b & ~we_b;
end

// [see README for description]
generate
    if (DO_REG == 1) begin : gen_doreg
        reg [DATA_W-1:0] rda_s2, rdb_s2;
        reg              vld_a2, vld_b2;
        always @(posedge clk_a) begin rda_s2 <= rda_s1; vld_a2 <= vld_a_s1; end
        always @(posedge clk_b) begin rdb_s2 <= rdb_s1; vld_b2 <= vld_b_s1; end
        assign rdata_a     = rda_s2;
        assign rdata_a_vld = vld_a2;
        assign rdata_b     = rdb_s2;
        assign rdata_b_vld = vld_b2;
    end else begin : gen_no_doreg
        assign rdata_a     = rda_s1;
        assign rdata_a_vld = vld_a_s1;
        assign rdata_b     = rdb_s1;
        assign rdata_b_vld = vld_b_s1;
    end
endgenerate

endmodule
