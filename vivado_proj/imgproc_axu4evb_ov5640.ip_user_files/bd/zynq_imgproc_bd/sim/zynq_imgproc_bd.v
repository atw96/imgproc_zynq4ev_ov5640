//Copyright 1986-2020 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2020.1 (win64) Build 2902540 Wed May 27 19:54:49 MDT 2020
//Date        : Tue Jun  2 12:48:58 2026
//Host        : DESKTOP-TEFC33U running 64-bit major release  (build 9200)
//Command     : generate_target zynq_imgproc_bd.bd
//Design      : zynq_imgproc_bd
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "zynq_imgproc_bd,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=zynq_imgproc_bd,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=15,numReposBlks=15,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=0,numPkgbdBlks=0,bdsource=USER,synth_mode=OOC_per_IP}" *) (* HW_HANDOFF = "zynq_imgproc_bd.hwdef" *) 
module zynq_imgproc_bd
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
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 ETH_AXIS_S2MM TDATA" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME ETH_AXIS_S2MM, CLK_DOMAIN zynq_imgproc_bd_zynq_ultra_ps_e_0_0_pl_clk0, FREQ_HZ 149998505, HAS_TKEEP 0, HAS_TLAST 1, HAS_TREADY 1, HAS_TSTRB 0, INSERT_VIP 0, LAYERED_METADATA undef, PHASE 0.000, TDATA_NUM_BYTES 1, TDEST_WIDTH 0, TID_WIDTH 0, TUSER_WIDTH 0" *) input [7:0]ETH_AXIS_S2MM_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 ETH_AXIS_S2MM TKEEP" *) input [0:0]ETH_AXIS_S2MM_tkeep;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 ETH_AXIS_S2MM TLAST" *) input ETH_AXIS_S2MM_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 ETH_AXIS_S2MM TREADY" *) output ETH_AXIS_S2MM_tready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 ETH_AXIS_S2MM TVALID" *) input ETH_AXIS_S2MM_tvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG ARADDR" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME M_AXIL_CFG, ADDR_WIDTH 32, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN zynq_imgproc_bd_zynq_ultra_ps_e_0_0_pl_clk0, DATA_WIDTH 32, FREQ_HZ 149998505, HAS_BRESP 1, HAS_BURST 0, HAS_CACHE 0, HAS_LOCK 0, HAS_PROT 1, HAS_QOS 0, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 1, NUM_READ_OUTSTANDING 8, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 8, NUM_WRITE_THREADS 1, PHASE 0.000, PROTOCOL AXI4LITE, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 0, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) output [31:0]M_AXIL_CFG_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG ARPROT" *) output [2:0]M_AXIL_CFG_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG ARREADY" *) input M_AXIL_CFG_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG ARVALID" *) output M_AXIL_CFG_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG AWADDR" *) output [31:0]M_AXIL_CFG_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG AWPROT" *) output [2:0]M_AXIL_CFG_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG AWREADY" *) input M_AXIL_CFG_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG AWVALID" *) output M_AXIL_CFG_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG BREADY" *) output M_AXIL_CFG_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG BRESP" *) input [1:0]M_AXIL_CFG_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG BVALID" *) input M_AXIL_CFG_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG RDATA" *) input [31:0]M_AXIL_CFG_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG RREADY" *) output M_AXIL_CFG_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG RRESP" *) input [1:0]M_AXIL_CFG_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG RVALID" *) input M_AXIL_CFG_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG WDATA" *) output [31:0]M_AXIL_CFG_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG WREADY" *) input M_AXIL_CFG_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG WSTRB" *) output [3:0]M_AXIL_CFG_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 M_AXIL_CFG WVALID" *) output M_AXIL_CFG_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWADDR" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP0, ADDR_WIDTH 32, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN zynq_imgproc_bd_zynq_ultra_ps_e_0_0_pl_clk0, DATA_WIDTH 64, FREQ_HZ 149998505, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 0, HAS_LOCK 0, HAS_PROT 1, HAS_QOS 0, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 1, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 1, NUM_WRITE_THREADS 1, PHASE 0.000, PROTOCOL AXI4, READ_WRITE_MODE WRITE_ONLY, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) input [31:0]S_AXI_HP0_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWBURST" *) input [1:0]S_AXI_HP0_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWCACHE" *) input [3:0]S_AXI_HP0_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWLEN" *) input [7:0]S_AXI_HP0_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWLOCK" *) input [0:0]S_AXI_HP0_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWPROT" *) input [2:0]S_AXI_HP0_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWQOS" *) input [3:0]S_AXI_HP0_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWREADY" *) output S_AXI_HP0_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWSIZE" *) input [2:0]S_AXI_HP0_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 AWVALID" *) input S_AXI_HP0_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 BREADY" *) input S_AXI_HP0_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 BRESP" *) output [1:0]S_AXI_HP0_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 BVALID" *) output S_AXI_HP0_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 WDATA" *) input [63:0]S_AXI_HP0_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 WLAST" *) input S_AXI_HP0_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 WREADY" *) output S_AXI_HP0_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 WSTRB" *) input [7:0]S_AXI_HP0_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP0 WVALID" *) input S_AXI_HP0_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARADDR" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S_AXI_HP1, ADDR_WIDTH 32, ARUSER_WIDTH 0, AWUSER_WIDTH 0, BUSER_WIDTH 0, CLK_DOMAIN zynq_imgproc_bd_zynq_ultra_ps_e_0_0_pl_clk0, DATA_WIDTH 64, FREQ_HZ 149998505, HAS_BRESP 1, HAS_BURST 1, HAS_CACHE 0, HAS_LOCK 0, HAS_PROT 1, HAS_QOS 0, HAS_REGION 0, HAS_RRESP 1, HAS_WSTRB 1, ID_WIDTH 0, INSERT_VIP 0, MAX_BURST_LENGTH 256, NUM_READ_OUTSTANDING 1, NUM_READ_THREADS 1, NUM_WRITE_OUTSTANDING 1, NUM_WRITE_THREADS 1, PHASE 0.000, PROTOCOL AXI4, READ_WRITE_MODE READ_WRITE, RUSER_BITS_PER_BYTE 0, RUSER_WIDTH 0, SUPPORTS_NARROW_BURST 1, WUSER_BITS_PER_BYTE 0, WUSER_WIDTH 0" *) input [31:0]S_AXI_HP1_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARBURST" *) input [1:0]S_AXI_HP1_arburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARCACHE" *) input [3:0]S_AXI_HP1_arcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARLEN" *) input [7:0]S_AXI_HP1_arlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARLOCK" *) input [0:0]S_AXI_HP1_arlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARPROT" *) input [2:0]S_AXI_HP1_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARQOS" *) input [3:0]S_AXI_HP1_arqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARREADY" *) output S_AXI_HP1_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARSIZE" *) input [2:0]S_AXI_HP1_arsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 ARVALID" *) input S_AXI_HP1_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWADDR" *) input [31:0]S_AXI_HP1_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWBURST" *) input [1:0]S_AXI_HP1_awburst;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWCACHE" *) input [3:0]S_AXI_HP1_awcache;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWLEN" *) input [7:0]S_AXI_HP1_awlen;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWLOCK" *) input [0:0]S_AXI_HP1_awlock;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWPROT" *) input [2:0]S_AXI_HP1_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWQOS" *) input [3:0]S_AXI_HP1_awqos;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWREADY" *) output S_AXI_HP1_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWSIZE" *) input [2:0]S_AXI_HP1_awsize;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 AWVALID" *) input S_AXI_HP1_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 BREADY" *) input S_AXI_HP1_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 BRESP" *) output [1:0]S_AXI_HP1_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 BVALID" *) output S_AXI_HP1_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 RDATA" *) output [63:0]S_AXI_HP1_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 RLAST" *) output S_AXI_HP1_rlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 RREADY" *) input S_AXI_HP1_rready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 RRESP" *) output [1:0]S_AXI_HP1_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 RVALID" *) output S_AXI_HP1_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 WDATA" *) input [63:0]S_AXI_HP1_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 WLAST" *) input S_AXI_HP1_wlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 WREADY" *) output S_AXI_HP1_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 WSTRB" *) input [7:0]S_AXI_HP1_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI_HP1 WVALID" *) input S_AXI_HP1_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 VIDEO_OUT TDATA" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME VIDEO_OUT, CLK_DOMAIN zynq_imgproc_bd_zynq_ultra_ps_e_0_0_pl_clk0, FREQ_HZ 149998505, HAS_TKEEP 0, HAS_TLAST 1, HAS_TREADY 1, HAS_TSTRB 0, INSERT_VIP 0, LAYERED_METADATA undef, PHASE 0.000, TDATA_NUM_BYTES 3, TDEST_WIDTH 10, TID_WIDTH 0, TUSER_WIDTH 1" *) output [23:0]VIDEO_OUT_tdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 VIDEO_OUT TDEST" *) output [9:0]VIDEO_OUT_tdest;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 VIDEO_OUT TLAST" *) output VIDEO_OUT_tlast;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 VIDEO_OUT TREADY" *) input VIDEO_OUT_tready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 VIDEO_OUT TUSER" *) output [0:0]VIDEO_OUT_tuser;
  (* X_INTERFACE_INFO = "xilinx.com:interface:axis:1.0 VIDEO_OUT TVALID" *) output VIDEO_OUT_tvalid;
  input frame_done_irq;
  input iic_scl_i;
  output iic_scl_o;
  output iic_scl_t;
  input iic_sda_i;
  output iic_sda_o;
  output iic_sda_t;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mipi_phy:1.0 mipi_phy_if CLK_N" *) input mipi_phy_if_clk_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mipi_phy:1.0 mipi_phy_if CLK_P" *) input mipi_phy_if_clk_p;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mipi_phy:1.0 mipi_phy_if DATA_N" *) input [1:0]mipi_phy_if_data_n;
  (* X_INTERFACE_INFO = "xilinx.com:interface:mipi_phy:1.0 mipi_phy_if DATA_P" *) input [1:0]mipi_phy_if_data_p;
  output ov5640_mclk;
  output [0:0]ov5640_pwdn;
  output [0:0]ov5640_reset_n;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.PCLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.PCLK, CLK_DOMAIN zynq_imgproc_bd_clk_wiz_0_0_clk_out1, FREQ_HZ 148499010, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) output pclk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.PCLK_RESETN RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.PCLK_RESETN, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) output [0:0]pclk_resetn;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.PL_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.PL_CLK, ASSOCIATED_BUSIF S_AXI_HP0:S_AXI_HP1:M_AXIL_CFG:VIDEO_OUT:ETH_AXIS_S2MM, CLK_DOMAIN zynq_imgproc_bd_zynq_ultra_ps_e_0_0_pl_clk0, FREQ_HZ 149998505, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.000" *) output pl_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.RST_N RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.RST_N, INSERT_VIP 0, POLARITY ACTIVE_LOW" *) output [0:0]rst_n;

  wire [7:0]ETH_AXIS_S2MM_1_TDATA;
  wire [0:0]ETH_AXIS_S2MM_1_TKEEP;
  wire ETH_AXIS_S2MM_1_TLAST;
  wire ETH_AXIS_S2MM_1_TREADY;
  wire ETH_AXIS_S2MM_1_TVALID;
  wire [31:0]S_AXI_HP0_1_AWADDR;
  wire [1:0]S_AXI_HP0_1_AWBURST;
  wire [3:0]S_AXI_HP0_1_AWCACHE;
  wire [7:0]S_AXI_HP0_1_AWLEN;
  wire [0:0]S_AXI_HP0_1_AWLOCK;
  wire [2:0]S_AXI_HP0_1_AWPROT;
  wire [3:0]S_AXI_HP0_1_AWQOS;
  wire S_AXI_HP0_1_AWREADY;
  wire [2:0]S_AXI_HP0_1_AWSIZE;
  wire S_AXI_HP0_1_AWVALID;
  wire S_AXI_HP0_1_BREADY;
  wire [1:0]S_AXI_HP0_1_BRESP;
  wire S_AXI_HP0_1_BVALID;
  wire [63:0]S_AXI_HP0_1_WDATA;
  wire S_AXI_HP0_1_WLAST;
  wire S_AXI_HP0_1_WREADY;
  wire [7:0]S_AXI_HP0_1_WSTRB;
  wire S_AXI_HP0_1_WVALID;
  wire [31:0]S_AXI_HP1_1_ARADDR;
  wire [1:0]S_AXI_HP1_1_ARBURST;
  wire [3:0]S_AXI_HP1_1_ARCACHE;
  wire [7:0]S_AXI_HP1_1_ARLEN;
  wire [0:0]S_AXI_HP1_1_ARLOCK;
  wire [2:0]S_AXI_HP1_1_ARPROT;
  wire [3:0]S_AXI_HP1_1_ARQOS;
  wire S_AXI_HP1_1_ARREADY;
  wire [2:0]S_AXI_HP1_1_ARSIZE;
  wire S_AXI_HP1_1_ARVALID;
  wire [31:0]S_AXI_HP1_1_AWADDR;
  wire [1:0]S_AXI_HP1_1_AWBURST;
  wire [3:0]S_AXI_HP1_1_AWCACHE;
  wire [7:0]S_AXI_HP1_1_AWLEN;
  wire [0:0]S_AXI_HP1_1_AWLOCK;
  wire [2:0]S_AXI_HP1_1_AWPROT;
  wire [3:0]S_AXI_HP1_1_AWQOS;
  wire S_AXI_HP1_1_AWREADY;
  wire [2:0]S_AXI_HP1_1_AWSIZE;
  wire S_AXI_HP1_1_AWVALID;
  wire S_AXI_HP1_1_BREADY;
  wire [1:0]S_AXI_HP1_1_BRESP;
  wire S_AXI_HP1_1_BVALID;
  wire [63:0]S_AXI_HP1_1_RDATA;
  wire S_AXI_HP1_1_RLAST;
  wire S_AXI_HP1_1_RREADY;
  wire [1:0]S_AXI_HP1_1_RRESP;
  wire S_AXI_HP1_1_RVALID;
  wire [63:0]S_AXI_HP1_1_WDATA;
  wire S_AXI_HP1_1_WLAST;
  wire S_AXI_HP1_1_WREADY;
  wire [7:0]S_AXI_HP1_1_WSTRB;
  wire S_AXI_HP1_1_WVALID;
  wire [31:0]axi_dma_eth_M_AXI_S2MM_AWADDR;
  wire [1:0]axi_dma_eth_M_AXI_S2MM_AWBURST;
  wire [3:0]axi_dma_eth_M_AXI_S2MM_AWCACHE;
  wire [7:0]axi_dma_eth_M_AXI_S2MM_AWLEN;
  wire [2:0]axi_dma_eth_M_AXI_S2MM_AWPROT;
  wire axi_dma_eth_M_AXI_S2MM_AWREADY;
  wire [2:0]axi_dma_eth_M_AXI_S2MM_AWSIZE;
  wire axi_dma_eth_M_AXI_S2MM_AWVALID;
  wire axi_dma_eth_M_AXI_S2MM_BREADY;
  wire [1:0]axi_dma_eth_M_AXI_S2MM_BRESP;
  wire axi_dma_eth_M_AXI_S2MM_BVALID;
  wire [31:0]axi_dma_eth_M_AXI_S2MM_WDATA;
  wire axi_dma_eth_M_AXI_S2MM_WLAST;
  wire axi_dma_eth_M_AXI_S2MM_WREADY;
  wire [3:0]axi_dma_eth_M_AXI_S2MM_WSTRB;
  wire axi_dma_eth_M_AXI_S2MM_WVALID;
  wire axi_dma_eth_s2mm_introut;
  wire [1:0]axi_gpio_0_gpio_io_o;
  wire axi_iic_0_scl_o;
  wire axi_iic_0_scl_t;
  wire axi_iic_0_sda_o;
  wire axi_iic_0_sda_t;
  wire [31:0]axi_sc_cfg_M00_AXI_ARADDR;
  wire [2:0]axi_sc_cfg_M00_AXI_ARPROT;
  wire axi_sc_cfg_M00_AXI_ARREADY;
  wire axi_sc_cfg_M00_AXI_ARVALID;
  wire [31:0]axi_sc_cfg_M00_AXI_AWADDR;
  wire [2:0]axi_sc_cfg_M00_AXI_AWPROT;
  wire axi_sc_cfg_M00_AXI_AWREADY;
  wire axi_sc_cfg_M00_AXI_AWVALID;
  wire axi_sc_cfg_M00_AXI_BREADY;
  wire [1:0]axi_sc_cfg_M00_AXI_BRESP;
  wire axi_sc_cfg_M00_AXI_BVALID;
  wire [31:0]axi_sc_cfg_M00_AXI_RDATA;
  wire axi_sc_cfg_M00_AXI_RREADY;
  wire [1:0]axi_sc_cfg_M00_AXI_RRESP;
  wire axi_sc_cfg_M00_AXI_RVALID;
  wire [31:0]axi_sc_cfg_M00_AXI_WDATA;
  wire axi_sc_cfg_M00_AXI_WREADY;
  wire [3:0]axi_sc_cfg_M00_AXI_WSTRB;
  wire axi_sc_cfg_M00_AXI_WVALID;
  wire [8:0]axi_sc_cfg_M01_AXI_ARADDR;
  wire axi_sc_cfg_M01_AXI_ARREADY;
  wire axi_sc_cfg_M01_AXI_ARVALID;
  wire [8:0]axi_sc_cfg_M01_AXI_AWADDR;
  wire axi_sc_cfg_M01_AXI_AWREADY;
  wire axi_sc_cfg_M01_AXI_AWVALID;
  wire axi_sc_cfg_M01_AXI_BREADY;
  wire [1:0]axi_sc_cfg_M01_AXI_BRESP;
  wire axi_sc_cfg_M01_AXI_BVALID;
  wire [31:0]axi_sc_cfg_M01_AXI_RDATA;
  wire axi_sc_cfg_M01_AXI_RREADY;
  wire [1:0]axi_sc_cfg_M01_AXI_RRESP;
  wire axi_sc_cfg_M01_AXI_RVALID;
  wire [31:0]axi_sc_cfg_M01_AXI_WDATA;
  wire axi_sc_cfg_M01_AXI_WREADY;
  wire [3:0]axi_sc_cfg_M01_AXI_WSTRB;
  wire axi_sc_cfg_M01_AXI_WVALID;
  wire [8:0]axi_sc_cfg_M02_AXI_ARADDR;
  wire axi_sc_cfg_M02_AXI_ARREADY;
  wire axi_sc_cfg_M02_AXI_ARVALID;
  wire [8:0]axi_sc_cfg_M02_AXI_AWADDR;
  wire axi_sc_cfg_M02_AXI_AWREADY;
  wire axi_sc_cfg_M02_AXI_AWVALID;
  wire axi_sc_cfg_M02_AXI_BREADY;
  wire [1:0]axi_sc_cfg_M02_AXI_BRESP;
  wire axi_sc_cfg_M02_AXI_BVALID;
  wire [31:0]axi_sc_cfg_M02_AXI_RDATA;
  wire axi_sc_cfg_M02_AXI_RREADY;
  wire [1:0]axi_sc_cfg_M02_AXI_RRESP;
  wire axi_sc_cfg_M02_AXI_RVALID;
  wire [31:0]axi_sc_cfg_M02_AXI_WDATA;
  wire axi_sc_cfg_M02_AXI_WREADY;
  wire [3:0]axi_sc_cfg_M02_AXI_WSTRB;
  wire axi_sc_cfg_M02_AXI_WVALID;
  wire [12:0]axi_sc_cfg_M03_AXI_ARADDR;
  wire [2:0]axi_sc_cfg_M03_AXI_ARPROT;
  wire [0:0]axi_sc_cfg_M03_AXI_ARREADY;
  wire axi_sc_cfg_M03_AXI_ARVALID;
  wire [12:0]axi_sc_cfg_M03_AXI_AWADDR;
  wire [2:0]axi_sc_cfg_M03_AXI_AWPROT;
  wire [0:0]axi_sc_cfg_M03_AXI_AWREADY;
  wire axi_sc_cfg_M03_AXI_AWVALID;
  wire axi_sc_cfg_M03_AXI_BREADY;
  wire [1:0]axi_sc_cfg_M03_AXI_BRESP;
  wire [0:0]axi_sc_cfg_M03_AXI_BVALID;
  wire [31:0]axi_sc_cfg_M03_AXI_RDATA;
  wire axi_sc_cfg_M03_AXI_RREADY;
  wire [1:0]axi_sc_cfg_M03_AXI_RRESP;
  wire [0:0]axi_sc_cfg_M03_AXI_RVALID;
  wire [31:0]axi_sc_cfg_M03_AXI_WDATA;
  wire [0:0]axi_sc_cfg_M03_AXI_WREADY;
  wire [3:0]axi_sc_cfg_M03_AXI_WSTRB;
  wire axi_sc_cfg_M03_AXI_WVALID;
  wire [9:0]axi_sc_cfg_M04_AXI_ARADDR;
  wire axi_sc_cfg_M04_AXI_ARREADY;
  wire axi_sc_cfg_M04_AXI_ARVALID;
  wire [9:0]axi_sc_cfg_M04_AXI_AWADDR;
  wire axi_sc_cfg_M04_AXI_AWREADY;
  wire axi_sc_cfg_M04_AXI_AWVALID;
  wire axi_sc_cfg_M04_AXI_BREADY;
  wire [1:0]axi_sc_cfg_M04_AXI_BRESP;
  wire axi_sc_cfg_M04_AXI_BVALID;
  wire [31:0]axi_sc_cfg_M04_AXI_RDATA;
  wire axi_sc_cfg_M04_AXI_RREADY;
  wire [1:0]axi_sc_cfg_M04_AXI_RRESP;
  wire axi_sc_cfg_M04_AXI_RVALID;
  wire [31:0]axi_sc_cfg_M04_AXI_WDATA;
  wire axi_sc_cfg_M04_AXI_WREADY;
  wire axi_sc_cfg_M04_AXI_WVALID;
  wire [48:0]axi_sc_hp0_M00_AXI_AWADDR;
  wire [1:0]axi_sc_hp0_M00_AXI_AWBURST;
  wire [3:0]axi_sc_hp0_M00_AXI_AWCACHE;
  wire [7:0]axi_sc_hp0_M00_AXI_AWLEN;
  wire [0:0]axi_sc_hp0_M00_AXI_AWLOCK;
  wire [2:0]axi_sc_hp0_M00_AXI_AWPROT;
  wire [3:0]axi_sc_hp0_M00_AXI_AWQOS;
  wire axi_sc_hp0_M00_AXI_AWREADY;
  wire [2:0]axi_sc_hp0_M00_AXI_AWSIZE;
  wire axi_sc_hp0_M00_AXI_AWVALID;
  wire axi_sc_hp0_M00_AXI_BREADY;
  wire [1:0]axi_sc_hp0_M00_AXI_BRESP;
  wire axi_sc_hp0_M00_AXI_BVALID;
  wire [63:0]axi_sc_hp0_M00_AXI_WDATA;
  wire axi_sc_hp0_M00_AXI_WLAST;
  wire axi_sc_hp0_M00_AXI_WREADY;
  wire [7:0]axi_sc_hp0_M00_AXI_WSTRB;
  wire axi_sc_hp0_M00_AXI_WVALID;
  wire [48:0]axi_sc_hp1_M00_AXI_ARADDR;
  wire [1:0]axi_sc_hp1_M00_AXI_ARBURST;
  wire [3:0]axi_sc_hp1_M00_AXI_ARCACHE;
  wire [7:0]axi_sc_hp1_M00_AXI_ARLEN;
  wire [0:0]axi_sc_hp1_M00_AXI_ARLOCK;
  wire [2:0]axi_sc_hp1_M00_AXI_ARPROT;
  wire [3:0]axi_sc_hp1_M00_AXI_ARQOS;
  wire axi_sc_hp1_M00_AXI_ARREADY;
  wire [2:0]axi_sc_hp1_M00_AXI_ARSIZE;
  wire axi_sc_hp1_M00_AXI_ARVALID;
  wire [48:0]axi_sc_hp1_M00_AXI_AWADDR;
  wire [1:0]axi_sc_hp1_M00_AXI_AWBURST;
  wire [3:0]axi_sc_hp1_M00_AXI_AWCACHE;
  wire [7:0]axi_sc_hp1_M00_AXI_AWLEN;
  wire [0:0]axi_sc_hp1_M00_AXI_AWLOCK;
  wire [2:0]axi_sc_hp1_M00_AXI_AWPROT;
  wire [3:0]axi_sc_hp1_M00_AXI_AWQOS;
  wire axi_sc_hp1_M00_AXI_AWREADY;
  wire [2:0]axi_sc_hp1_M00_AXI_AWSIZE;
  wire axi_sc_hp1_M00_AXI_AWVALID;
  wire axi_sc_hp1_M00_AXI_BREADY;
  wire [1:0]axi_sc_hp1_M00_AXI_BRESP;
  wire axi_sc_hp1_M00_AXI_BVALID;
  wire [63:0]axi_sc_hp1_M00_AXI_RDATA;
  wire axi_sc_hp1_M00_AXI_RLAST;
  wire axi_sc_hp1_M00_AXI_RREADY;
  wire [1:0]axi_sc_hp1_M00_AXI_RRESP;
  wire axi_sc_hp1_M00_AXI_RVALID;
  wire [63:0]axi_sc_hp1_M00_AXI_WDATA;
  wire axi_sc_hp1_M00_AXI_WLAST;
  wire axi_sc_hp1_M00_AXI_WREADY;
  wire [7:0]axi_sc_hp1_M00_AXI_WSTRB;
  wire axi_sc_hp1_M00_AXI_WVALID;
  wire [48:0]axi_sc_hp2_M00_AXI_AWADDR;
  wire [1:0]axi_sc_hp2_M00_AXI_AWBURST;
  wire [3:0]axi_sc_hp2_M00_AXI_AWCACHE;
  wire [7:0]axi_sc_hp2_M00_AXI_AWLEN;
  wire [0:0]axi_sc_hp2_M00_AXI_AWLOCK;
  wire [2:0]axi_sc_hp2_M00_AXI_AWPROT;
  wire [3:0]axi_sc_hp2_M00_AXI_AWQOS;
  wire axi_sc_hp2_M00_AXI_AWREADY;
  wire [2:0]axi_sc_hp2_M00_AXI_AWSIZE;
  wire axi_sc_hp2_M00_AXI_AWVALID;
  wire axi_sc_hp2_M00_AXI_BREADY;
  wire [1:0]axi_sc_hp2_M00_AXI_BRESP;
  wire axi_sc_hp2_M00_AXI_BVALID;
  wire [63:0]axi_sc_hp2_M00_AXI_WDATA;
  wire axi_sc_hp2_M00_AXI_WLAST;
  wire axi_sc_hp2_M00_AXI_WREADY;
  wire [7:0]axi_sc_hp2_M00_AXI_WSTRB;
  wire axi_sc_hp2_M00_AXI_WVALID;
  wire clk_wiz_0_clk_out1;
  wire clk_wiz_0_locked;
  wire clk_wiz_mipi_ref_clk_out1;
  wire frame_done_irq_1;
  wire iic_scl_i_1;
  wire iic_sda_i_1;
  wire [23:0]mipi_csi2_rx_subsystem_0_video_out_TDATA;
  wire [9:0]mipi_csi2_rx_subsystem_0_video_out_TDEST;
  wire mipi_csi2_rx_subsystem_0_video_out_TLAST;
  wire mipi_csi2_rx_subsystem_0_video_out_TREADY;
  wire [0:0]mipi_csi2_rx_subsystem_0_video_out_TUSER;
  wire mipi_csi2_rx_subsystem_0_video_out_TVALID;
  wire mipi_phy_if_1_CLK_N;
  wire mipi_phy_if_1_CLK_P;
  wire [1:0]mipi_phy_if_1_DATA_N;
  wire [1:0]mipi_phy_if_1_DATA_P;
  wire [0:0]rst_pclk_0_peripheral_aresetn;
  wire [0:0]rst_ps8_0_150m_interconnect_aresetn;
  wire [0:0]rst_ps8_0_150m_peripheral_aresetn;
  wire [0:0]xlslice_pwdn_Dout;
  wire [0:0]xlslice_rst_Dout;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID;
  wire [39:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID;
  wire [7:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY;
  wire [2:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID;
  wire [31:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA;
  wire [15:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY;
  wire [1:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID;
  wire [31:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY;
  wire [3:0]zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB;
  wire zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID;
  wire zynq_ultra_ps_e_0_pl_clk0;
  wire zynq_ultra_ps_e_0_pl_clk1;
  wire zynq_ultra_ps_e_0_pl_resetn0;

  assign ETH_AXIS_S2MM_1_TDATA = ETH_AXIS_S2MM_tdata[7:0];
  assign ETH_AXIS_S2MM_1_TKEEP = ETH_AXIS_S2MM_tkeep[0];
  assign ETH_AXIS_S2MM_1_TLAST = ETH_AXIS_S2MM_tlast;
  assign ETH_AXIS_S2MM_1_TVALID = ETH_AXIS_S2MM_tvalid;
  assign ETH_AXIS_S2MM_tready = ETH_AXIS_S2MM_1_TREADY;
  assign M_AXIL_CFG_araddr[31:0] = axi_sc_cfg_M00_AXI_ARADDR;
  assign M_AXIL_CFG_arprot[2:0] = axi_sc_cfg_M00_AXI_ARPROT;
  assign M_AXIL_CFG_arvalid = axi_sc_cfg_M00_AXI_ARVALID;
  assign M_AXIL_CFG_awaddr[31:0] = axi_sc_cfg_M00_AXI_AWADDR;
  assign M_AXIL_CFG_awprot[2:0] = axi_sc_cfg_M00_AXI_AWPROT;
  assign M_AXIL_CFG_awvalid = axi_sc_cfg_M00_AXI_AWVALID;
  assign M_AXIL_CFG_bready = axi_sc_cfg_M00_AXI_BREADY;
  assign M_AXIL_CFG_rready = axi_sc_cfg_M00_AXI_RREADY;
  assign M_AXIL_CFG_wdata[31:0] = axi_sc_cfg_M00_AXI_WDATA;
  assign M_AXIL_CFG_wstrb[3:0] = axi_sc_cfg_M00_AXI_WSTRB;
  assign M_AXIL_CFG_wvalid = axi_sc_cfg_M00_AXI_WVALID;
  assign S_AXI_HP0_1_AWADDR = S_AXI_HP0_awaddr[31:0];
  assign S_AXI_HP0_1_AWBURST = S_AXI_HP0_awburst[1:0];
  assign S_AXI_HP0_1_AWCACHE = S_AXI_HP0_awcache[3:0];
  assign S_AXI_HP0_1_AWLEN = S_AXI_HP0_awlen[7:0];
  assign S_AXI_HP0_1_AWLOCK = S_AXI_HP0_awlock[0];
  assign S_AXI_HP0_1_AWPROT = S_AXI_HP0_awprot[2:0];
  assign S_AXI_HP0_1_AWQOS = S_AXI_HP0_awqos[3:0];
  assign S_AXI_HP0_1_AWSIZE = S_AXI_HP0_awsize[2:0];
  assign S_AXI_HP0_1_AWVALID = S_AXI_HP0_awvalid;
  assign S_AXI_HP0_1_BREADY = S_AXI_HP0_bready;
  assign S_AXI_HP0_1_WDATA = S_AXI_HP0_wdata[63:0];
  assign S_AXI_HP0_1_WLAST = S_AXI_HP0_wlast;
  assign S_AXI_HP0_1_WSTRB = S_AXI_HP0_wstrb[7:0];
  assign S_AXI_HP0_1_WVALID = S_AXI_HP0_wvalid;
  assign S_AXI_HP0_awready = S_AXI_HP0_1_AWREADY;
  assign S_AXI_HP0_bresp[1:0] = S_AXI_HP0_1_BRESP;
  assign S_AXI_HP0_bvalid = S_AXI_HP0_1_BVALID;
  assign S_AXI_HP0_wready = S_AXI_HP0_1_WREADY;
  assign S_AXI_HP1_1_ARADDR = S_AXI_HP1_araddr[31:0];
  assign S_AXI_HP1_1_ARBURST = S_AXI_HP1_arburst[1:0];
  assign S_AXI_HP1_1_ARCACHE = S_AXI_HP1_arcache[3:0];
  assign S_AXI_HP1_1_ARLEN = S_AXI_HP1_arlen[7:0];
  assign S_AXI_HP1_1_ARLOCK = S_AXI_HP1_arlock[0];
  assign S_AXI_HP1_1_ARPROT = S_AXI_HP1_arprot[2:0];
  assign S_AXI_HP1_1_ARQOS = S_AXI_HP1_arqos[3:0];
  assign S_AXI_HP1_1_ARSIZE = S_AXI_HP1_arsize[2:0];
  assign S_AXI_HP1_1_ARVALID = S_AXI_HP1_arvalid;
  assign S_AXI_HP1_1_AWADDR = S_AXI_HP1_awaddr[31:0];
  assign S_AXI_HP1_1_AWBURST = S_AXI_HP1_awburst[1:0];
  assign S_AXI_HP1_1_AWCACHE = S_AXI_HP1_awcache[3:0];
  assign S_AXI_HP1_1_AWLEN = S_AXI_HP1_awlen[7:0];
  assign S_AXI_HP1_1_AWLOCK = S_AXI_HP1_awlock[0];
  assign S_AXI_HP1_1_AWPROT = S_AXI_HP1_awprot[2:0];
  assign S_AXI_HP1_1_AWQOS = S_AXI_HP1_awqos[3:0];
  assign S_AXI_HP1_1_AWSIZE = S_AXI_HP1_awsize[2:0];
  assign S_AXI_HP1_1_AWVALID = S_AXI_HP1_awvalid;
  assign S_AXI_HP1_1_BREADY = S_AXI_HP1_bready;
  assign S_AXI_HP1_1_RREADY = S_AXI_HP1_rready;
  assign S_AXI_HP1_1_WDATA = S_AXI_HP1_wdata[63:0];
  assign S_AXI_HP1_1_WLAST = S_AXI_HP1_wlast;
  assign S_AXI_HP1_1_WSTRB = S_AXI_HP1_wstrb[7:0];
  assign S_AXI_HP1_1_WVALID = S_AXI_HP1_wvalid;
  assign S_AXI_HP1_arready = S_AXI_HP1_1_ARREADY;
  assign S_AXI_HP1_awready = S_AXI_HP1_1_AWREADY;
  assign S_AXI_HP1_bresp[1:0] = S_AXI_HP1_1_BRESP;
  assign S_AXI_HP1_bvalid = S_AXI_HP1_1_BVALID;
  assign S_AXI_HP1_rdata[63:0] = S_AXI_HP1_1_RDATA;
  assign S_AXI_HP1_rlast = S_AXI_HP1_1_RLAST;
  assign S_AXI_HP1_rresp[1:0] = S_AXI_HP1_1_RRESP;
  assign S_AXI_HP1_rvalid = S_AXI_HP1_1_RVALID;
  assign S_AXI_HP1_wready = S_AXI_HP1_1_WREADY;
  assign VIDEO_OUT_tdata[23:0] = mipi_csi2_rx_subsystem_0_video_out_TDATA;
  assign VIDEO_OUT_tdest[9:0] = mipi_csi2_rx_subsystem_0_video_out_TDEST;
  assign VIDEO_OUT_tlast = mipi_csi2_rx_subsystem_0_video_out_TLAST;
  assign VIDEO_OUT_tuser[0] = mipi_csi2_rx_subsystem_0_video_out_TUSER;
  assign VIDEO_OUT_tvalid = mipi_csi2_rx_subsystem_0_video_out_TVALID;
  assign axi_sc_cfg_M00_AXI_ARREADY = M_AXIL_CFG_arready;
  assign axi_sc_cfg_M00_AXI_AWREADY = M_AXIL_CFG_awready;
  assign axi_sc_cfg_M00_AXI_BRESP = M_AXIL_CFG_bresp[1:0];
  assign axi_sc_cfg_M00_AXI_BVALID = M_AXIL_CFG_bvalid;
  assign axi_sc_cfg_M00_AXI_RDATA = M_AXIL_CFG_rdata[31:0];
  assign axi_sc_cfg_M00_AXI_RRESP = M_AXIL_CFG_rresp[1:0];
  assign axi_sc_cfg_M00_AXI_RVALID = M_AXIL_CFG_rvalid;
  assign axi_sc_cfg_M00_AXI_WREADY = M_AXIL_CFG_wready;
  assign frame_done_irq_1 = frame_done_irq;
  assign iic_scl_i_1 = iic_scl_i;
  assign iic_scl_o = axi_iic_0_scl_o;
  assign iic_scl_t = axi_iic_0_scl_t;
  assign iic_sda_i_1 = iic_sda_i;
  assign iic_sda_o = axi_iic_0_sda_o;
  assign iic_sda_t = axi_iic_0_sda_t;
  assign mipi_csi2_rx_subsystem_0_video_out_TREADY = VIDEO_OUT_tready;
  assign mipi_phy_if_1_CLK_N = mipi_phy_if_clk_n;
  assign mipi_phy_if_1_CLK_P = mipi_phy_if_clk_p;
  assign mipi_phy_if_1_DATA_N = mipi_phy_if_data_n[1:0];
  assign mipi_phy_if_1_DATA_P = mipi_phy_if_data_p[1:0];
  assign ov5640_mclk = zynq_ultra_ps_e_0_pl_clk1;
  assign ov5640_pwdn[0] = xlslice_pwdn_Dout;
  assign ov5640_reset_n[0] = xlslice_rst_Dout;
  assign pclk = clk_wiz_0_clk_out1;
  assign pclk_resetn[0] = rst_pclk_0_peripheral_aresetn;
  assign pl_clk = zynq_ultra_ps_e_0_pl_clk0;
  assign rst_n[0] = rst_ps8_0_150m_peripheral_aresetn;
  zynq_imgproc_bd_axi_dma_eth_0 axi_dma_eth
       (.axi_resetn(rst_ps8_0_150m_peripheral_aresetn),
        .m_axi_s2mm_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .m_axi_s2mm_awaddr(axi_dma_eth_M_AXI_S2MM_AWADDR),
        .m_axi_s2mm_awburst(axi_dma_eth_M_AXI_S2MM_AWBURST),
        .m_axi_s2mm_awcache(axi_dma_eth_M_AXI_S2MM_AWCACHE),
        .m_axi_s2mm_awlen(axi_dma_eth_M_AXI_S2MM_AWLEN),
        .m_axi_s2mm_awprot(axi_dma_eth_M_AXI_S2MM_AWPROT),
        .m_axi_s2mm_awready(axi_dma_eth_M_AXI_S2MM_AWREADY),
        .m_axi_s2mm_awsize(axi_dma_eth_M_AXI_S2MM_AWSIZE),
        .m_axi_s2mm_awvalid(axi_dma_eth_M_AXI_S2MM_AWVALID),
        .m_axi_s2mm_bready(axi_dma_eth_M_AXI_S2MM_BREADY),
        .m_axi_s2mm_bresp(axi_dma_eth_M_AXI_S2MM_BRESP),
        .m_axi_s2mm_bvalid(axi_dma_eth_M_AXI_S2MM_BVALID),
        .m_axi_s2mm_wdata(axi_dma_eth_M_AXI_S2MM_WDATA),
        .m_axi_s2mm_wlast(axi_dma_eth_M_AXI_S2MM_WLAST),
        .m_axi_s2mm_wready(axi_dma_eth_M_AXI_S2MM_WREADY),
        .m_axi_s2mm_wstrb(axi_dma_eth_M_AXI_S2MM_WSTRB),
        .m_axi_s2mm_wvalid(axi_dma_eth_M_AXI_S2MM_WVALID),
        .s2mm_introut(axi_dma_eth_s2mm_introut),
        .s_axi_lite_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axi_lite_araddr(axi_sc_cfg_M04_AXI_ARADDR),
        .s_axi_lite_arready(axi_sc_cfg_M04_AXI_ARREADY),
        .s_axi_lite_arvalid(axi_sc_cfg_M04_AXI_ARVALID),
        .s_axi_lite_awaddr(axi_sc_cfg_M04_AXI_AWADDR),
        .s_axi_lite_awready(axi_sc_cfg_M04_AXI_AWREADY),
        .s_axi_lite_awvalid(axi_sc_cfg_M04_AXI_AWVALID),
        .s_axi_lite_bready(axi_sc_cfg_M04_AXI_BREADY),
        .s_axi_lite_bresp(axi_sc_cfg_M04_AXI_BRESP),
        .s_axi_lite_bvalid(axi_sc_cfg_M04_AXI_BVALID),
        .s_axi_lite_rdata(axi_sc_cfg_M04_AXI_RDATA),
        .s_axi_lite_rready(axi_sc_cfg_M04_AXI_RREADY),
        .s_axi_lite_rresp(axi_sc_cfg_M04_AXI_RRESP),
        .s_axi_lite_rvalid(axi_sc_cfg_M04_AXI_RVALID),
        .s_axi_lite_wdata(axi_sc_cfg_M04_AXI_WDATA),
        .s_axi_lite_wready(axi_sc_cfg_M04_AXI_WREADY),
        .s_axi_lite_wvalid(axi_sc_cfg_M04_AXI_WVALID),
        .s_axis_s2mm_tdata(ETH_AXIS_S2MM_1_TDATA),
        .s_axis_s2mm_tkeep(ETH_AXIS_S2MM_1_TKEEP),
        .s_axis_s2mm_tlast(ETH_AXIS_S2MM_1_TLAST),
        .s_axis_s2mm_tready(ETH_AXIS_S2MM_1_TREADY),
        .s_axis_s2mm_tvalid(ETH_AXIS_S2MM_1_TVALID));
  zynq_imgproc_bd_axi_gpio_0_0 axi_gpio_0
       (.gpio_io_o(axi_gpio_0_gpio_io_o),
        .s_axi_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axi_araddr(axi_sc_cfg_M02_AXI_ARADDR),
        .s_axi_aresetn(rst_ps8_0_150m_peripheral_aresetn),
        .s_axi_arready(axi_sc_cfg_M02_AXI_ARREADY),
        .s_axi_arvalid(axi_sc_cfg_M02_AXI_ARVALID),
        .s_axi_awaddr(axi_sc_cfg_M02_AXI_AWADDR),
        .s_axi_awready(axi_sc_cfg_M02_AXI_AWREADY),
        .s_axi_awvalid(axi_sc_cfg_M02_AXI_AWVALID),
        .s_axi_bready(axi_sc_cfg_M02_AXI_BREADY),
        .s_axi_bresp(axi_sc_cfg_M02_AXI_BRESP),
        .s_axi_bvalid(axi_sc_cfg_M02_AXI_BVALID),
        .s_axi_rdata(axi_sc_cfg_M02_AXI_RDATA),
        .s_axi_rready(axi_sc_cfg_M02_AXI_RREADY),
        .s_axi_rresp(axi_sc_cfg_M02_AXI_RRESP),
        .s_axi_rvalid(axi_sc_cfg_M02_AXI_RVALID),
        .s_axi_wdata(axi_sc_cfg_M02_AXI_WDATA),
        .s_axi_wready(axi_sc_cfg_M02_AXI_WREADY),
        .s_axi_wstrb(axi_sc_cfg_M02_AXI_WSTRB),
        .s_axi_wvalid(axi_sc_cfg_M02_AXI_WVALID));
  zynq_imgproc_bd_axi_iic_0_0 axi_iic_0
       (.s_axi_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .s_axi_araddr(axi_sc_cfg_M01_AXI_ARADDR),
        .s_axi_aresetn(rst_ps8_0_150m_peripheral_aresetn),
        .s_axi_arready(axi_sc_cfg_M01_AXI_ARREADY),
        .s_axi_arvalid(axi_sc_cfg_M01_AXI_ARVALID),
        .s_axi_awaddr(axi_sc_cfg_M01_AXI_AWADDR),
        .s_axi_awready(axi_sc_cfg_M01_AXI_AWREADY),
        .s_axi_awvalid(axi_sc_cfg_M01_AXI_AWVALID),
        .s_axi_bready(axi_sc_cfg_M01_AXI_BREADY),
        .s_axi_bresp(axi_sc_cfg_M01_AXI_BRESP),
        .s_axi_bvalid(axi_sc_cfg_M01_AXI_BVALID),
        .s_axi_rdata(axi_sc_cfg_M01_AXI_RDATA),
        .s_axi_rready(axi_sc_cfg_M01_AXI_RREADY),
        .s_axi_rresp(axi_sc_cfg_M01_AXI_RRESP),
        .s_axi_rvalid(axi_sc_cfg_M01_AXI_RVALID),
        .s_axi_wdata(axi_sc_cfg_M01_AXI_WDATA),
        .s_axi_wready(axi_sc_cfg_M01_AXI_WREADY),
        .s_axi_wstrb(axi_sc_cfg_M01_AXI_WSTRB),
        .s_axi_wvalid(axi_sc_cfg_M01_AXI_WVALID),
        .scl_i(iic_scl_i_1),
        .scl_o(axi_iic_0_scl_o),
        .scl_t(axi_iic_0_scl_t),
        .sda_i(iic_sda_i_1),
        .sda_o(axi_iic_0_sda_o),
        .sda_t(axi_iic_0_sda_t));
  zynq_imgproc_bd_axi_sc_cfg_0 axi_sc_cfg
       (.M00_AXI_araddr(axi_sc_cfg_M00_AXI_ARADDR),
        .M00_AXI_arprot(axi_sc_cfg_M00_AXI_ARPROT),
        .M00_AXI_arready(axi_sc_cfg_M00_AXI_ARREADY),
        .M00_AXI_arvalid(axi_sc_cfg_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_sc_cfg_M00_AXI_AWADDR),
        .M00_AXI_awprot(axi_sc_cfg_M00_AXI_AWPROT),
        .M00_AXI_awready(axi_sc_cfg_M00_AXI_AWREADY),
        .M00_AXI_awvalid(axi_sc_cfg_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_sc_cfg_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_sc_cfg_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_sc_cfg_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_sc_cfg_M00_AXI_RDATA),
        .M00_AXI_rready(axi_sc_cfg_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_sc_cfg_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_sc_cfg_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_sc_cfg_M00_AXI_WDATA),
        .M00_AXI_wready(axi_sc_cfg_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_sc_cfg_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_sc_cfg_M00_AXI_WVALID),
        .M01_AXI_araddr(axi_sc_cfg_M01_AXI_ARADDR),
        .M01_AXI_arready(axi_sc_cfg_M01_AXI_ARREADY),
        .M01_AXI_arvalid(axi_sc_cfg_M01_AXI_ARVALID),
        .M01_AXI_awaddr(axi_sc_cfg_M01_AXI_AWADDR),
        .M01_AXI_awready(axi_sc_cfg_M01_AXI_AWREADY),
        .M01_AXI_awvalid(axi_sc_cfg_M01_AXI_AWVALID),
        .M01_AXI_bready(axi_sc_cfg_M01_AXI_BREADY),
        .M01_AXI_bresp(axi_sc_cfg_M01_AXI_BRESP),
        .M01_AXI_bvalid(axi_sc_cfg_M01_AXI_BVALID),
        .M01_AXI_rdata(axi_sc_cfg_M01_AXI_RDATA),
        .M01_AXI_rready(axi_sc_cfg_M01_AXI_RREADY),
        .M01_AXI_rresp(axi_sc_cfg_M01_AXI_RRESP),
        .M01_AXI_rvalid(axi_sc_cfg_M01_AXI_RVALID),
        .M01_AXI_wdata(axi_sc_cfg_M01_AXI_WDATA),
        .M01_AXI_wready(axi_sc_cfg_M01_AXI_WREADY),
        .M01_AXI_wstrb(axi_sc_cfg_M01_AXI_WSTRB),
        .M01_AXI_wvalid(axi_sc_cfg_M01_AXI_WVALID),
        .M02_AXI_araddr(axi_sc_cfg_M02_AXI_ARADDR),
        .M02_AXI_arready(axi_sc_cfg_M02_AXI_ARREADY),
        .M02_AXI_arvalid(axi_sc_cfg_M02_AXI_ARVALID),
        .M02_AXI_awaddr(axi_sc_cfg_M02_AXI_AWADDR),
        .M02_AXI_awready(axi_sc_cfg_M02_AXI_AWREADY),
        .M02_AXI_awvalid(axi_sc_cfg_M02_AXI_AWVALID),
        .M02_AXI_bready(axi_sc_cfg_M02_AXI_BREADY),
        .M02_AXI_bresp(axi_sc_cfg_M02_AXI_BRESP),
        .M02_AXI_bvalid(axi_sc_cfg_M02_AXI_BVALID),
        .M02_AXI_rdata(axi_sc_cfg_M02_AXI_RDATA),
        .M02_AXI_rready(axi_sc_cfg_M02_AXI_RREADY),
        .M02_AXI_rresp(axi_sc_cfg_M02_AXI_RRESP),
        .M02_AXI_rvalid(axi_sc_cfg_M02_AXI_RVALID),
        .M02_AXI_wdata(axi_sc_cfg_M02_AXI_WDATA),
        .M02_AXI_wready(axi_sc_cfg_M02_AXI_WREADY),
        .M02_AXI_wstrb(axi_sc_cfg_M02_AXI_WSTRB),
        .M02_AXI_wvalid(axi_sc_cfg_M02_AXI_WVALID),
        .M03_AXI_araddr(axi_sc_cfg_M03_AXI_ARADDR),
        .M03_AXI_arprot(axi_sc_cfg_M03_AXI_ARPROT),
        .M03_AXI_arready(axi_sc_cfg_M03_AXI_ARREADY),
        .M03_AXI_arvalid(axi_sc_cfg_M03_AXI_ARVALID),
        .M03_AXI_awaddr(axi_sc_cfg_M03_AXI_AWADDR),
        .M03_AXI_awprot(axi_sc_cfg_M03_AXI_AWPROT),
        .M03_AXI_awready(axi_sc_cfg_M03_AXI_AWREADY),
        .M03_AXI_awvalid(axi_sc_cfg_M03_AXI_AWVALID),
        .M03_AXI_bready(axi_sc_cfg_M03_AXI_BREADY),
        .M03_AXI_bresp(axi_sc_cfg_M03_AXI_BRESP),
        .M03_AXI_bvalid(axi_sc_cfg_M03_AXI_BVALID),
        .M03_AXI_rdata(axi_sc_cfg_M03_AXI_RDATA),
        .M03_AXI_rready(axi_sc_cfg_M03_AXI_RREADY),
        .M03_AXI_rresp(axi_sc_cfg_M03_AXI_RRESP),
        .M03_AXI_rvalid(axi_sc_cfg_M03_AXI_RVALID),
        .M03_AXI_wdata(axi_sc_cfg_M03_AXI_WDATA),
        .M03_AXI_wready(axi_sc_cfg_M03_AXI_WREADY),
        .M03_AXI_wstrb(axi_sc_cfg_M03_AXI_WSTRB),
        .M03_AXI_wvalid(axi_sc_cfg_M03_AXI_WVALID),
        .M04_AXI_araddr(axi_sc_cfg_M04_AXI_ARADDR),
        .M04_AXI_arready(axi_sc_cfg_M04_AXI_ARREADY),
        .M04_AXI_arvalid(axi_sc_cfg_M04_AXI_ARVALID),
        .M04_AXI_awaddr(axi_sc_cfg_M04_AXI_AWADDR),
        .M04_AXI_awready(axi_sc_cfg_M04_AXI_AWREADY),
        .M04_AXI_awvalid(axi_sc_cfg_M04_AXI_AWVALID),
        .M04_AXI_bready(axi_sc_cfg_M04_AXI_BREADY),
        .M04_AXI_bresp(axi_sc_cfg_M04_AXI_BRESP),
        .M04_AXI_bvalid(axi_sc_cfg_M04_AXI_BVALID),
        .M04_AXI_rdata(axi_sc_cfg_M04_AXI_RDATA),
        .M04_AXI_rready(axi_sc_cfg_M04_AXI_RREADY),
        .M04_AXI_rresp(axi_sc_cfg_M04_AXI_RRESP),
        .M04_AXI_rvalid(axi_sc_cfg_M04_AXI_RVALID),
        .M04_AXI_wdata(axi_sc_cfg_M04_AXI_WDATA),
        .M04_AXI_wready(axi_sc_cfg_M04_AXI_WREADY),
        .M04_AXI_wvalid(axi_sc_cfg_M04_AXI_WVALID),
        .S00_AXI_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR),
        .S00_AXI_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST),
        .S00_AXI_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE),
        .S00_AXI_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID),
        .S00_AXI_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN),
        .S00_AXI_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK),
        .S00_AXI_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT),
        .S00_AXI_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS),
        .S00_AXI_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY),
        .S00_AXI_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE),
        .S00_AXI_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER),
        .S00_AXI_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID),
        .S00_AXI_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR),
        .S00_AXI_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST),
        .S00_AXI_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE),
        .S00_AXI_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID),
        .S00_AXI_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN),
        .S00_AXI_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK),
        .S00_AXI_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT),
        .S00_AXI_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS),
        .S00_AXI_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY),
        .S00_AXI_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE),
        .S00_AXI_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER),
        .S00_AXI_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID),
        .S00_AXI_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID),
        .S00_AXI_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY),
        .S00_AXI_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP),
        .S00_AXI_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID),
        .S00_AXI_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA),
        .S00_AXI_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID),
        .S00_AXI_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST),
        .S00_AXI_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY),
        .S00_AXI_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP),
        .S00_AXI_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID),
        .S00_AXI_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA),
        .S00_AXI_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST),
        .S00_AXI_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY),
        .S00_AXI_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB),
        .S00_AXI_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_150m_interconnect_aresetn));
  zynq_imgproc_bd_axi_sc_hp0_0 axi_sc_hp0
       (.M00_AXI_awaddr(axi_sc_hp0_M00_AXI_AWADDR),
        .M00_AXI_awburst(axi_sc_hp0_M00_AXI_AWBURST),
        .M00_AXI_awcache(axi_sc_hp0_M00_AXI_AWCACHE),
        .M00_AXI_awlen(axi_sc_hp0_M00_AXI_AWLEN),
        .M00_AXI_awlock(axi_sc_hp0_M00_AXI_AWLOCK),
        .M00_AXI_awprot(axi_sc_hp0_M00_AXI_AWPROT),
        .M00_AXI_awqos(axi_sc_hp0_M00_AXI_AWQOS),
        .M00_AXI_awready(axi_sc_hp0_M00_AXI_AWREADY),
        .M00_AXI_awsize(axi_sc_hp0_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(axi_sc_hp0_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_sc_hp0_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_sc_hp0_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_sc_hp0_M00_AXI_BVALID),
        .M00_AXI_wdata(axi_sc_hp0_M00_AXI_WDATA),
        .M00_AXI_wlast(axi_sc_hp0_M00_AXI_WLAST),
        .M00_AXI_wready(axi_sc_hp0_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_sc_hp0_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_sc_hp0_M00_AXI_WVALID),
        .S00_AXI_awaddr(S_AXI_HP0_1_AWADDR),
        .S00_AXI_awburst(S_AXI_HP0_1_AWBURST),
        .S00_AXI_awcache(S_AXI_HP0_1_AWCACHE),
        .S00_AXI_awlen(S_AXI_HP0_1_AWLEN),
        .S00_AXI_awlock(S_AXI_HP0_1_AWLOCK),
        .S00_AXI_awprot(S_AXI_HP0_1_AWPROT),
        .S00_AXI_awqos(S_AXI_HP0_1_AWQOS),
        .S00_AXI_awready(S_AXI_HP0_1_AWREADY),
        .S00_AXI_awsize(S_AXI_HP0_1_AWSIZE),
        .S00_AXI_awvalid(S_AXI_HP0_1_AWVALID),
        .S00_AXI_bready(S_AXI_HP0_1_BREADY),
        .S00_AXI_bresp(S_AXI_HP0_1_BRESP),
        .S00_AXI_bvalid(S_AXI_HP0_1_BVALID),
        .S00_AXI_wdata(S_AXI_HP0_1_WDATA),
        .S00_AXI_wlast(S_AXI_HP0_1_WLAST),
        .S00_AXI_wready(S_AXI_HP0_1_WREADY),
        .S00_AXI_wstrb(S_AXI_HP0_1_WSTRB),
        .S00_AXI_wvalid(S_AXI_HP0_1_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_150m_interconnect_aresetn));
  zynq_imgproc_bd_axi_sc_hp1_0 axi_sc_hp1
       (.M00_AXI_araddr(axi_sc_hp1_M00_AXI_ARADDR),
        .M00_AXI_arburst(axi_sc_hp1_M00_AXI_ARBURST),
        .M00_AXI_arcache(axi_sc_hp1_M00_AXI_ARCACHE),
        .M00_AXI_arlen(axi_sc_hp1_M00_AXI_ARLEN),
        .M00_AXI_arlock(axi_sc_hp1_M00_AXI_ARLOCK),
        .M00_AXI_arprot(axi_sc_hp1_M00_AXI_ARPROT),
        .M00_AXI_arqos(axi_sc_hp1_M00_AXI_ARQOS),
        .M00_AXI_arready(axi_sc_hp1_M00_AXI_ARREADY),
        .M00_AXI_arsize(axi_sc_hp1_M00_AXI_ARSIZE),
        .M00_AXI_arvalid(axi_sc_hp1_M00_AXI_ARVALID),
        .M00_AXI_awaddr(axi_sc_hp1_M00_AXI_AWADDR),
        .M00_AXI_awburst(axi_sc_hp1_M00_AXI_AWBURST),
        .M00_AXI_awcache(axi_sc_hp1_M00_AXI_AWCACHE),
        .M00_AXI_awlen(axi_sc_hp1_M00_AXI_AWLEN),
        .M00_AXI_awlock(axi_sc_hp1_M00_AXI_AWLOCK),
        .M00_AXI_awprot(axi_sc_hp1_M00_AXI_AWPROT),
        .M00_AXI_awqos(axi_sc_hp1_M00_AXI_AWQOS),
        .M00_AXI_awready(axi_sc_hp1_M00_AXI_AWREADY),
        .M00_AXI_awsize(axi_sc_hp1_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(axi_sc_hp1_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_sc_hp1_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_sc_hp1_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_sc_hp1_M00_AXI_BVALID),
        .M00_AXI_rdata(axi_sc_hp1_M00_AXI_RDATA),
        .M00_AXI_rlast(axi_sc_hp1_M00_AXI_RLAST),
        .M00_AXI_rready(axi_sc_hp1_M00_AXI_RREADY),
        .M00_AXI_rresp(axi_sc_hp1_M00_AXI_RRESP),
        .M00_AXI_rvalid(axi_sc_hp1_M00_AXI_RVALID),
        .M00_AXI_wdata(axi_sc_hp1_M00_AXI_WDATA),
        .M00_AXI_wlast(axi_sc_hp1_M00_AXI_WLAST),
        .M00_AXI_wready(axi_sc_hp1_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_sc_hp1_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_sc_hp1_M00_AXI_WVALID),
        .S00_AXI_araddr(S_AXI_HP1_1_ARADDR),
        .S00_AXI_arburst(S_AXI_HP1_1_ARBURST),
        .S00_AXI_arcache(S_AXI_HP1_1_ARCACHE),
        .S00_AXI_arlen(S_AXI_HP1_1_ARLEN),
        .S00_AXI_arlock(S_AXI_HP1_1_ARLOCK),
        .S00_AXI_arprot(S_AXI_HP1_1_ARPROT),
        .S00_AXI_arqos(S_AXI_HP1_1_ARQOS),
        .S00_AXI_arready(S_AXI_HP1_1_ARREADY),
        .S00_AXI_arsize(S_AXI_HP1_1_ARSIZE),
        .S00_AXI_arvalid(S_AXI_HP1_1_ARVALID),
        .S00_AXI_awaddr(S_AXI_HP1_1_AWADDR),
        .S00_AXI_awburst(S_AXI_HP1_1_AWBURST),
        .S00_AXI_awcache(S_AXI_HP1_1_AWCACHE),
        .S00_AXI_awlen(S_AXI_HP1_1_AWLEN),
        .S00_AXI_awlock(S_AXI_HP1_1_AWLOCK),
        .S00_AXI_awprot(S_AXI_HP1_1_AWPROT),
        .S00_AXI_awqos(S_AXI_HP1_1_AWQOS),
        .S00_AXI_awready(S_AXI_HP1_1_AWREADY),
        .S00_AXI_awsize(S_AXI_HP1_1_AWSIZE),
        .S00_AXI_awvalid(S_AXI_HP1_1_AWVALID),
        .S00_AXI_bready(S_AXI_HP1_1_BREADY),
        .S00_AXI_bresp(S_AXI_HP1_1_BRESP),
        .S00_AXI_bvalid(S_AXI_HP1_1_BVALID),
        .S00_AXI_rdata(S_AXI_HP1_1_RDATA),
        .S00_AXI_rlast(S_AXI_HP1_1_RLAST),
        .S00_AXI_rready(S_AXI_HP1_1_RREADY),
        .S00_AXI_rresp(S_AXI_HP1_1_RRESP),
        .S00_AXI_rvalid(S_AXI_HP1_1_RVALID),
        .S00_AXI_wdata(S_AXI_HP1_1_WDATA),
        .S00_AXI_wlast(S_AXI_HP1_1_WLAST),
        .S00_AXI_wready(S_AXI_HP1_1_WREADY),
        .S00_AXI_wstrb(S_AXI_HP1_1_WSTRB),
        .S00_AXI_wvalid(S_AXI_HP1_1_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_150m_interconnect_aresetn));
  zynq_imgproc_bd_axi_sc_hp2_0 axi_sc_hp2
       (.M00_AXI_awaddr(axi_sc_hp2_M00_AXI_AWADDR),
        .M00_AXI_awburst(axi_sc_hp2_M00_AXI_AWBURST),
        .M00_AXI_awcache(axi_sc_hp2_M00_AXI_AWCACHE),
        .M00_AXI_awlen(axi_sc_hp2_M00_AXI_AWLEN),
        .M00_AXI_awlock(axi_sc_hp2_M00_AXI_AWLOCK),
        .M00_AXI_awprot(axi_sc_hp2_M00_AXI_AWPROT),
        .M00_AXI_awqos(axi_sc_hp2_M00_AXI_AWQOS),
        .M00_AXI_awready(axi_sc_hp2_M00_AXI_AWREADY),
        .M00_AXI_awsize(axi_sc_hp2_M00_AXI_AWSIZE),
        .M00_AXI_awvalid(axi_sc_hp2_M00_AXI_AWVALID),
        .M00_AXI_bready(axi_sc_hp2_M00_AXI_BREADY),
        .M00_AXI_bresp(axi_sc_hp2_M00_AXI_BRESP),
        .M00_AXI_bvalid(axi_sc_hp2_M00_AXI_BVALID),
        .M00_AXI_wdata(axi_sc_hp2_M00_AXI_WDATA),
        .M00_AXI_wlast(axi_sc_hp2_M00_AXI_WLAST),
        .M00_AXI_wready(axi_sc_hp2_M00_AXI_WREADY),
        .M00_AXI_wstrb(axi_sc_hp2_M00_AXI_WSTRB),
        .M00_AXI_wvalid(axi_sc_hp2_M00_AXI_WVALID),
        .S00_AXI_awaddr(axi_dma_eth_M_AXI_S2MM_AWADDR),
        .S00_AXI_awburst(axi_dma_eth_M_AXI_S2MM_AWBURST),
        .S00_AXI_awcache(axi_dma_eth_M_AXI_S2MM_AWCACHE),
        .S00_AXI_awlen(axi_dma_eth_M_AXI_S2MM_AWLEN),
        .S00_AXI_awlock(1'b0),
        .S00_AXI_awprot(axi_dma_eth_M_AXI_S2MM_AWPROT),
        .S00_AXI_awqos({1'b0,1'b0,1'b0,1'b0}),
        .S00_AXI_awready(axi_dma_eth_M_AXI_S2MM_AWREADY),
        .S00_AXI_awsize(axi_dma_eth_M_AXI_S2MM_AWSIZE),
        .S00_AXI_awvalid(axi_dma_eth_M_AXI_S2MM_AWVALID),
        .S00_AXI_bready(axi_dma_eth_M_AXI_S2MM_BREADY),
        .S00_AXI_bresp(axi_dma_eth_M_AXI_S2MM_BRESP),
        .S00_AXI_bvalid(axi_dma_eth_M_AXI_S2MM_BVALID),
        .S00_AXI_wdata(axi_dma_eth_M_AXI_S2MM_WDATA),
        .S00_AXI_wlast(axi_dma_eth_M_AXI_S2MM_WLAST),
        .S00_AXI_wready(axi_dma_eth_M_AXI_S2MM_WREADY),
        .S00_AXI_wstrb(axi_dma_eth_M_AXI_S2MM_WSTRB),
        .S00_AXI_wvalid(axi_dma_eth_M_AXI_S2MM_WVALID),
        .aclk(zynq_ultra_ps_e_0_pl_clk0),
        .aresetn(rst_ps8_0_150m_interconnect_aresetn));
  zynq_imgproc_bd_clk_wiz_0_0 clk_wiz_0
       (.clk_in1(zynq_ultra_ps_e_0_pl_clk0),
        .clk_out1(clk_wiz_0_clk_out1),
        .locked(clk_wiz_0_locked));
  zynq_imgproc_bd_clk_wiz_mipi_ref_0 clk_wiz_mipi_ref
       (.clk_in1(zynq_ultra_ps_e_0_pl_clk0),
        .clk_out1(clk_wiz_mipi_ref_clk_out1));
  zynq_imgproc_bd_mipi_csi2_rx_subsystem_0_0 mipi_csi2_rx_subsystem_0
       (.csirxss_s_axi_araddr(axi_sc_cfg_M03_AXI_ARADDR),
        .csirxss_s_axi_arprot(axi_sc_cfg_M03_AXI_ARPROT),
        .csirxss_s_axi_arready(axi_sc_cfg_M03_AXI_ARREADY),
        .csirxss_s_axi_arvalid(axi_sc_cfg_M03_AXI_ARVALID),
        .csirxss_s_axi_awaddr(axi_sc_cfg_M03_AXI_AWADDR),
        .csirxss_s_axi_awprot(axi_sc_cfg_M03_AXI_AWPROT),
        .csirxss_s_axi_awready(axi_sc_cfg_M03_AXI_AWREADY),
        .csirxss_s_axi_awvalid(axi_sc_cfg_M03_AXI_AWVALID),
        .csirxss_s_axi_bready(axi_sc_cfg_M03_AXI_BREADY),
        .csirxss_s_axi_bresp(axi_sc_cfg_M03_AXI_BRESP),
        .csirxss_s_axi_bvalid(axi_sc_cfg_M03_AXI_BVALID),
        .csirxss_s_axi_rdata(axi_sc_cfg_M03_AXI_RDATA),
        .csirxss_s_axi_rready(axi_sc_cfg_M03_AXI_RREADY),
        .csirxss_s_axi_rresp(axi_sc_cfg_M03_AXI_RRESP),
        .csirxss_s_axi_rvalid(axi_sc_cfg_M03_AXI_RVALID),
        .csirxss_s_axi_wdata(axi_sc_cfg_M03_AXI_WDATA),
        .csirxss_s_axi_wready(axi_sc_cfg_M03_AXI_WREADY),
        .csirxss_s_axi_wstrb(axi_sc_cfg_M03_AXI_WSTRB),
        .csirxss_s_axi_wvalid(axi_sc_cfg_M03_AXI_WVALID),
        .dphy_clk_200M(clk_wiz_mipi_ref_clk_out1),
        .lite_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .lite_aresetn(rst_ps8_0_150m_peripheral_aresetn),
        .mipi_phy_if_clk_n(mipi_phy_if_1_CLK_N),
        .mipi_phy_if_clk_p(mipi_phy_if_1_CLK_P),
        .mipi_phy_if_data_n(mipi_phy_if_1_DATA_N),
        .mipi_phy_if_data_p(mipi_phy_if_1_DATA_P),
        .video_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .video_aresetn(rst_ps8_0_150m_peripheral_aresetn),
        .video_out_tdata(mipi_csi2_rx_subsystem_0_video_out_TDATA),
        .video_out_tdest(mipi_csi2_rx_subsystem_0_video_out_TDEST),
        .video_out_tlast(mipi_csi2_rx_subsystem_0_video_out_TLAST),
        .video_out_tready(mipi_csi2_rx_subsystem_0_video_out_TREADY),
        .video_out_tuser(mipi_csi2_rx_subsystem_0_video_out_TUSER),
        .video_out_tvalid(mipi_csi2_rx_subsystem_0_video_out_TVALID));
  zynq_imgproc_bd_rst_pclk_0_0 rst_pclk_0
       (.aux_reset_in(1'b1),
        .dcm_locked(clk_wiz_0_locked),
        .ext_reset_in(zynq_ultra_ps_e_0_pl_resetn0),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_pclk_0_peripheral_aresetn),
        .slowest_sync_clk(clk_wiz_0_clk_out1));
  zynq_imgproc_bd_rst_ps8_0_150m_0 rst_ps8_0_150m
       (.aux_reset_in(1'b1),
        .dcm_locked(1'b1),
        .ext_reset_in(zynq_ultra_ps_e_0_pl_resetn0),
        .interconnect_aresetn(rst_ps8_0_150m_interconnect_aresetn),
        .mb_debug_sys_rst(1'b0),
        .peripheral_aresetn(rst_ps8_0_150m_peripheral_aresetn),
        .slowest_sync_clk(zynq_ultra_ps_e_0_pl_clk0));
  zynq_imgproc_bd_xlslice_pwdn_0 xlslice_pwdn
       (.Din(axi_gpio_0_gpio_io_o),
        .Dout(xlslice_pwdn_Dout));
  zynq_imgproc_bd_xlslice_rst_0 xlslice_rst
       (.Din(axi_gpio_0_gpio_io_o),
        .Dout(xlslice_rst_Dout));
  zynq_imgproc_bd_zynq_ultra_ps_e_0_0 zynq_ultra_ps_e_0
       (.maxigp0_araddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARADDR),
        .maxigp0_arburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARBURST),
        .maxigp0_arcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARCACHE),
        .maxigp0_arid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARID),
        .maxigp0_arlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLEN),
        .maxigp0_arlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARLOCK),
        .maxigp0_arprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARPROT),
        .maxigp0_arqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARQOS),
        .maxigp0_arready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARREADY),
        .maxigp0_arsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARSIZE),
        .maxigp0_aruser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARUSER),
        .maxigp0_arvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_ARVALID),
        .maxigp0_awaddr(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWADDR),
        .maxigp0_awburst(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWBURST),
        .maxigp0_awcache(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWCACHE),
        .maxigp0_awid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWID),
        .maxigp0_awlen(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLEN),
        .maxigp0_awlock(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWLOCK),
        .maxigp0_awprot(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWPROT),
        .maxigp0_awqos(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWQOS),
        .maxigp0_awready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWREADY),
        .maxigp0_awsize(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWSIZE),
        .maxigp0_awuser(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWUSER),
        .maxigp0_awvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_AWVALID),
        .maxigp0_bid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BID),
        .maxigp0_bready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BREADY),
        .maxigp0_bresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BRESP),
        .maxigp0_bvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_BVALID),
        .maxigp0_rdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RDATA),
        .maxigp0_rid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RID),
        .maxigp0_rlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RLAST),
        .maxigp0_rready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RREADY),
        .maxigp0_rresp(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RRESP),
        .maxigp0_rvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_RVALID),
        .maxigp0_wdata(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WDATA),
        .maxigp0_wlast(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WLAST),
        .maxigp0_wready(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WREADY),
        .maxigp0_wstrb(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WSTRB),
        .maxigp0_wvalid(zynq_ultra_ps_e_0_M_AXI_HPM0_FPD_WVALID),
        .maxigp2_arready(1'b0),
        .maxigp2_awready(1'b0),
        .maxigp2_bid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .maxigp2_bresp({1'b0,1'b0}),
        .maxigp2_bvalid(1'b0),
        .maxigp2_rdata({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .maxigp2_rid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .maxigp2_rlast(1'b0),
        .maxigp2_rresp({1'b0,1'b0}),
        .maxigp2_rvalid(1'b0),
        .maxigp2_wready(1'b0),
        .maxihpm0_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .maxihpm0_lpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .pl_clk0(zynq_ultra_ps_e_0_pl_clk0),
        .pl_clk1(zynq_ultra_ps_e_0_pl_clk1),
        .pl_ps_irq0(frame_done_irq_1),
        .pl_ps_irq1(axi_dma_eth_s2mm_introut),
        .pl_resetn0(zynq_ultra_ps_e_0_pl_resetn0),
        .saxigp2_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_arburst({1'b0,1'b1}),
        .saxigp2_arcache({1'b0,1'b0,1'b1,1'b1}),
        .saxigp2_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_arlock(1'b0),
        .saxigp2_arprot({1'b0,1'b0,1'b0}),
        .saxigp2_arqos({1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_arsize({1'b0,1'b1,1'b1}),
        .saxigp2_aruser(1'b0),
        .saxigp2_arvalid(1'b0),
        .saxigp2_awaddr(axi_sc_hp0_M00_AXI_AWADDR),
        .saxigp2_awburst(axi_sc_hp0_M00_AXI_AWBURST),
        .saxigp2_awcache(axi_sc_hp0_M00_AXI_AWCACHE),
        .saxigp2_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp2_awlen(axi_sc_hp0_M00_AXI_AWLEN),
        .saxigp2_awlock(axi_sc_hp0_M00_AXI_AWLOCK),
        .saxigp2_awprot(axi_sc_hp0_M00_AXI_AWPROT),
        .saxigp2_awqos(axi_sc_hp0_M00_AXI_AWQOS),
        .saxigp2_awready(axi_sc_hp0_M00_AXI_AWREADY),
        .saxigp2_awsize(axi_sc_hp0_M00_AXI_AWSIZE),
        .saxigp2_awuser(1'b0),
        .saxigp2_awvalid(axi_sc_hp0_M00_AXI_AWVALID),
        .saxigp2_bready(axi_sc_hp0_M00_AXI_BREADY),
        .saxigp2_bresp(axi_sc_hp0_M00_AXI_BRESP),
        .saxigp2_bvalid(axi_sc_hp0_M00_AXI_BVALID),
        .saxigp2_rready(1'b0),
        .saxigp2_wdata(axi_sc_hp0_M00_AXI_WDATA),
        .saxigp2_wlast(axi_sc_hp0_M00_AXI_WLAST),
        .saxigp2_wready(axi_sc_hp0_M00_AXI_WREADY),
        .saxigp2_wstrb(axi_sc_hp0_M00_AXI_WSTRB),
        .saxigp2_wvalid(axi_sc_hp0_M00_AXI_WVALID),
        .saxigp3_araddr(axi_sc_hp1_M00_AXI_ARADDR),
        .saxigp3_arburst(axi_sc_hp1_M00_AXI_ARBURST),
        .saxigp3_arcache(axi_sc_hp1_M00_AXI_ARCACHE),
        .saxigp3_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp3_arlen(axi_sc_hp1_M00_AXI_ARLEN),
        .saxigp3_arlock(axi_sc_hp1_M00_AXI_ARLOCK),
        .saxigp3_arprot(axi_sc_hp1_M00_AXI_ARPROT),
        .saxigp3_arqos(axi_sc_hp1_M00_AXI_ARQOS),
        .saxigp3_arready(axi_sc_hp1_M00_AXI_ARREADY),
        .saxigp3_arsize(axi_sc_hp1_M00_AXI_ARSIZE),
        .saxigp3_aruser(1'b0),
        .saxigp3_arvalid(axi_sc_hp1_M00_AXI_ARVALID),
        .saxigp3_awaddr(axi_sc_hp1_M00_AXI_AWADDR),
        .saxigp3_awburst(axi_sc_hp1_M00_AXI_AWBURST),
        .saxigp3_awcache(axi_sc_hp1_M00_AXI_AWCACHE),
        .saxigp3_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp3_awlen(axi_sc_hp1_M00_AXI_AWLEN),
        .saxigp3_awlock(axi_sc_hp1_M00_AXI_AWLOCK),
        .saxigp3_awprot(axi_sc_hp1_M00_AXI_AWPROT),
        .saxigp3_awqos(axi_sc_hp1_M00_AXI_AWQOS),
        .saxigp3_awready(axi_sc_hp1_M00_AXI_AWREADY),
        .saxigp3_awsize(axi_sc_hp1_M00_AXI_AWSIZE),
        .saxigp3_awuser(1'b0),
        .saxigp3_awvalid(axi_sc_hp1_M00_AXI_AWVALID),
        .saxigp3_bready(axi_sc_hp1_M00_AXI_BREADY),
        .saxigp3_bresp(axi_sc_hp1_M00_AXI_BRESP),
        .saxigp3_bvalid(axi_sc_hp1_M00_AXI_BVALID),
        .saxigp3_rdata(axi_sc_hp1_M00_AXI_RDATA),
        .saxigp3_rlast(axi_sc_hp1_M00_AXI_RLAST),
        .saxigp3_rready(axi_sc_hp1_M00_AXI_RREADY),
        .saxigp3_rresp(axi_sc_hp1_M00_AXI_RRESP),
        .saxigp3_rvalid(axi_sc_hp1_M00_AXI_RVALID),
        .saxigp3_wdata(axi_sc_hp1_M00_AXI_WDATA),
        .saxigp3_wlast(axi_sc_hp1_M00_AXI_WLAST),
        .saxigp3_wready(axi_sc_hp1_M00_AXI_WREADY),
        .saxigp3_wstrb(axi_sc_hp1_M00_AXI_WSTRB),
        .saxigp3_wvalid(axi_sc_hp1_M00_AXI_WVALID),
        .saxigp4_araddr({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_arburst({1'b0,1'b1}),
        .saxigp4_arcache({1'b0,1'b0,1'b1,1'b1}),
        .saxigp4_arid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_arlen({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_arlock(1'b0),
        .saxigp4_arprot({1'b0,1'b0,1'b0}),
        .saxigp4_arqos({1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_arsize({1'b0,1'b1,1'b1}),
        .saxigp4_aruser(1'b0),
        .saxigp4_arvalid(1'b0),
        .saxigp4_awaddr(axi_sc_hp2_M00_AXI_AWADDR),
        .saxigp4_awburst(axi_sc_hp2_M00_AXI_AWBURST),
        .saxigp4_awcache(axi_sc_hp2_M00_AXI_AWCACHE),
        .saxigp4_awid({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .saxigp4_awlen(axi_sc_hp2_M00_AXI_AWLEN),
        .saxigp4_awlock(axi_sc_hp2_M00_AXI_AWLOCK),
        .saxigp4_awprot(axi_sc_hp2_M00_AXI_AWPROT),
        .saxigp4_awqos(axi_sc_hp2_M00_AXI_AWQOS),
        .saxigp4_awready(axi_sc_hp2_M00_AXI_AWREADY),
        .saxigp4_awsize(axi_sc_hp2_M00_AXI_AWSIZE),
        .saxigp4_awuser(1'b0),
        .saxigp4_awvalid(axi_sc_hp2_M00_AXI_AWVALID),
        .saxigp4_bready(axi_sc_hp2_M00_AXI_BREADY),
        .saxigp4_bresp(axi_sc_hp2_M00_AXI_BRESP),
        .saxigp4_bvalid(axi_sc_hp2_M00_AXI_BVALID),
        .saxigp4_rready(1'b0),
        .saxigp4_wdata(axi_sc_hp2_M00_AXI_WDATA),
        .saxigp4_wlast(axi_sc_hp2_M00_AXI_WLAST),
        .saxigp4_wready(axi_sc_hp2_M00_AXI_WREADY),
        .saxigp4_wstrb(axi_sc_hp2_M00_AXI_WSTRB),
        .saxigp4_wvalid(axi_sc_hp2_M00_AXI_WVALID),
        .saxihp0_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .saxihp1_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0),
        .saxihp2_fpd_aclk(zynq_ultra_ps_e_0_pl_clk0));
endmodule
