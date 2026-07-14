// frame_eth_tx.v — ISP RGB → AXI-Stream for PS AXI DMA S2MM
// Header 12B (3×32-bit beats, TKEEP=F; no DRE required) + RGBX payload
// Header: AA 55 | fid | W | H | format | 00 | 00 00
//   format=1 → RGB888 stored as RGBX (pad 0) for 32-bit AXIS
// AXIS 32-bit @ 1 beat/pixel (DMA must be 32-bit S2MM)
// Inter-frame gap ~20ms @150MHz so PS can arm on AA55

`timescale 1ns/1ps

module frame_eth_tx #(
    parameter PIXEL_W  = 13,
    parameter IMG_W    = 1920,
    parameter IMG_H    = 1080,
    parameter AXIS_DW  = 32,
    parameter FORMAT   = 8'd1
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [PIXEL_W-1:0] s_pix_r,
    input  wire [PIXEL_W-1:0] s_pix_g,
    input  wire [PIXEL_W-1:0] s_pix_b,
    input  wire               s_pix_valid,
    input  wire               s_pix_sof,

    output reg  [AXIS_DW-1:0] m_axis_tdata,
    output reg                m_axis_tvalid,
    input  wire               m_axis_tready,
    output reg                m_axis_tlast,
    output reg  [3:0]         m_axis_tkeep,

    input  wire [3:0]         frame_skip,
    output reg [15:0]         tx_frame_cnt
);

    localparam TOTAL_PIX = IMG_W * IMG_H;
    localparam HDR_WORDS = 2'd3; // 12 bytes, all full-width beats
    localparam [15:0] W16 = IMG_W;
    localparam [15:0] H16 = IMG_H;
    localparam [7:0]  FMT8 = FORMAT;

    localparam S_IDLE    = 2'd0;
    localparam S_HEADER  = 2'd1;
    localparam S_PAYLOAD = 2'd2;
    localparam S_DONE    = 2'd3;

    // ~20ms @150MHz
    localparam GAP_CYCLES = 22'd3000000;

    reg [1:0]  state;
    reg [1:0]  hdr_cnt;
    reg [20:0] pix_cnt;
    reg [3:0]  skip_cnt;
    reg [21:0] gap_cnt;

    wire [7:0] r8 = s_pix_r[11:4];
    wire [7:0] g8 = s_pix_g[11:4];
    wire [7:0] b8 = s_pix_b[11:4];

    wire frame_start = s_pix_valid && s_pix_sof;
    wire axis_fire   = m_axis_tvalid && m_axis_tready;
    wire axis_ready  = !m_axis_tvalid || m_axis_tready;

    // Byte order on AXI (little-endian word): matches DMA DDR layout
    //  [0]=AA [1]=55 [2]=fid_hi [3]=fid_lo
    //  [4]=W_hi [5]=W_lo [6]=H_hi [7]=H_lo
    //  [8]=format [9]=00 [10]=00 [11]=00
    reg [31:0] hdr_word;
    always @(*) begin
        case (hdr_cnt)
            2'd0: hdr_word = {tx_frame_cnt[7:0], tx_frame_cnt[15:8], 8'h55, 8'hAA};
            2'd1: hdr_word = {H16[7:0], H16[15:8], W16[7:0], W16[15:8]};
            default: hdr_word = {8'h00, 8'h00, 8'h00, FMT8};
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            hdr_cnt       <= 2'd0;
            pix_cnt       <= 21'd0;
            skip_cnt      <= 4'd0;
            gap_cnt       <= 22'd0;
            m_axis_tdata  <= 32'd0;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
            m_axis_tkeep  <= 4'hF;
            tx_frame_cnt  <= 16'd0;
        end else begin
            m_axis_tlast <= 1'b0;

            case (state)
            S_IDLE: begin
                m_axis_tvalid <= 1'b0;
                if (frame_start) begin
                    if (skip_cnt == frame_skip) begin
                        skip_cnt <= 4'd0;
                        state    <= S_HEADER;
                        hdr_cnt  <= 2'd0;
                    end else begin
                        skip_cnt <= skip_cnt + 1'b1;
                    end
                end
            end

            S_HEADER: begin
                if (axis_ready) begin
                    m_axis_tdata  <= hdr_word;
                    m_axis_tkeep  <= 4'hF;
                    m_axis_tvalid <= 1'b1;
                    if (hdr_cnt == HDR_WORDS - 1) begin
                        state   <= S_PAYLOAD;
                        pix_cnt <= 21'd0;
                    end
                    hdr_cnt <= hdr_cnt + 2'd1;
                end
            end

            S_PAYLOAD: begin
                if (s_pix_valid && axis_ready) begin
                    // Memory order: R, G, B, 0 (little-endian word)
                    m_axis_tdata  <= {8'h00, b8, g8, r8};
                    m_axis_tkeep  <= 4'hF;
                    m_axis_tvalid <= 1'b1;
                    if (pix_cnt == TOTAL_PIX - 1) begin
                        m_axis_tlast <= 1'b1;
                        state        <= S_DONE;
                        tx_frame_cnt <= tx_frame_cnt + 16'd1;
                    end else begin
                        pix_cnt <= pix_cnt + 21'd1;
                    end
                end else if (axis_fire) begin
                    m_axis_tvalid <= 1'b0;
                end
            end

            S_DONE: begin
                m_axis_tvalid <= 1'b0;
                m_axis_tlast  <= 1'b0;
                if (gap_cnt >= GAP_CYCLES) begin
                    gap_cnt <= 22'd0;
                    state   <= S_IDLE;
                end else begin
                    gap_cnt <= gap_cnt + 22'd1;
                end
            end

            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
