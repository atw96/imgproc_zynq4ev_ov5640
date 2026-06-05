// =============================================================================
// shift_reg.v  — Parameterized Shift-Register Delay Line
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// Purpose:
//   Replace manual per-stage _x / _y propagation registers with a single,
//   synthesisable delay line.  For DEPTH >= 2, Vivado maps the storage to
//   SRL16E / SRL32E primitives inside SLICEM (much cheaper than FF chains).
//
// Parameters:
//   W     Data width (bits)
//   DEPTH Number of pipeline stages to delay (≥ 1)
//
// Usage example — delay a coordinate pair by 10 pipeline stages:
//   shift_reg #(.W(11), .DEPTH(10)) u_dly_x (.clk(clk), .din(col_x), .dout(enh_x_del));
//   shift_reg #(.W(11), .DEPTH(10)) u_dly_y (.clk(clk), .din(col_y), .dout(enh_y_del));
//
// Resource:  DEPTH=1 → 1 FF per bit.  DEPTH >= 2 → SRL16/SRL32 per bit.
// Timing:    Output is valid DEPTH clocks after input.
// =============================================================================

`timescale 1ns / 1ps

module shift_reg #(
    parameter W     = 1,
    parameter DEPTH = 1
)(
    input  wire           clk,
    input  wire [W-1:0]   din,
    output wire [W-1:0]   dout
);
    generate
        if (DEPTH == 0) begin : gen_passthrough
            assign dout = din;
        end else if (DEPTH == 1) begin : gen_one_ff
            reg [W-1:0] r;
            always @(posedge clk) r <= din;
            assign dout = r;
        end else begin : gen_srl
            // Vivado infers SRL16E / SRL32E for DEPTH 2-32
            // For DEPTH > 32 it chains SRLs automatically.
            (* srl_style = "srl_reg" *)
            reg [W-1:0] sr [0:DEPTH-1];
            integer i;
            always @(posedge clk) begin
                sr[0] <= din;
                for (i = 1; i < DEPTH; i = i + 1)
                    sr[i] <= sr[i-1];
            end
            assign dout = sr[DEPTH-1];
        end
    endgenerate

endmodule
