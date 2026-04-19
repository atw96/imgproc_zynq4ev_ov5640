//=============================================================================
// ram_sp_bram.v
// Single-Port Block RAM — Generic SP BRAM Wrapper
//
// Single port for both read and write (shared address and clock).
// Write mode WR_MODE:
//   0 = READ_FIRST : read old data before write (useful for read-modify-write)
//   1 = WRITE_FIRST: new data available on output during write
//   2 = NO_CHANGE  : output unchanged during write (most resource-efficient)
//
// [see README for description]
// [see README for description]
//=============================================================================

`timescale 1ns/1ps

module ram_sp_bram #(
    parameter DATA_W  = 8,
    parameter DEPTH   = 1024,
    parameter ADDR_W  = $clog2(DEPTH),
    parameter WR_MODE = 0       // 0:READ_FIRST 1:WRITE_FIRST 2:NO_CHANGE
)(
    input  wire              clk,
    input  wire              en,        // Port enable
    input  wire              we,        // Write enable (active high)
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] wdata,
    output reg  [DATA_W-1:0] rdata
);

(* ram_style = "block" *)
reg [DATA_W-1:0] mem [0:DEPTH-1];

generate
    if (WR_MODE == 0) begin : gen_read_first
        // [see README for description]
        always @(posedge clk) begin
            if (en) begin
                if (we)
                    mem[addr] <= wdata;
                rdata <= mem[addr];     // Read old value
            end
        end
    end else if (WR_MODE == 1) begin : gen_write_first
        // [see README for description]
        always @(posedge clk) begin
            if (en) begin
                if (we) begin
                    mem[addr] <= wdata;
                    rdata     <= wdata; // Forward written value
                end else begin
                    rdata <= mem[addr];
                end
            end
        end
    end else begin : gen_no_change
        // [see README for description]
        always @(posedge clk) begin
            if (en) begin
                if (we)
                    mem[addr] <= wdata;
                else
                    rdata <= mem[addr];
            end
        end
    end
endgenerate

endmodule
