// =============================================================================
// k_lut_rom.v  — Wiener k-Coefficient Look-Up Table  (Read-Only)
// Academic Research Demo — Zynq UltraScale+ ZU7EV
//
// ── Why this module exists (Defect-2 fix: Memory / Control Decoupling) ──────
//   Previously the k-LUT BRAM was declared inline inside
//   local_detail_enhance_11x11.v using a (* ram_style = "block" *) array and
//   an initial block.  Mixing memory initialisation and control logic in one
//   module makes the code harder to read, and some synthesis flows treat the
//   initial block inside a module that also contains FSM logic as non-BRAM.
//   Isolating the ROM here guarantees clean BRAM inference.
//
// ── Content ─────────────────────────────────────────────────────────────────
//   Entry  i : k_lut[i] = round( (i×256) / (i×256 + 1536) × 8192 )  [Q0.13]
//
//   Derivation (from se_ver2.m):
//     k  = σ² / (σ² + σ_n²)            where σ_n² = 1536  (Q0.26)
//     LUT address = σ²[16:8]            step = 2^8 = 256 in Q0.26 space
//     i=0   → k ≈ 0   (flat region, full noise suppression)
//     i=6   → k ≈ 0.5 (σ² = σ_n², Wiener boundary)
//     i=511 → k ≈ 1   (strong texture, pass through unchanged)
//
// ── Interface ────────────────────────────────────────────────────────────────
//   addr  [8:0]   : read address (registered externally: var_q26[16:8])
//   dout  [12:0]  : Q0.13 k value, valid 1 clock after addr
//
// ── Resources ────────────────────────────────────────────────────────────────
//   1 RAMB36  (512 × 13b, fits in one RAMB18 actually)
// =============================================================================

`timescale 1ns / 1ps

module k_lut_rom (
    input  wire        clk,
    input  wire [8:0]  addr,
    output reg  [12:0] dout
);

    (* ram_style = "block" *)
    reg [12:0] mem [0:511];

    // Pre-compute:  k(i) = round( i×256 / (i×256 + 1536) × 8192 )
    // Using integer arithmetic: divide-by-truncation is acceptable because the
    // values are smoothly monotonic and the ±1 LSB error is imperceptible.
    integer i;
    initial begin
        mem[0] = 13'd0;  // special case: 0/(0+1536) = 0
        for (i = 1; i < 512; i = i + 1) begin
            // numerator   = i * 256 * 8192 = i * 2097152
            // denominator = i * 256 + 1536
            // result      ≤ 8192 (fits in 13 bits)
            mem[i] = (i * 256 * 8192) / (i * 256 + 1536);
        end
    end

    always @(posedge clk)
        dout <= mem[addr];

endmodule
