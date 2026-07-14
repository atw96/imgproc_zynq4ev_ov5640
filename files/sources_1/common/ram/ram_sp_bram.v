//=============================================================================
// ram_sp_bram.v
// Single-Port Block RAM - Generic SP BRAM Wrapper
//=============================================================================

`timescale 1ns/1ps

module ram_sp_bram #(
    parameter DATA_W  = 8,
    parameter DEPTH   = 1024,
    parameter ADDR_W  = $clog2(DEPTH),
    parameter WR_MODE = 0,
    parameter INIT_FILE = ""
)(
    input  wire              clk,
    input  wire              en,
    input  wire              we,
    input  wire [ADDR_W-1:0] addr,
    input  wire [DATA_W-1:0] wdata,
    output reg  [DATA_W-1:0] rdata
);

(* ram_style = "block" *)
reg [DATA_W-1:0] mem [0:DEPTH-1];

initial begin
    if (INIT_FILE != "") begin
        $readmemh(INIT_FILE, mem);
    end
end

generate
    if (WR_MODE == 0) begin : gen_read_first
        always @(posedge clk) begin
            if (en) begin
                if (we)
                    mem[addr] <= wdata;
                rdata <= mem[addr];
            end
        end
    end else if (WR_MODE == 1) begin : gen_write_first
        always @(posedge clk) begin
            if (en) begin
                if (we) begin
                    mem[addr] <= wdata;
                    rdata     <= wdata;
                end else begin
                    rdata <= mem[addr];
                end
            end
        end
    end else begin : gen_no_change
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
