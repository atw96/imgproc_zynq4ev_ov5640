//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.1 (win64) Build 2902540 Wed May 27 19:54:49 MDT 2020
//Date        : Mon Jul  6 18:13:20 2026
//Host        : DESKTOP-TEFC33U running 64-bit major release  (build 9200)
//Command     : generate_target zynq_imgproc_bd_wrapper.bd
//Design      : zynq_imgproc_bd_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module zynq_imgproc_bd_wrapper
   (ETH_AXIS_S2MM_tdata,
    ETH_AXIS_S2MM_tkeep,
    ETH_AXIS_S2MM_tlast,
    ETH_AXIS_S2MM_tready,
    ETH_AXIS_S2MM_tvalid,
    M_AXIL_CFG_araddr,
    M_AXIL_CFG_arprot,
    M_AXIL_CFG_arready,
    M_AXIL_CFG_arvalid,
    M_AXIL_CFG_awaddr,
    M_AXIL_CFG_awprot,
    M_AXIL_CFG_awready,
    M_AXIL_CFG_awvalid,
    M_AXIL_CFG_bready,
    M_AXIL_CFG_bresp,
    M_AXIL_CFG_bvalid,
    M_AXIL_CFG_rdata,
    M_AXIL_CFG_rready,
    M_AXIL_CFG_rresp,
    M_AXIL_CFG_rvalid,
    M_AXIL_CFG_wdata,
    M_AXIL_CFG_wready,
    M_AXIL_CFG_wstrb,
    M_AXIL_CFG_wvalid,
    S_AXI_HP0_awaddr,
    S_AXI_HP0_awburst,
    S_AXI_HP0_awcache,
    S_AXI_HP0_awlen,
    S_AXI_HP0_awlock,
    S_AXI_HP0_awprot,
    S_AXI_HP0_awqos,
    S_AXI_HP0_awready,
    S_AXI_HP0_awsize,
    S_AXI_HP0_awvalid,
    S_AXI_HP0_bready,
    S_AXI_HP0_bresp,
    S_AXI_HP0_bvalid,
    S_AXI_HP0_wdata,
    S_AXI_HP0_wlast,
    S_AXI_HP0_wready,
    S_AXI_HP0_wstrb,
    S_AXI_HP0_wvalid,
    S_AXI_HP1_araddr,
    S_AXI_HP1_arburst,
    S_AXI_HP1_arcache,
    S_AXI_HP1_arlen,
    S_AXI_HP1_arlock,
    S_AXI_HP1_arprot,
    S_AXI_HP1_arqos,
    S_AXI_HP1_arready,
    S_AXI_HP1_arsize,
    S_AXI_HP1_arvalid,
    S_AXI_HP1_awaddr,
    S_AXI_HP1_awburst,
    S_AXI_HP1_awcache,
    S_AXI_HP1_awlen,
    S_AXI_HP1_awlock,
    S_AXI_HP1_awprot,
    S_AXI_HP1_awqos,
    S_AXI_HP1_awready,
    S_AXI_HP1_awsize,
    S_AXI_HP1_awvalid,
    S_AXI_HP1_bready,
    S_AXI_HP1_bresp,
    S_AXI_HP1_bvalid,
    S_AXI_HP1_rdata,
    S_AXI_HP1_rlast,
    S_AXI_HP1_rready,
    S_AXI_HP1_rresp,
    S_AXI_HP1_rvalid,
    S_AXI_HP1_wdata,
    S_AXI_HP1_wlast,
    S_AXI_HP1_wready,
    S_AXI_HP1_wstrb,
    S_AXI_HP1_wvalid,
    VIDEO_OUT_tdata,
    VIDEO_OUT_tdest,
    VIDEO_OUT_tlast,
    VIDEO_OUT_tready,
    VIDEO_OUT_tuser,
    VIDEO_OUT_tvalid,
    frame_done_irq,
    iic_scl_i,
    iic_scl_o,
    iic_scl_t,
    iic_sda_i,
    iic_sda_o,
    iic_sda_t,
    mipi_phy_if_clk_n,
    mipi_phy_if_clk_p,
    mipi_phy_if_data_n,
    mipi_phy_if_data_p,
    ov5640_mclk,
    ov5640_pwdn,
    ov5640_reset_n,
    pclk,
    pclk_resetn,
    pl_clk,
    rst_n);
  input [7:0]ETH_AXIS_S2MM_tdata;
  input [0:0]ETH_AXIS_S2MM_tkeep;
  input ETH_AXIS_S2MM_tlast;
  output ETH_AXIS_S2MM_tready;
  input ETH_AXIS_S2MM_tvalid;
  output [31:0]M_AXIL_CFG_araddr;
  output [2:0]M_AXIL_CFG_arprot;
  input M_AXIL_CFG_arready;
  output M_AXIL_CFG_arvalid;
  output [31:0]M_AXIL_CFG_awaddr;
  output [2:0]M_AXIL_CFG_awprot;
  input M_AXIL_CFG_awready;
  output M_AXIL_CFG_awvalid;
  output M_AXIL_CFG_bready;
  input [1:0]M_AXIL_CFG_bresp;
  input M_AXIL_CFG_bvalid;
  input [31:0]M_AXIL_CFG_rdata;
  output M_AXIL_CFG_rready;
  input [1:0]M_AXIL_CFG_rresp;
  input M_AXIL_CFG_rvalid;
  output [31:0]M_AXIL_CFG_wdata;
  input M_AXIL_CFG_wready;
  output [3:0]M_AXIL_CFG_wstrb;
  output M_AXIL_CFG_wvalid;
  input [31:0]S_AXI_HP0_awaddr;
  input [1:0]S_AXI_HP0_awburst;
  input [3:0]S_AXI_HP0_awcache;
  input [7:0]S_AXI_HP0_awlen;
  input [0:0]S_AXI_HP0_awlock;
  input [2:0]S_AXI_HP0_awprot;
  input [3:0]S_AXI_HP0_awqos;
  output S_AXI_HP0_awready;
  input [2:0]S_AXI_HP0_awsize;
  input S_AXI_HP0_awvalid;
  input S_AXI_HP0_bready;
  output [1:0]S_AXI_HP0_bresp;
  output S_AXI_HP0_bvalid;
  input [63:0]S_AXI_HP0_wdata;
  input S_AXI_HP0_wlast;
  output S_AXI_HP0_wready;
  input [7:0]S_AXI_HP0_wstrb;
  input S_AXI_HP0_wvalid;
  input [31:0]S_AXI_HP1_araddr;
  input [1:0]S_AXI_HP1_arburst;
  input [3:0]S_AXI_HP1_arcache;
  input [7:0]S_AXI_HP1_arlen;
  input [0:0]S_AXI_HP1_arlock;
  input [2:0]S_AXI_HP1_arprot;
  input [3:0]S_AXI_HP1_arqos;
  output S_AXI_HP1_arready;
  input [2:0]S_AXI_HP1_arsize;
  input S_AXI_HP1_arvalid;
  input [31:0]S_AXI_HP1_awaddr;
  input [1:0]S_AXI_HP1_awburst;
  input [3:0]S_AXI_HP1_awcache;
  input [7:0]S_AXI_HP1_awlen;
  input [0:0]S_AXI_HP1_awlock;
  input [2:0]S_AXI_HP1_awprot;
  input [3:0]S_AXI_HP1_awqos;
  output S_AXI_HP1_awready;
  input [2:0]S_AXI_HP1_awsize;
  input S_AXI_HP1_awvalid;
  input S_AXI_HP1_bready;
  output [1:0]S_AXI_HP1_bresp;
  output S_AXI_HP1_bvalid;
  output [63:0]S_AXI_HP1_rdata;
  output S_AXI_HP1_rlast;
  input S_AXI_HP1_rready;
  output [1:0]S_AXI_HP1_rresp;
  output S_AXI_HP1_rvalid;
  input [63:0]S_AXI_HP1_wdata;
  input S_AXI_HP1_wlast;
  output S_AXI_HP1_wready;
  input [7:0]S_AXI_HP1_wstrb;
  input S_AXI_HP1_wvalid;
  output [23:0]VIDEO_OUT_tdata;
  output [9:0]VIDEO_OUT_tdest;
  output VIDEO_OUT_tlast;
  input VIDEO_OUT_tready;
  output [0:0]VIDEO_OUT_tuser;
  output VIDEO_OUT_tvalid;
  input frame_done_irq;
  input iic_scl_i;
  output iic_scl_o;
  output iic_scl_t;
  input iic_sda_i;
  output iic_sda_o;
  output iic_sda_t;
  input mipi_phy_if_clk_n;
  input mipi_phy_if_clk_p;
  input [1:0]mipi_phy_if_data_n;
  input [1:0]mipi_phy_if_data_p;
  output ov5640_mclk;
  output [0:0]ov5640_pwdn;
  output [0:0]ov5640_reset_n;
  output pclk;
  output [0:0]pclk_resetn;
  output pl_clk;
  output [0:0]rst_n;

  wire [7:0]ETH_AXIS_S2MM_tdata;
  wire [0:0]ETH_AXIS_S2MM_tkeep;
  wire ETH_AXIS_S2MM_tlast;
  wire ETH_AXIS_S2MM_tready;
  wire ETH_AXIS_S2MM_tvalid;
  wire [31:0]M_AXIL_CFG_araddr;
  wire [2:0]M_AXIL_CFG_arprot;
  wire M_AXIL_CFG_arready;
  wire M_AXIL_CFG_arvalid;
  wire [31:0]M_AXIL_CFG_awaddr;
  wire [2:0]M_AXIL_CFG_awprot;
  wire M_AXIL_CFG_awready;
  wire M_AXIL_CFG_awvalid;
  wire M_AXIL_CFG_bready;
  wire [1:0]M_AXIL_CFG_bresp;
  wire M_AXIL_CFG_bvalid;
  wire [31:0]M_AXIL_CFG_rdata;
  wire M_AXIL_CFG_rready;
  wire [1:0]M_AXIL_CFG_rresp;
  wire M_AXIL_CFG_rvalid;
  wire [31:0]M_AXIL_CFG_wdata;
  wire M_AXIL_CFG_wready;
  wire [3:0]M_AXIL_CFG_wstrb;
  wire M_AXIL_CFG_wvalid;
  wire [31:0]S_AXI_HP0_awaddr;
  wire [1:0]S_AXI_HP0_awburst;
  wire [3:0]S_AXI_HP0_awcache;
  wire [7:0]S_AXI_HP0_awlen;
  wire [0:0]S_AXI_HP0_awlock;
  wire [2:0]S_AXI_HP0_awprot;
  wire [3:0]S_AXI_HP0_awqos;
  wire S_AXI_HP0_awready;
  wire [2:0]S_AXI_HP0_awsize;
  wire S_AXI_HP0_awvalid;
  wire S_AXI_HP0_bready;
  wire [1:0]S_AXI_HP0_bresp;
  wire S_AXI_HP0_bvalid;
  wire [63:0]S_AXI_HP0_wdata;
  wire S_AXI_HP0_wlast;
  wire S_AXI_HP0_wready;
  wire [7:0]S_AXI_HP0_wstrb;
  wire S_AXI_HP0_wvalid;
  wire [31:0]S_AXI_HP1_araddr;
  wire [1:0]S_AXI_HP1_arburst;
  wire [3:0]S_AXI_HP1_arcache;
  wire [7:0]S_AXI_HP1_arlen;
  wire [0:0]S_AXI_HP1_arlock;
  wire [2:0]S_AXI_HP1_arprot;
  wire [3:0]S_AXI_HP1_arqos;
  wire S_AXI_HP1_arready;
  wire [2:0]S_AXI_HP1_arsize;
  wire S_AXI_HP1_arvalid;
  wire [31:0]S_AXI_HP1_awaddr;
  wire [1:0]S_AXI_HP1_awburst;
  wire [3:0]S_AXI_HP1_awcache;
  wire [7:0]S_AXI_HP1_awlen;
  wire [0:0]S_AXI_HP1_awlock;
  wire [2:0]S_AXI_HP1_awprot;
  wire [3:0]S_AXI_HP1_awqos;
  wire S_AXI_HP1_awready;
  wire [2:0]S_AXI_HP1_awsize;
  wire S_AXI_HP1_awvalid;
  wire S_AXI_HP1_bready;
  wire [1:0]S_AXI_HP1_bresp;
  wire S_AXI_HP1_bvalid;
  wire [63:0]S_AXI_HP1_rdata;
  wire S_AXI_HP1_rlast;
  wire S_AXI_HP1_rready;
  wire [1:0]S_AXI_HP1_rresp;
  wire S_AXI_HP1_rvalid;
  wire [63:0]S_AXI_HP1_wdata;
  wire S_AXI_HP1_wlast;
  wire S_AXI_HP1_wready;
  wire [7:0]S_AXI_HP1_wstrb;
  wire S_AXI_HP1_wvalid;
  wire [23:0]VIDEO_OUT_tdata;
  wire [9:0]VIDEO_OUT_tdest;
  wire VIDEO_OUT_tlast;
  wire VIDEO_OUT_tready;
  wire [0:0]VIDEO_OUT_tuser;
  wire VIDEO_OUT_tvalid;
  wire frame_done_irq;
  wire iic_scl_i;
  wire iic_scl_o;
  wire iic_scl_t;
  wire iic_sda_i;
  wire iic_sda_o;
  wire iic_sda_t;
  wire mipi_phy_if_clk_n;
  wire mipi_phy_if_clk_p;
  wire [1:0]mipi_phy_if_data_n;
  wire [1:0]mipi_phy_if_data_p;
  wire ov5640_mclk;
  wire [0:0]ov5640_pwdn;
  wire [0:0]ov5640_reset_n;
  wire pclk;
  wire [0:0]pclk_resetn;
  wire pl_clk;
  wire [0:0]rst_n;

  zynq_imgproc_bd zynq_imgproc_bd_i
       (.ETH_AXIS_S2MM_tdata(ETH_AXIS_S2MM_tdata),
        .ETH_AXIS_S2MM_tkeep(ETH_AXIS_S2MM_tkeep),
        .ETH_AXIS_S2MM_tlast(ETH_AXIS_S2MM_tlast),
        .ETH_AXIS_S2MM_tready(ETH_AXIS_S2MM_tready),
        .ETH_AXIS_S2MM_tvalid(ETH_AXIS_S2MM_tvalid),
        .M_AXIL_CFG_araddr(M_AXIL_CFG_araddr),
        .M_AXIL_CFG_arprot(M_AXIL_CFG_arprot),
        .M_AXIL_CFG_arready(M_AXIL_CFG_arready),
        .M_AXIL_CFG_arvalid(M_AXIL_CFG_arvalid),
        .M_AXIL_CFG_awaddr(M_AXIL_CFG_awaddr),
        .M_AXIL_CFG_awprot(M_AXIL_CFG_awprot),
        .M_AXIL_CFG_awready(M_AXIL_CFG_awready),
        .M_AXIL_CFG_awvalid(M_AXIL_CFG_awvalid),
        .M_AXIL_CFG_bready(M_AXIL_CFG_bready),
        .M_AXIL_CFG_bresp(M_AXIL_CFG_bresp),
        .M_AXIL_CFG_bvalid(M_AXIL_CFG_bvalid),
        .M_AXIL_CFG_rdata(M_AXIL_CFG_rdata),
        .M_AXIL_CFG_rready(M_AXIL_CFG_rready),
        .M_AXIL_CFG_rresp(M_AXIL_CFG_rresp),
        .M_AXIL_CFG_rvalid(M_AXIL_CFG_rvalid),
        .M_AXIL_CFG_wdata(M_AXIL_CFG_wdata),
        .M_AXIL_CFG_wready(M_AXIL_CFG_wready),
        .M_AXIL_CFG_wstrb(M_AXIL_CFG_wstrb),
        .M_AXIL_CFG_wvalid(M_AXIL_CFG_wvalid),
        .S_AXI_HP0_awaddr(S_AXI_HP0_awaddr),
        .S_AXI_HP0_awburst(S_AXI_HP0_awburst),
        .S_AXI_HP0_awcache(S_AXI_HP0_awcache),
        .S_AXI_HP0_awlen(S_AXI_HP0_awlen),
        .S_AXI_HP0_awlock(S_AXI_HP0_awlock),
        .S_AXI_HP0_awprot(S_AXI_HP0_awprot),
        .S_AXI_HP0_awqos(S_AXI_HP0_awqos),
        .S_AXI_HP0_awready(S_AXI_HP0_awready),
        .S_AXI_HP0_awsize(S_AXI_HP0_awsize),
        .S_AXI_HP0_awvalid(S_AXI_HP0_awvalid),
        .S_AXI_HP0_bready(S_AXI_HP0_bready),
        .S_AXI_HP0_bresp(S_AXI_HP0_bresp),
        .S_AXI_HP0_bvalid(S_AXI_HP0_bvalid),
        .S_AXI_HP0_wdata(S_AXI_HP0_wdata),
        .S_AXI_HP0_wlast(S_AXI_HP0_wlast),
        .S_AXI_HP0_wready(S_AXI_HP0_wready),
        .S_AXI_HP0_wstrb(S_AXI_HP0_wstrb),
        .S_AXI_HP0_wvalid(S_AXI_HP0_wvalid),
        .S_AXI_HP1_araddr(S_AXI_HP1_araddr),
        .S_AXI_HP1_arburst(S_AXI_HP1_arburst),
        .S_AXI_HP1_arcache(S_AXI_HP1_arcache),
        .S_AXI_HP1_arlen(S_AXI_HP1_arlen),
        .S_AXI_HP1_arlock(S_AXI_HP1_arlock),
        .S_AXI_HP1_arprot(S_AXI_HP1_arprot),
        .S_AXI_HP1_arqos(S_AXI_HP1_arqos),
        .S_AXI_HP1_arready(S_AXI_HP1_arready),
        .S_AXI_HP1_arsize(S_AXI_HP1_arsize),
        .S_AXI_HP1_arvalid(S_AXI_HP1_arvalid),
        .S_AXI_HP1_awaddr(S_AXI_HP1_awaddr),
        .S_AXI_HP1_awburst(S_AXI_HP1_awburst),
        .S_AXI_HP1_awcache(S_AXI_HP1_awcache),
        .S_AXI_HP1_awlen(S_AXI_HP1_awlen),
        .S_AXI_HP1_awlock(S_AXI_HP1_awlock),
        .S_AXI_HP1_awprot(S_AXI_HP1_awprot),
        .S_AXI_HP1_awqos(S_AXI_HP1_awqos),
        .S_AXI_HP1_awready(S_AXI_HP1_awready),
        .S_AXI_HP1_awsize(S_AXI_HP1_awsize),
        .S_AXI_HP1_awvalid(S_AXI_HP1_awvalid),
        .S_AXI_HP1_bready(S_AXI_HP1_bready),
        .S_AXI_HP1_bresp(S_AXI_HP1_bresp),
        .S_AXI_HP1_bvalid(S_AXI_HP1_bvalid),
        .S_AXI_HP1_rdata(S_AXI_HP1_rdata),
        .S_AXI_HP1_rlast(S_AXI_HP1_rlast),
        .S_AXI_HP1_rready(S_AXI_HP1_rready),
        .S_AXI_HP1_rresp(S_AXI_HP1_rresp),
        .S_AXI_HP1_rvalid(S_AXI_HP1_rvalid),
        .S_AXI_HP1_wdata(S_AXI_HP1_wdata),
        .S_AXI_HP1_wlast(S_AXI_HP1_wlast),
        .S_AXI_HP1_wready(S_AXI_HP1_wready),
        .S_AXI_HP1_wstrb(S_AXI_HP1_wstrb),
        .S_AXI_HP1_wvalid(S_AXI_HP1_wvalid),
        .VIDEO_OUT_tdata(VIDEO_OUT_tdata),
        .VIDEO_OUT_tdest(VIDEO_OUT_tdest),
        .VIDEO_OUT_tlast(VIDEO_OUT_tlast),
        .VIDEO_OUT_tready(VIDEO_OUT_tready),
        .VIDEO_OUT_tuser(VIDEO_OUT_tuser),
        .VIDEO_OUT_tvalid(VIDEO_OUT_tvalid),
        .frame_done_irq(frame_done_irq),
        .iic_scl_i(iic_scl_i),
        .iic_scl_o(iic_scl_o),
        .iic_scl_t(iic_scl_t),
        .iic_sda_i(iic_sda_i),
        .iic_sda_o(iic_sda_o),
        .iic_sda_t(iic_sda_t),
        .mipi_phy_if_clk_n(mipi_phy_if_clk_n),
        .mipi_phy_if_clk_p(mipi_phy_if_clk_p),
        .mipi_phy_if_data_n(mipi_phy_if_data_n),
        .mipi_phy_if_data_p(mipi_phy_if_data_p),
        .ov5640_mclk(ov5640_mclk),
        .ov5640_pwdn(ov5640_pwdn),
        .ov5640_reset_n(ov5640_reset_n),
        .pclk(pclk),
        .pclk_resetn(pclk_resetn),
        .pl_clk(pl_clk),
        .rst_n(rst_n));
endmodule
