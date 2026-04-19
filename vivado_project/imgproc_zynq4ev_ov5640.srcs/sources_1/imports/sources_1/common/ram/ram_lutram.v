//=============================================================================
// ram_lutram.v
// Distributed RAM (LUTRAM) — Generic Distributed RAM Wrapper
//
// Characteristics (vs. BRAM):
//   + Asynchronous read (zero latency) — ideal for small, frequently-accessed tables
//   + Synchronous write (posedge clk)
//   + Each LUT6 implements 64×1-bit storage
//   + Recommended for DEPTH × DATA_W ≤ 65536 bits; use BRAM for larger arrays
//
// [see README for description]
// [see README for description]
// [see README for description]
//
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//=============================================================================

`timescale 1ns/1ps

module ram_lutram #(
    parameter DATA_W    = 8,
    parameter DEPTH     = 256,
    parameter ADDR_W    = $clog2(DEPTH),
    parameter SYNC_READ = 0     // 0: async read  1: sync read
)(
    // [see README for description]
    input  wire              clk,
    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [DATA_W-1:0] wdata,

    // [see README for description]
    input  wire              re,            // Used for synchronous read
    input  wire [ADDR_W-1:0] raddr,
    output wire [DATA_W-1:0] rdata,
    output wire              rdata_vld      // Sync read: valid 1T after re; async read: always high
);

// [see README for description]
(* ram_style = "distributed" *)
reg [DATA_W-1:0] mem [0:DEPTH-1];

// [see README for description]
always @(posedge clk) begin
    if (we)
        mem[waddr] <= wdata;
end

// [see README for description]
generate
    if (SYNC_READ == 0) begin : gen_async_rd
        // [see README for description]
        assign rdata     = mem[raddr];
        assign rdata_vld = 1'b1;        // Data valid immediately with address
    end else begin : gen_sync_rd
        // [see README for description]
        reg [DATA_W-1:0] rdata_r;
        reg              vld_r;
        always @(posedge clk) begin
            if (re)
                rdata_r <= mem[raddr];
            vld_r <= re;
        end
        assign rdata     = rdata_r;
        assign rdata_vld = vld_r;
    end
endgenerate

endmodule
