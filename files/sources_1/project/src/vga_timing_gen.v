//=============================================================================
// vga_timing_gen.v
// Multi-Resolution VGA Standard Timing Generator
//
// Supported resolutions (2K as maximum; smaller images are centred):
//
//   Mode 0 — 2K    (2048×1080 @60 Hz, pixel clock ~148.5 MHz)
//   Mode 1 — 1080p (1920×1080 @60 Hz, pixel clock 148.5 MHz, padded to 2K)
//   Mode 2 — 720p  (1280×720  @60 Hz, pixel clock  74.25 MHz, padded to 2K)
//
// Output baseline: always generates 2048×1080 timing frame.
// [see README for description]
// [see README for description]
//
// [see README for description]
//
// [see README for description]
//     H Total = 2200, H Active = 2048(2K)/1920(1080p)
//     V Total = 1125, V Active = 1080
//     H Sync  = 44 clk, H Back = 148, H Front = 88
//     V Sync  = 5  line, V Back = 36,  V Front = 4
//
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//
// [see README for description]
// [see README for description]
//
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
// [see README for description]
//=============================================================================

`timescale 1ns/1ps

module vga_timing_gen #(
    // [see README for description]
    parameter H_TOTAL_2K   = 2200,
    parameter H_ACTIVE_2K  = 2048,
    parameter H_FRONT_2K   = 88,
    parameter H_SYNC_2K    = 44,
    parameter H_BACK_2K    = 148 - 44,    // back porch（不含 sync）
    parameter V_TOTAL      = 1125,
    parameter V_ACTIVE     = 1080,
    parameter V_FRONT      = 4,
    parameter V_SYNC       = 5,
    parameter V_BACK       = 36,
    // [see README for description]
    parameter H_ACT_1080P  = 1920,
    parameter H_ACT_720P   = 1280,
    parameter V_ACT_720P   = 720
)(
    input  wire         pclk,      // 像素时钟（由外部 MMCM 提供）
    input  wire         rst_n,

    // [see README for description]
    // 00=2K  01=1080p  10=720p
    input  wire [1:0]   res_sel,

    // [see README for description]
    output reg          hsync,         // 行同步（负极性）
    output reg          vsync,         // 场同步（负极性）
    output reg          de,            // 数据使能（像素有效区高）

    // [see README for description]
    output reg  [11:0]  pixel_x,       // 0 ~ H_ACT-1（源分辨率）
    output reg  [10:0]  pixel_y,       // 0 ~ V_ACT-1（源分辨率）
    output reg          active_region, // 当前是否在图像有效区（非黑边）

    // [see README for description]
    output reg          frame_start,   // 每帧第一个 pclk 脉冲
    output reg          line_start,    // 每行第一个有效像素 pclk

    // [see README for description]
    output reg          mmcm_rst
);

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
// [see README for description]
reg [11:0] h_act;      // 当前活跃水平像素
reg [10:0] v_act;      // 当前活跃垂直行数
reg [11:0] h_pad_l;    // 左侧黑边宽度（居中）
reg [10:0] v_pad_t;    // 顶部黑边高度（居中）
reg [11:0] h_total;    // 当前水平总计数

always @(*) begin
    case (res_sel)
        2'b00: begin   // 2K
            h_act    = H_ACTIVE_2K;
            v_act    = V_ACTIVE;
            h_pad_l  = 12'd0;
            v_pad_t  = 11'd0;
            h_total  = H_TOTAL_2K;
        end
        2'b01: begin   // 1080p（居中在 2K 帧内）
            h_act    = H_ACT_1080P;
            v_act    = V_ACTIVE;
            h_pad_l  = (H_ACTIVE_2K - H_ACT_1080P) >> 1;  // 64
            v_pad_t  = 11'd0;
            h_total  = H_TOTAL_2K;
        end
        2'b10: begin   // 720p（居中在 2K 帧内）
            h_act    = H_ACT_720P;
            v_act    = V_ACT_720P;
            h_pad_l  = (H_ACTIVE_2K - H_ACT_720P) >> 1;   // 384
            v_pad_t  = (V_ACTIVE    - V_ACT_720P)  >> 1;   // 180
            h_total  = H_TOTAL_2K;  // 统一用 2K H_TOTAL，720p 时空拍填零
        end
        default: begin
            h_act = H_ACTIVE_2K; v_act = V_ACTIVE;
            h_pad_l = 12'd0; v_pad_t = 11'd0; h_total = H_TOTAL_2K;
        end
    endcase
end

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
reg [11:0] h_cnt;   // 0 ~ H_TOTAL-1
reg [10:0] v_cnt;   // 0 ~ V_TOTAL-1

// [see README for description]
// [see README for description]
//   [0 .. H_FRONT-1]           : Front Porch
//   [H_FRONT .. H_FRONT+H_SYNC-1]: H Sync
//   [H_FRONT+H_SYNC .. H_FRONT+H_SYNC+H_BACK-1]: Back Porch
//   [H_FRONT+H_SYNC+H_BACK .. H_TOTAL-1]: Active
// [see README for description]
localparam H_ACTIVE_START = H_FRONT_2K + H_SYNC_2K + (H_BACK_2K);
localparam H_ACTIVE_END   = H_ACTIVE_START + H_ACTIVE_2K - 1;
localparam H_SYNC_START   = H_FRONT_2K;
localparam H_SYNC_END     = H_FRONT_2K + H_SYNC_2K - 1;

// [see README for description]
localparam V_ACTIVE_START = V_FRONT + V_SYNC + V_BACK;
localparam V_ACTIVE_END   = V_ACTIVE_START + V_ACTIVE - 1;
localparam V_SYNC_START   = V_FRONT;
localparam V_SYNC_END     = V_FRONT + V_SYNC - 1;

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
always @(posedge pclk) begin
    if (!rst_n) begin
        h_cnt <= 12'd0; v_cnt <= 11'd0;
        frame_start <= 1'b0; line_start <= 1'b0;
        mmcm_rst    <= 1'b0;
    end else begin
        frame_start <= 1'b0;
        line_start  <= 1'b0;

        if (h_cnt < H_TOTAL_2K - 1) begin
            h_cnt <= h_cnt + 1;
        end else begin
            h_cnt <= 12'd0;
            if (v_cnt < V_TOTAL - 1) begin
                v_cnt <= v_cnt + 1;
            end else begin
                v_cnt       <= 11'd0;
                frame_start <= 1'b1;
            end
        end
        // [see README for description]
        if (h_cnt == H_ACTIVE_START && v_cnt >= V_ACTIVE_START)
            line_start <= 1'b1;
    end
end

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
always @(posedge pclk) begin
    // [see README for description]
    hsync <= !((h_cnt >= H_SYNC_START) && (h_cnt <= H_SYNC_END));
    // [see README for description]
    vsync <= !((v_cnt >= V_SYNC_START) && (v_cnt <= V_SYNC_END));
    // DE: H Active AND V Active
    de    <= (h_cnt >= H_ACTIVE_START) && (h_cnt <= H_ACTIVE_END) &&
             (v_cnt >= V_ACTIVE_START) && (v_cnt <= V_ACTIVE_END);
end

// ─────────────────────────────────────────────
// [see README for description]
// ─────────────────────────────────────────────
// [see README for description]
wire [11:0] frame_x = (h_cnt >= H_ACTIVE_START) ?
                       h_cnt - H_ACTIVE_START[11:0] : 12'd0;
wire [10:0] frame_y = (v_cnt >= V_ACTIVE_START) ?
                       v_cnt - V_ACTIVE_START[10:0] : 11'd0;

// [see README for description]
wire in_h_act = (frame_x >= h_pad_l) && (frame_x < h_pad_l + h_act);
wire in_v_act = (frame_y >= v_pad_t) && (frame_y < v_pad_t + v_act);

always @(posedge pclk) begin
    active_region <= de && in_h_act && in_v_act;
    // [see README for description]
    pixel_x <= in_h_act ? (frame_x - h_pad_l) : 12'd0;
    pixel_y <= in_v_act ? (frame_y - v_pad_t)  : 11'd0;
end

endmodule
