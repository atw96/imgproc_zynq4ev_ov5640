//=============================================================================
// fifo_async.v - Async dual-clock FIFO (Gray pointers + 2-FF synchronizers)
//=============================================================================
`timescale 1ns/1ps

module fifo_async #(
    parameter DATA_W = 8,
    parameter DEPTH  = 4096,
    parameter ADDR_W = $clog2(DEPTH)
)(
    input  wire              wr_clk,
    input  wire              wr_rst_n,
    input  wire              wr_en,
    input  wire [DATA_W-1:0] wr_data,
    output wire              full,

    input  wire              rd_clk,
    input  wire              rd_rst_n,
    input  wire              rd_en,
    output wire [DATA_W-1:0] rd_data,
    output wire              rd_data_vld,
    output wire              empty
);

    function [ADDR_W:0] b2g;
        input [ADDR_W:0] b;
        begin
            b2g = b ^ (b >> 1);
        end
    endfunction

    reg [ADDR_W:0] wr_bin;
    reg [ADDR_W:0] rd_bin;

    reg [ADDR_W:0] wr_gray_r;
    reg [ADDR_W:0] rd_gray_r;
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            wr_gray_r <= {(ADDR_W+1){1'b0}};
        else
            wr_gray_r <= b2g(wr_bin);
    end
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            rd_gray_r <= {(ADDR_W+1){1'b0}};
        else
            rd_gray_r <= b2g(rd_bin);
    end

    (* ASYNC_REG = "TRUE" *) reg [ADDR_W:0] rdg_ws1;
    (* ASYNC_REG = "TRUE" *) reg [ADDR_W:0] rdg_ws2;
    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rdg_ws1 <= {(ADDR_W+1){1'b0}};
            rdg_ws2 <= {(ADDR_W+1){1'b0}};
        end else begin
            rdg_ws1 <= rd_gray_r;
            rdg_ws2 <= rdg_ws1;
        end
    end

    (* ASYNC_REG = "TRUE" *) reg [ADDR_W:0] wrg_rs1;
    (* ASYNC_REG = "TRUE" *) reg [ADDR_W:0] wrg_rs2;
    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wrg_rs1 <= {(ADDR_W+1){1'b0}};
            wrg_rs2 <= {(ADDR_W+1){1'b0}};
        end else begin
            wrg_rs1 <= wr_gray_r;
            wrg_rs2 <= wrg_rs1;
        end
    end

    wire [ADDR_W:0] wr_gray_next = b2g(wr_bin + 1'b1);
    wire            full_w = (wr_gray_next == {~rdg_ws2[ADDR_W:ADDR_W-1], rdg_ws2[ADDR_W-2:0]});
    wire            wr_fire = wr_en && !full_w;

    wire [ADDR_W:0] rd_gray = b2g(rd_bin);
    wire            empty_w = (rd_gray == wrg_rs2);
    wire            rd_fire = rd_en && !empty_w;

    assign full  = full_w;
    assign empty = empty_w;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n)
            wr_bin <= {(ADDR_W+1){1'b0}};
        else if (wr_fire)
            wr_bin <= wr_bin + 1'b1;
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n)
            rd_bin <= {(ADDR_W+1){1'b0}};
        else if (rd_fire)
            rd_bin <= rd_bin + 1'b1;
    end

    ram_sdp_bram #(
        .DATA_W (DATA_W),
        .DEPTH  (DEPTH),
        .ADDR_W (ADDR_W),
        .DO_REG (0)
    ) u_mem (
        .clk_w     (wr_clk),
        .we        (wr_fire),
        .waddr     (wr_bin[ADDR_W-1:0]),
        .wdata     (wr_data),
        .clk_r     (rd_clk),
        .re        (rd_fire),
        .raddr     (rd_bin[ADDR_W-1:0]),
        .rdata     (rd_data),
        .rdata_vld (rd_data_vld)
    );

endmodule