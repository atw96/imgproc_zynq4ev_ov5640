//=============================================================================
// axil_cfg_reg.v
// Generic AXI4-Lite Configuration Register Bank
//
// Fully decouples AXI4-Lite bus protocol from downstream functional logic.
//   - Accepts AXI4-Lite write / read transactions
//   - Maintains a parameterisable bank of 32-bit registers
//   - Broadcasts register values to functional modules via wreg_o[]
//   - Supports read-back of status registers via status_i[]
//
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//
// [see README for description]
//   0x000 → wreg[0]
//   0x004 → wreg[1]
//   ...
//   0x004*(NUM_WR_REGS-1) → wreg[NUM_WR_REGS-1]
//
// [see README for description]
//   0x200 → status[0]
//   0x204 → status[1]
//   ...
//
// [see README for description]
// [see README for description]
// [see README for description]
//
// [see README for description]
// [see README for description]
//   axil_cfg_reg #(.NUM_WR_REGS(8)) u_cfg (...);
//   assign cfg_session_id = u_cfg.wreg_o[0][SESSION_ID_W-1:0];
//   assign cfg_interval   = u_cfg.wreg_o[1][19:0];
//   assign cfg_mep_id     = {u_cfg.wreg_o[3][15:0], u_cfg.wreg_o[2]};
//   assign cfg_wr_en      = u_cfg.wreg_wr_o[4];
//=============================================================================

`timescale 1ns/1ps

module axil_cfg_reg #(
    parameter NUM_WR_REGS  = 16,     // 可写寄存器数量
    parameter NUM_RD_REGS  = 8,      // 只读状态寄存器数量
    parameter ADDR_BITS    = 12,     // 地址有效位宽（字节）
    parameter STATUS_BASE  = 12'h200 // 状态寄存器基地址（字节）
)(
    input  wire         aclk,
    input  wire         aresetn,

    // [see README for description]
    // [see README for description]
    input  wire [ADDR_BITS-1:0]  s_axil_awaddr,
    input  wire                  s_axil_awvalid,
    output reg                   s_axil_awready,
    // [see README for description]
    input  wire [31:0]           s_axil_wdata,
    input  wire [3:0]            s_axil_wstrb,
    input  wire                  s_axil_wvalid,
    output reg                   s_axil_wready,
    // [see README for description]
    output reg  [1:0]            s_axil_bresp,
    output reg                   s_axil_bvalid,
    input  wire                  s_axil_bready,
    // [see README for description]
    input  wire [ADDR_BITS-1:0]  s_axil_araddr,
    input  wire                  s_axil_arvalid,
    output reg                   s_axil_arready,
    // [see README for description]
    output reg  [31:0]           s_axil_rdata,
    output reg  [1:0]            s_axil_rresp,
    output reg                   s_axil_rvalid,
    input  wire                  s_axil_rready,

    // [see README for description]
    // [see README for description]
    // [see README for description]
    output reg  [32*NUM_WR_REGS-1:0]  wreg_o,
    // [see README for description]
    output reg  [NUM_WR_REGS-1:0]     wreg_wr_o,

    // [see README for description]
    input  wire [32*NUM_RD_REGS-1:0]  status_i
);

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
reg [ADDR_BITS-1:0] aw_addr_lat;   // 锁存写地址
reg                 aw_addr_vld;   // 写地址已接收

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
always @(posedge aclk) begin
    if (!aresetn) begin
        s_axil_awready <= 1'b1;
        s_axil_wready  <= 1'b1;
        s_axil_bvalid  <= 1'b0;
        s_axil_bresp   <= 2'b00;
        aw_addr_vld    <= 1'b0;
        wreg_wr_o      <= {NUM_WR_REGS{1'b0}};
    end else begin
        wreg_wr_o <= {NUM_WR_REGS{1'b0}};  // 默认清零（单拍脉冲）

        // [see README for description]
        if (s_axil_awvalid && s_axil_awready) begin
            aw_addr_lat    <= s_axil_awaddr;
            aw_addr_vld    <= 1'b1;
            s_axil_awready <= 1'b0;
        end

        // [see README for description]
        if (s_axil_wvalid && s_axil_wready && aw_addr_vld) begin
            s_axil_wready  <= 1'b0;
            s_axil_awready <= 1'b0;
            aw_addr_vld    <= 1'b0;

            // [see README for description]
            begin : do_write
                integer idx;
                idx = aw_addr_lat[ADDR_BITS-1:2];  // 去掉低2位（字节对齐）
                if (idx < NUM_WR_REGS) begin
                    // [see README for description]
                    if (s_axil_wstrb[0]) wreg_o[idx*32+0  +: 8] <= s_axil_wdata[7:0];
                    if (s_axil_wstrb[1]) wreg_o[idx*32+8  +: 8] <= s_axil_wdata[15:8];
                    if (s_axil_wstrb[2]) wreg_o[idx*32+16 +: 8] <= s_axil_wdata[23:16];
                    if (s_axil_wstrb[3]) wreg_o[idx*32+24 +: 8] <= s_axil_wdata[31:24];
                    wreg_wr_o[idx] <= 1'b1;
                end
            end

            s_axil_bvalid  <= 1'b1;
            s_axil_bresp   <= 2'b00;  // OKAY
        end

        // [see README for description]
        if (s_axil_bvalid && s_axil_bready) begin
            s_axil_bvalid  <= 1'b0;
            s_axil_awready <= 1'b1;
            s_axil_wready  <= 1'b1;
        end
    end
end

// ─────────────────────────────────────────────
// [see README for description]
// [see README for description]
// [see README for description]
// ─────────────────────────────────────────────
always @(posedge aclk) begin
    if (!aresetn) begin
        s_axil_arready <= 1'b1;
        s_axil_rvalid  <= 1'b0;
        s_axil_rresp   <= 2'b00;
    end else begin
        if (s_axil_arvalid && s_axil_arready) begin
            s_axil_arready <= 1'b0;
            s_axil_rvalid  <= 1'b1;
            s_axil_rresp   <= 2'b00;

            begin : do_read
                integer ridx;
                if (s_axil_araddr >= STATUS_BASE &&
                    s_axil_araddr < STATUS_BASE + NUM_RD_REGS*4) begin
                    // [see README for description]
                    ridx = (s_axil_araddr - STATUS_BASE) >> 2;
                    s_axil_rdata <= status_i[ridx*32 +: 32];
                end else begin
                    // [see README for description]
                    ridx = s_axil_araddr[ADDR_BITS-1:2];
                    if (ridx < NUM_WR_REGS)
                        s_axil_rdata <= wreg_o[ridx*32 +: 32];
                    else
                        s_axil_rdata <= 32'hDEAD_C0DE;
                end
            end
        end

        if (s_axil_rvalid && s_axil_rready) begin
            s_axil_rvalid  <= 1'b0;
            s_axil_arready <= 1'b1;
        end
    end
end

endmodule
