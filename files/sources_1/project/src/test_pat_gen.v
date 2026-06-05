// test_pat_gen.v -- PL built-in test pattern (1920x1080 horizontal gradient)
`timescale 1ns/1ps

module test_pat_gen #(
    parameter PIXEL_W = 13,
    parameter IMG_W   = 1920,
    parameter IMG_H   = 1080
)(
    input  wire               clk,
    input  wire               rst_n,
    input  wire               enable,
    output reg  [PIXEL_W-1:0] m_pix_data,
    output reg                m_pix_valid,
    output reg  [31:0]        pix_cnt
);

    localparam integer TOTAL_PIX = IMG_W * IMG_H;
    localparam [15:0]  FRAME_GAP = 16'd32;

    reg [20:0] pix_idx;
    reg [15:0] gap_cnt;

    wire [10:0] col = pix_idx % IMG_W;
    wire [7:0]  grad = col[10:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pix_idx     <= 21'd0;
            gap_cnt     <= 16'd0;
            m_pix_valid <= 1'b0;
            m_pix_data  <= {PIXEL_W{1'b0}};
            pix_cnt     <= 32'd0;
        end else if (!enable) begin
            pix_idx     <= 21'd0;
            gap_cnt     <= 16'd0;
            m_pix_valid <= 1'b0;
        end else if (gap_cnt != 16'd0) begin
            m_pix_valid <= 1'b0;
            gap_cnt     <= gap_cnt - 16'd1;
        end else if (pix_idx < TOTAL_PIX[20:0]) begin
            m_pix_valid <= 1'b1;
            m_pix_data  <= {grad, 5'b0};
            pix_idx     <= pix_idx + 21'd1;
            pix_cnt     <= pix_cnt + 32'd1;
        end else begin
            m_pix_valid <= 1'b0;
            pix_idx     <= 21'd0;
            gap_cnt     <= FRAME_GAP;
        end
    end

endmodule
