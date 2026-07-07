// isp_raw_pat_gen.v -- Backpressure-aware RAW test source for ISP input
// Produces 1920x1080 horizontal gradient (RAW10 -> Q0.13) with hsync/vsync.
`timescale 1ns/1ps

module isp_raw_pat_gen #(
    parameter RAW_W   = 10,
    parameter PIXEL_W = 13,
    parameter IMG_W   = 1920,
    parameter IMG_H   = 1080
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               enable,
    input  wire               s_ready,
    output reg  [PIXEL_W-1:0] m_raw_data,
    output reg                m_raw_valid,
    output reg                m_raw_hsync,
    output reg                m_raw_vsync
);

    localparam integer TOTAL_PIX = IMG_W * IMG_H;
    localparam [15:0]  FRAME_GAP = 16'd64;

    reg [20:0] pix_idx;
    reg [15:0] gap_cnt;

    wire [10:0] col  = pix_idx % IMG_W;
    wire [10:0] row  = pix_idx / IMG_W;
    wire [7:0]  grad = col[10:3];

    wire emit_ok = enable && (gap_cnt == 16'd0) && (pix_idx < TOTAL_PIX[20:0]);
    wire can_fire = emit_ok && s_ready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_idx      <= 21'd0;
            gap_cnt      <= 16'd0;
            m_raw_valid  <= 1'b0;
            m_raw_hsync  <= 1'b0;
            m_raw_vsync  <= 1'b0;
            m_raw_data   <= {PIXEL_W{1'b0}};
        end else begin
            m_raw_valid <= 1'b0;
            m_raw_hsync <= 1'b0;
            m_raw_vsync <= 1'b0;

            if (!enable) begin
                pix_idx <= 21'd0;
                gap_cnt <= 16'd0;
            end else if (gap_cnt != 16'd0) begin
                gap_cnt <= gap_cnt - 16'd1;
            end else if (can_fire) begin
                m_raw_valid <= 1'b1;
                m_raw_data  <= {grad, 5'b0};
                m_raw_hsync <= (col == 11'd0);
                m_raw_vsync <= (col == 11'd0) && (row == 11'd0);
                if (pix_idx == TOTAL_PIX[20:0] - 1) begin
                    pix_idx <= 21'd0;
                    gap_cnt <= FRAME_GAP;
                end else begin
                    pix_idx <= pix_idx + 21'd1;
                end
            end
        end
    end

endmodule
