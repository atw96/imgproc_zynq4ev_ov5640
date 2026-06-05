//=============================================================================
// ram_sdp_bram.v
// Simple Dual-Port Block RAM — Generic SDP BRAM Wrapper
//
// Vivado 2020.1 BRAM inference rules (strictly followed):
//   1. (* ram_style = "block" *) attribute forces RAMB inference
//   2. Write: isolated always @(posedge clk_w) with only if(we) mem<=wdata
//   3. Read: isolated always @(posedge clk_r) with only if(re) rdata<=mem
//   4. Address/data pre-registered by caller; no arithmetic inside this module
// [see README for description]
//
// Parameters:
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//=============================================================================

`timescale 1ns/1ps

module ram_sdp_bram #(
    parameter DATA_W = 8,
    parameter DEPTH  = 1024,
    parameter ADDR_W = $clog2(DEPTH),
    parameter DO_REG = 1
)(
    // [see README for description]
    input  wire              clk_w,
    input  wire              we,
    input  wire [ADDR_W-1:0] waddr,
    input  wire [DATA_W-1:0] wdata,
    // [see README for description]
    input  wire              clk_r,
    input  wire              re,
    input  wire [ADDR_W-1:0] raddr,
    output wire [DATA_W-1:0] rdata,
    output wire              rdata_vld
);

// [see README for description]
(* ram_style = "block" *)
reg [DATA_W-1:0] mem [0:DEPTH-1];

// [see README for description]
always @(posedge clk_w) begin
    if (we)
        mem[waddr] <= wdata;
end

// [see README for description]
reg [DATA_W-1:0] rdata_s1;
reg              vld_s1;

always @(posedge clk_r) begin
    if (re)
        rdata_s1 <= mem[raddr];
    vld_s1 <= re;
end

// [see README for description]
generate
    if (DO_REG == 1) begin : gen_doreg
        reg [DATA_W-1:0] rdata_s2;
        reg              vld_s2;
        always @(posedge clk_r) begin
            rdata_s2 <= rdata_s1;
            vld_s2   <= vld_s1;
        end
        assign rdata     = rdata_s2;
        assign rdata_vld = vld_s2;
    end else begin : gen_no_doreg
        assign rdata     = rdata_s1;
        assign rdata_vld = vld_s1;
    end
endgenerate

endmodule
