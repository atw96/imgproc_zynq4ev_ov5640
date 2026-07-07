// frame_eth_tx.v  -- 帧抽取模块，从 ISP 像素流生成 AXI-Stream 帧数据
// 目的：将完整 1920×1080 灰度帧（8-bit/pixel）打包后送 PS AXI DMA（S2MM）
//
// 帧格式：帧头(8B) + 像素数据(1920×1080 B) = 2,073,608 B/帧
//
// 帧头格式 (8 字节，大端):
//   [7:0]  = 0xAA (魔数)
//   [15:8] = 0x55 (魔数)
//   [31:16] = 帧序号 (uint16)
//   [47:32] = 图像宽度 (uint16)
//   [63:48] = 图像高度 (uint16)
// =============================================================================

`timescale 1ns/1ps

module frame_eth_tx #(
    parameter PIXEL_W  = 13,
    parameter IMG_W    = 1920,
    parameter IMG_H    = 1080,
    parameter AXIS_DW  = 8        // 每拍 1 字节送 DMA
)(
    input  wire        clk,
    input  wire        rst_n,

    input  wire [PIXEL_W-1:0] s_pix_data,
    input  wire               s_pix_valid,
    input  wire               s_pix_sof,

    output reg  [AXIS_DW-1:0] m_axis_tdata,
    output reg                m_axis_tvalid,
    input  wire               m_axis_tready,
    output reg                m_axis_tlast,

    input  wire [3:0]         frame_skip,
    output reg [15:0]         tx_frame_cnt
);

    localparam TOTAL_PIX  = IMG_W * IMG_H;

    localparam S_IDLE    = 2'd0;
    localparam S_HEADER  = 2'd1;
    localparam S_PAYLOAD = 2'd2;
    localparam S_DONE    = 2'd3;

    reg [1:0]  state;
    reg [2:0]  hdr_cnt;
    reg [20:0] pix_cnt;
    reg [3:0]  skip_cnt;

    reg [7:0] hdr_byte;
    always @(*) begin
        case (hdr_cnt)
            3'd0: hdr_byte = 8'hAA;
            3'd1: hdr_byte = 8'h55;
            3'd2: hdr_byte = tx_frame_cnt[15:8];
            3'd3: hdr_byte = tx_frame_cnt[7:0];
            3'd4: hdr_byte = (IMG_W >> 8) & 8'hFF;
            3'd5: hdr_byte = IMG_W & 8'hFF;
            3'd6: hdr_byte = (IMG_H >> 8) & 8'hFF;
            3'd7: hdr_byte = IMG_H & 8'hFF;
            default: hdr_byte = 8'h00;
        endcase
    end

    wire [7:0] pix_byte = s_pix_data[PIXEL_W-1 -: 8];

    wire frame_start = s_pix_valid && s_pix_sof;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state         <= S_IDLE;
            hdr_cnt       <= 3'd0;
            pix_cnt       <= 21'd0;
            skip_cnt      <= 4'd0;
            m_axis_tdata  <= 8'h00;
            m_axis_tvalid <= 1'b0;
            m_axis_tlast  <= 1'b0;
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
                        hdr_cnt  <= 3'd0;
                    end else begin
                        skip_cnt <= skip_cnt + 1'b1;
                    end
                end
            end

            S_HEADER: begin
                if (!m_axis_tvalid || m_axis_tready) begin
                    m_axis_tdata  <= hdr_byte;
                    m_axis_tvalid <= 1'b1;
                    if (hdr_cnt == 3'd7) begin
                        state   <= S_PAYLOAD;
                        pix_cnt <= 21'd0;
                    end else begin
                        hdr_cnt <= hdr_cnt + 1'b1;
                    end
                end
            end

            S_PAYLOAD: begin
                if (s_pix_valid) begin
                    if (!m_axis_tvalid || m_axis_tready) begin
                        m_axis_tdata  <= pix_byte;
                        m_axis_tvalid <= 1'b1;
                        if (pix_cnt == TOTAL_PIX - 1) begin
                            m_axis_tlast  <= 1'b1;
                            state         <= S_DONE;
                            tx_frame_cnt  <= tx_frame_cnt + 1'b1;
                        end else begin
                            pix_cnt <= pix_cnt + 1'b1;
                        end
                    end
                end
            end

            S_DONE: begin
                if (m_axis_tready) begin
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    state         <= S_IDLE;
                end
            end
            default: state <= S_IDLE;
            endcase
        end
    end

endmodule
