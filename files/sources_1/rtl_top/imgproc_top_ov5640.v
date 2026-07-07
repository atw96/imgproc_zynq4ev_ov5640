// imgproc_top_ov5640.v -- Vivado 综合顶层
// 板卡: ALINX AXU4EVB (xczu4ev-sfvc784-2-i)，传感器: AV5641 (OV5640 MIPI CSI-2)
//
// 模块层次:
//   imgproc_top_ov5640 (本文件)
//     +-- zynq_imgproc_bd_wrapper  [BD: PS + MIPI RX + I2C + GPIO]
//     +-- u_axil_cfg   (axil_cfg_reg)
//     +-- u_sensor_if  (sensor_if, MIPI_MODE=1)
//     +-- u_preproc    (img_preprocessor)
//     +-- u_linebuf    (line_buffer_ctrl)
//     +-- u_detail_enh (local_detail_enhance_11x11)
//     +-- u_bilateral  (bilateral_filter)
//     +-- u_clahe      (clahe_engine)
//     +-- u_ddr3_buf   (ddr3_pixel_buf)
//     +-- u_display    (zynq_display_ctrl)
//     +-- u_frame_eth  (project/src/frame_eth_tx.v → BD AXI DMA S2MM)
//
// BD 对外接口由 create_bd_ov5640.tcl 定义端口名。
//   BD -> 本 RTL:
//     pl_clk, rst_n          系统时钟 ~150 MHz / 复位 (pl_clk 域)
//     pclk, pclk_resetn      HDMI 像素时钟 148.5 MHz / 复位 (MMCM)
//     VIDEO_OUT_tdata[19:0], VIDEO_OUT_tvalid, VIDEO_OUT_tlast,
//     VIDEO_OUT_tuser, VIDEO_OUT_tready
//     M_AXIL_CFG_* (AXI-Lite Master -> ISP 配置从机)
//   本 RTL -> BD:
//     S_AXI_HP0_* (AXI4 只写 64-bit -> display_ctrl)
//     S_AXI_HP1_* (AXI4 读写 64-bit -> ddr3_pixel_buf)
//     frame_done_irq
//     ETH_AXIS_S2MM_* — PL frame_eth_tx → BD AXI DMA S2MM（送 PS DDR）
//   物理引脚:
//     mipi_phy_if_*, iic_scl_*, iic_sda_*
//     ov5640_reset_n, ov5640_pwdn, ov5640_mclk
//     hdmi_d[23:0], hdmi_clk, hdmi_hsync, hdmi_vsync, hdmi_de
// =============================================================================

`timescale 1ns/1ps

module imgproc_top_ov5640 #(
    parameter RAW_W    = 10,   // OV5640 RAW10
    parameter PIXEL_W  = 13,   // 内部 Q0.13 定点像素
    parameter AXI_DW   = 64,
    parameter AXI_AW   = 32,
    parameter LINE_LEN = 1920, // OV5640 1080p
    parameter IMG_W    = 1920,
    parameter IMG_H    = 1080,
    /* Compile-time ISP/ETH mux (Vivado generic override for MIPI bit) */
    parameter ISP_USE_TEST_RAW = 1'b1,
    parameter ETH_USE_CLAHE    = 1'b1
)(
    // -------------------------------------------------------------------------
    // 物理引脚（PACKAGE_PIN / IOSTANDARD 见 XDC）
    // -------------------------------------------------------------------------

    // MIPI CSI-2 差分接口（接 BD mipi_phy_if）
    input  wire        mipi_phy_if_clk_p,
    input  wire        mipi_phy_if_clk_n,
    input  wire [1:0]  mipi_phy_if_data_p,
    input  wire [1:0]  mipi_phy_if_data_n,

    // I2C 双向总线（IOBUF 在本顶层）
    inout  wire        iic_scl_io,
    inout  wire        iic_sda_io,

    // OV5640 控制 GPIO
    //output wire        ov5640_reset_n,
    output wire        ov5640_pwdn,
    output wire        ov5640_mclk,    // 24 MHz from PS FCLK_CLK1

    // -------------------------------------------------------------------------
    // HDMI 输出 -> ADV7511 并行 24-bit RGB (Bank 66, LVCMOS33)
    //   pclk = 148.5 MHz (MMCM)，1920x1080@60Hz 灰度显示
    //   灰度映射: R=G=B = Y[12:5]
    // -------------------------------------------------------------------------
    output wire                  hdmi_clk,
    output wire                  hdmi_hsync,
    output wire                  hdmi_vsync,
    output wire                  hdmi_de,
    output wire [23:0]           hdmi_d

    // -------------------------------------------------------------------------
    // 状态输出（可选引出顶层）
    // -------------------------------------------------------------------------
    //output wire [31:0]           dead_pixel_cnt_out,
    //output wire                  buf_sel_out
);

    // =========================================================================
    // A. 内部信号声明与 BD / RTL 互连
    // =========================================================================

    // A1. 时钟与复位（来自 BD）
    wire        pl_clk;       // ~150 MHz (PS FCLK_CLK0，主 AXI / ISP 时钟)
    wire        rst_n;        // 低有效复位 (pl_clk 域 peripheral_aresetn)
    wire        pclk;         // 148.5 MHz HDMI 像素时钟 (MMCM clk_wiz 输出)
    wire        pclk_resetn;  // 低有效复位 (pclk 域，MMCM locked 后有效)

    // A8. 显示控制器 VGA 中间信号 (display_ctrl -> 顶层再送 HDMI)
    wire                  vga_hsync_i;
    wire                  vga_vsync_i;
    wire                  vga_de_i;
    wire [PIXEL_W-1:0]    vga_pixel_i;
    wire                  vga_active_i;

    // A2. MIPI AXI-Stream（来自 BD VIDEO_OUT）
    // Vivado 为 Master AXIS 生成的信号名:
    //   VIDEO_OUT_tdata, VIDEO_OUT_tvalid, VIDEO_OUT_tready,
    //   VIDEO_OUT_tlast, VIDEO_OUT_tuser
    wire [19:0] mipi_tdata_w;
    wire        mipi_tvalid_w;
    wire        mipi_tlast_w;
    wire        mipi_tuser_w;
    wire        mipi_tready_w;

    // A3. AXI4-Lite 配置（BD M_AXIL_CFG Master -> 本模块从机）
    // 对 ISP 侧为 AXI4-Lite 从机
    wire [31:0] s_axil_awaddr;
    wire        s_axil_awvalid;
    wire        s_axil_awready;
    wire [31:0] s_axil_wdata;
    wire [3:0]  s_axil_wstrb;
    wire        s_axil_wvalid;
    wire        s_axil_wready;
    wire [1:0]  s_axil_bresp;
    wire        s_axil_bvalid;
    wire        s_axil_bready;
    wire [31:0] s_axil_araddr;
    wire        s_axil_arvalid;
    wire        s_axil_arready;
    wire [31:0] s_axil_rdata;
    wire [1:0]  s_axil_rresp;
    wire        s_axil_rvalid;
    wire        s_axil_rready;

    // A4. AXI4 HP0：display_ctrl Master -> BD Slave（写帧缓存）
    wire [AXI_AW-1:0]   m_axi_hp0_awaddr;
    wire [7:0]           m_axi_hp0_awlen;
    wire [2:0]           m_axi_hp0_awsize;
    wire [1:0]           m_axi_hp0_awburst;
    wire                 m_axi_hp0_awvalid;
    wire                 m_axi_hp0_awready;
    wire [AXI_DW-1:0]   m_axi_hp0_wdata;
    wire [AXI_DW/8-1:0] m_axi_hp0_wstrb;
    wire                 m_axi_hp0_wlast;
    wire                 m_axi_hp0_wvalid;
    wire                 m_axi_hp0_wready;
    wire [1:0]           m_axi_hp0_bresp;
    wire                 m_axi_hp0_bvalid;
    wire                 m_axi_hp0_bready;

    // A5. AXI4 HP1：ddr3_pixel_buf Master -> BD Slave（DDR 乒乓）
    wire [AXI_AW-1:0]   m_axi_hp1_awaddr;
    wire [7:0]           m_axi_hp1_awlen;
    wire [2:0]           m_axi_hp1_awsize;
    wire [1:0]           m_axi_hp1_awburst;
    wire                 m_axi_hp1_awvalid;
    wire                 m_axi_hp1_awready;
    wire [AXI_DW-1:0]   m_axi_hp1_wdata;
    wire [AXI_DW/8-1:0] m_axi_hp1_wstrb;
    wire                 m_axi_hp1_wlast;
    wire                 m_axi_hp1_wvalid;
    wire                 m_axi_hp1_wready;
    wire [1:0]           m_axi_hp1_bresp;
    wire                 m_axi_hp1_bvalid;
    wire                 m_axi_hp1_bready;
    wire [AXI_AW-1:0]   m_axi_hp1_araddr;
    wire [7:0]           m_axi_hp1_arlen;
    wire [2:0]           m_axi_hp1_arsize;
    wire [1:0]           m_axi_hp1_arburst;
    wire                 m_axi_hp1_arvalid;
    wire                 m_axi_hp1_arready;
    wire [AXI_DW-1:0]   m_axi_hp1_rdata;
    wire [1:0]           m_axi_hp1_rresp;
    wire                 m_axi_hp1_rvalid;
    wire                 m_axi_hp1_rlast;
    wire                 m_axi_hp1_rready;
    // AXI DMA S2MM 信号
    wire [7:0]           eth_axis_tdata;
    wire                 eth_axis_tvalid;
    wire                 eth_axis_tready;   
    wire                 eth_axis_tlast;
    wire                 eth_axis_tkeep = 1'b1;
    wire [15:0]          eth_tx_frame_cnt;
    wire [31:0]          mipi_beat_cnt_w;
    wire [31:0]          mipi_pix_cnt_w;
    reg  [31:0]          raw_pixel_cnt_r;
    reg  [31:0]          clahe_pixel_cnt_r;
    reg  [31:0]          fifo_ovf_cnt_r;
    reg  [20:0]          bilat_frame_pix_r;

    // A6. I2C 三态（BD 内 IOBUF，本顶层再包一层）
    wire iic_scl_i_w, iic_scl_o_w, iic_scl_t_w;
    wire iic_sda_i_w, iic_sda_o_w, iic_sda_t_w;

    // A7. 中断 / 状态
    wire frame_done_irq_w;
    wire buf_sel_w;
    wire [31:0] dead_cnt_w;

    // =========================================================================
    // B. IOBUF：I2C 双向 IO
    //    T=1 高阻输入；T=0 输出 iic_*_o_w
    // =========================================================================
    IOBUF u_iic_scl_buf (
        .IO (iic_scl_io),
        .I  (iic_scl_o_w),
        .O  (iic_scl_i_w),
        .T  (iic_scl_t_w)
    );
    IOBUF u_iic_sda_buf (
        .IO (iic_sda_io),
        .I  (iic_sda_o_w),
        .O  (iic_sda_i_w),
        .T  (iic_sda_t_w)
    );

    // =========================================================================
    // C. Block Design 封装例化
    //    端口名与 create_bd_ov5640.tcl 中 BD 一致
    //    AXI 命名: <接口>_<信号>
    // =========================================================================
    zynq_imgproc_bd_wrapper u_bd (
        // MIPI 差分物理接口
        .mipi_phy_if_clk_p  (mipi_phy_if_clk_p),
        .mipi_phy_if_clk_n  (mipi_phy_if_clk_n),
        .mipi_phy_if_data_p (mipi_phy_if_data_p),
        .mipi_phy_if_data_n (mipi_phy_if_data_n),

        // 时钟与复位
        .pl_clk             (pl_clk),
        .rst_n              (rst_n),
        .pclk               (pclk),
        .pclk_resetn        (pclk_resetn),

        // MIPI AXI-Stream (VIDEO_OUT)
        .VIDEO_OUT_tdata    (mipi_tdata_w),
        .VIDEO_OUT_tvalid   (mipi_tvalid_w),
        .VIDEO_OUT_tready   (mipi_tready_w),
        .VIDEO_OUT_tlast    (mipi_tlast_w),
        .VIDEO_OUT_tuser    (mipi_tuser_w),

        // PL -> BD：AXI DMA S2MM（以太网帧字节流）
        .ETH_AXIS_S2MM_tdata  (eth_axis_tdata),
        .ETH_AXIS_S2MM_tvalid (eth_axis_tvalid),
        .ETH_AXIS_S2MM_tready (eth_axis_tready),
        .ETH_AXIS_S2MM_tlast  (eth_axis_tlast),
        .ETH_AXIS_S2MM_tkeep  (eth_axis_tkeep),

        // AXI-Lite 配置 Master
        .M_AXIL_CFG_awaddr  (s_axil_awaddr),
        .M_AXIL_CFG_awvalid (s_axil_awvalid),
        .M_AXIL_CFG_awready (s_axil_awready),
        .M_AXIL_CFG_wdata   (s_axil_wdata),
        .M_AXIL_CFG_wstrb   (s_axil_wstrb),
        .M_AXIL_CFG_wvalid  (s_axil_wvalid),
        .M_AXIL_CFG_wready  (s_axil_wready),
        .M_AXIL_CFG_bresp   (s_axil_bresp),
        .M_AXIL_CFG_bvalid  (s_axil_bvalid),
        .M_AXIL_CFG_bready  (s_axil_bready),
        .M_AXIL_CFG_araddr  (s_axil_araddr),
        .M_AXIL_CFG_arvalid (s_axil_arvalid),
        .M_AXIL_CFG_arready (s_axil_arready),
        .M_AXIL_CFG_rdata   (s_axil_rdata),
        .M_AXIL_CFG_rresp   (s_axil_rresp),
        .M_AXIL_CFG_rvalid  (s_axil_rvalid),
        .M_AXIL_CFG_rready  (s_axil_rready),

        // AXI4 HP0 Slave（写帧缓存）
        .S_AXI_HP0_awaddr   (m_axi_hp0_awaddr),
        .S_AXI_HP0_awlen    (m_axi_hp0_awlen),
        .S_AXI_HP0_awsize   (m_axi_hp0_awsize),
        .S_AXI_HP0_awburst  (m_axi_hp0_awburst),
        .S_AXI_HP0_awvalid  (m_axi_hp0_awvalid),
        .S_AXI_HP0_awready  (m_axi_hp0_awready),
        .S_AXI_HP0_wdata    (m_axi_hp0_wdata),
        .S_AXI_HP0_wstrb    (m_axi_hp0_wstrb),
        .S_AXI_HP0_wlast    (m_axi_hp0_wlast),
        .S_AXI_HP0_wvalid   (m_axi_hp0_wvalid),
        .S_AXI_HP0_wready   (m_axi_hp0_wready),
        .S_AXI_HP0_bresp    (m_axi_hp0_bresp),
        .S_AXI_HP0_bvalid   (m_axi_hp0_bvalid),
        .S_AXI_HP0_bready   (m_axi_hp0_bready),

        // AXI4 HP1 Slave（DDR 乒乓）
        .S_AXI_HP1_awaddr   (m_axi_hp1_awaddr),
        .S_AXI_HP1_awlen    (m_axi_hp1_awlen),
        .S_AXI_HP1_awsize   (m_axi_hp1_awsize),
        .S_AXI_HP1_awburst  (m_axi_hp1_awburst),
        .S_AXI_HP1_awvalid  (m_axi_hp1_awvalid),
        .S_AXI_HP1_awready  (m_axi_hp1_awready),
        .S_AXI_HP1_wdata    (m_axi_hp1_wdata),
        .S_AXI_HP1_wstrb    (m_axi_hp1_wstrb),
        .S_AXI_HP1_wlast    (m_axi_hp1_wlast),
        .S_AXI_HP1_wvalid   (m_axi_hp1_wvalid),
        .S_AXI_HP1_wready   (m_axi_hp1_wready),
        .S_AXI_HP1_bresp    (m_axi_hp1_bresp),
        .S_AXI_HP1_bvalid   (m_axi_hp1_bvalid),
        .S_AXI_HP1_bready   (m_axi_hp1_bready),
        .S_AXI_HP1_araddr   (m_axi_hp1_araddr),
        .S_AXI_HP1_arlen    (m_axi_hp1_arlen),
        .S_AXI_HP1_arsize   (m_axi_hp1_arsize),
        .S_AXI_HP1_arburst  (m_axi_hp1_arburst),
        .S_AXI_HP1_arvalid  (m_axi_hp1_arvalid),
        .S_AXI_HP1_arready  (m_axi_hp1_arready),
        .S_AXI_HP1_rdata    (m_axi_hp1_rdata),
        .S_AXI_HP1_rresp    (m_axi_hp1_rresp),
        .S_AXI_HP1_rvalid   (m_axi_hp1_rvalid),
        .S_AXI_HP1_rlast    (m_axi_hp1_rlast),
        .S_AXI_HP1_rready   (m_axi_hp1_rready),

        // 帧完成中断
        .frame_done_irq     (frame_done_irq_w),

        // OV5640 GPIO
        .ov5640_reset_n     (),//(ov5640_reset_n),
        .ov5640_pwdn        (ov5640_pwdn),
        .ov5640_mclk        (ov5640_mclk),

        // I2C 三态
        .iic_scl_i          (iic_scl_i_w),
        .iic_scl_o          (iic_scl_o_w),
        .iic_scl_t          (iic_scl_t_w),
        .iic_sda_i          (iic_sda_i_w),
        .iic_sda_o          (iic_sda_o_w),
        .iic_sda_t          (iic_sda_t_w)
    );

    // =========================================================================
    // D. AXI4-Lite 配置寄存器 (axil_cfg_reg)
    // =========================================================================
    localparam NUM_WR_REGS = 10;
    localparam NUM_RD_REGS = 7;
    localparam integer ETH_FRAME_PIX = IMG_W * IMG_H;

    wire [NUM_WR_REGS*32-1:0] cfg_wreg;
    wire [NUM_WR_REGS-1:0]    cfg_wreg_wr;
    wire [NUM_RD_REGS*32-1:0] cfg_status;

    axil_cfg_reg #(
        .NUM_WR_REGS (NUM_WR_REGS),
        .NUM_RD_REGS (NUM_RD_REGS),
        .ADDR_BITS   (12),
        .STATUS_BASE (12'h200)
    ) u_axil_cfg (
        .aclk             (pl_clk),
        .aresetn          (rst_n),
        .s_axil_awaddr    (s_axil_awaddr[11:0]),
        .s_axil_awvalid   (s_axil_awvalid),
        .s_axil_awready   (s_axil_awready),
        .s_axil_wdata     (s_axil_wdata),
        .s_axil_wstrb     (s_axil_wstrb),
        .s_axil_wvalid    (s_axil_wvalid),
        .s_axil_wready    (s_axil_wready),
        .s_axil_bresp     (s_axil_bresp),
        .s_axil_bvalid    (s_axil_bvalid),
        .s_axil_bready    (s_axil_bready),
        .s_axil_araddr    (s_axil_araddr[11:0]),
        .s_axil_arvalid   (s_axil_arvalid),
        .s_axil_arready   (s_axil_arready),
        .s_axil_rdata     (s_axil_rdata),
        .s_axil_rresp     (s_axil_rresp),
        .s_axil_rvalid    (s_axil_rvalid),
        .s_axil_rready    (s_axil_rready),
        .wreg_o           (cfg_wreg),
        .wreg_wr_o        (cfg_wreg_wr),
        .status_i         (cfg_status)
    );

    // 寄存器域解析
    wire [31:0] r_fb_addr_a   = cfg_wreg[0*32 +: 32];
    wire [31:0] r_fb_addr_b   = cfg_wreg[1*32 +: 32];
    wire [31:0] r_ctrl        = cfg_wreg[2*32 +: 32];
    wire [12:0] r_black_level = cfg_wreg[3*32 +: 13];
    wire [11:0] r_wb_gain_r   = cfg_wreg[4*32 +: 12];
    wire [11:0] r_wb_gain_g   = cfg_wreg[5*32 +: 12];
    wire [11:0] r_wb_gain_b   = cfg_wreg[6*32 +: 12];
    wire [31:0] r_gamma_wr    = cfg_wreg[7*32 +: 32];
    wire [31:0] r_ddr3_base   = cfg_wreg[8*32 +: 32];
    wire [31:0] r_sy_lut      = cfg_wreg[9*32 +: 32];

    wire        cfg_start     = r_ctrl[0];
    wire [1:0]  res_sel       = r_ctrl[2:1];
    /* r_ctrl[8]=legacy ETH test_pat bypass; [9]=ISP test RAW; [10]=ETH from CLAHE */
    wire        test_pat_en    = r_ctrl[8];
    wire        isp_src_test   = ((r_ctrl & 32'h00000600) == 32'h0) ?
                                  ISP_USE_TEST_RAW : r_ctrl[9];
    wire        eth_from_clahe = ((r_ctrl & 32'h00000600) == 32'h0) ?
                                  ETH_USE_CLAHE : r_ctrl[10];
    wire        gamma_lut_we  = cfg_wreg_wr[7];
    wire [7:0]  gamma_lut_wa  = r_gamma_wr[20:13];
    wire [12:0] gamma_lut_wd  = r_gamma_wr[12:0];
    wire        sy_lut_we     = cfg_wreg_wr[9];
    wire [9:0]  sy_lut_wa     = r_sy_lut[22:13];
    wire [12:0] sy_lut_wd     = r_sy_lut[12:0];

    // =========================================================================
    // E. 传感器：MIPI AXI-Stream -> Q0.13 像素流
    //    MIPI_MODE=1: 从 mipi_tdata[19:0] 解包 2 lane RAW10
    //    Q0.13: P = {RAW10[9:0], 3'b0}（左移 3 位 max=8184)
    // =========================================================================
    wire [PIXEL_W-1:0] si_raw_data;
    wire               si_raw_valid;
    wire               si_raw_hsync;
    wire               si_raw_vsync;

    wire [PIXEL_W-1:0] mipi_raw_data;
    wire               mipi_raw_valid;
    wire               mipi_raw_hsync;
    wire               mipi_raw_vsync;

    wire [PIXEL_W-1:0] pat_raw_data;
    wire               pat_raw_valid;
    wire               pat_raw_hsync;
    wire               pat_raw_vsync;
    wire               pat_raw_ready;
    wire               clahe_fifo_almost_full;

    sensor_if #(
        .RAW_W     (RAW_W),
        .PIXEL_W   (PIXEL_W),
        .IMG_W     (IMG_W),
        .IMG_H     (IMG_H),
        .BAYER_FMT (0),        // RGGB (OV5640 默认)
        .VSYNC_POL (0),
        .HREF_POL  (0),
        .MIPI_MODE (1)         // MIPI CSI-2 模式
    ) u_sensor_if (
        .pclk        (pl_clk),  // MIPI：pl_clk 解包时钟
        .rst_n       (rst_n),
        // DVP 未用接 0
        .dvp_data    ({RAW_W{1'b0}}),
        .dvp_href    (1'b0),
        .dvp_vsync   (1'b0),
        .dvp_pclk_en (1'b0),
        // MIPI AXI4-Stream 输入
        .mipi_tdata  (mipi_tdata_w),
        .mipi_tvalid (mipi_tvalid_w),
        .mipi_tready (mipi_tready_w),
        .mipi_tlast  (mipi_tlast_w),
        .mipi_tuser  (mipi_tuser_w),
        // 像素流输出 (Q0.13, pl_clk 域)
        .m_raw_data  (mipi_raw_data),
        .m_raw_valid (mipi_raw_valid),
        .m_raw_hsync (mipi_raw_hsync),
        .m_raw_vsync (mipi_raw_vsync),
        .bayer_phase  (),
        .frame_width  (),
        .frame_height (),
        .frame_cnt    (),
        .locked       (),
        .mipi_beat_cnt (mipi_beat_cnt_w),
        .mipi_pix_cnt  (mipi_pix_cnt_w)
    );

    assign pat_raw_ready = ~clahe_fifo_almost_full;

    isp_raw_pat_gen #(
        .RAW_W   (RAW_W),
        .PIXEL_W (PIXEL_W),
        .IMG_W   (IMG_W),
        .IMG_H   (IMG_H)
    ) u_isp_pat (
        .clk          (pl_clk),
        .rst_n        (rst_n),
        .enable       (isp_src_test),
        .s_ready      (pat_raw_ready),
        .m_raw_data   (pat_raw_data),
        .m_raw_valid  (pat_raw_valid),
        .m_raw_hsync  (pat_raw_hsync),
        .m_raw_vsync  (pat_raw_vsync)
    );

    assign si_raw_data  = isp_src_test ? pat_raw_data  : mipi_raw_data;
    assign si_raw_valid = isp_src_test ? pat_raw_valid : mipi_raw_valid;
    assign si_raw_hsync = isp_src_test ? pat_raw_hsync : mipi_raw_hsync;
    assign si_raw_vsync = isp_src_test ? pat_raw_vsync : mipi_raw_vsync;

    // =========================================================================
    // F. ISP 预处理（流水线）
    // =========================================================================
    wire [PIXEL_W-1:0] preproc_Y;
    wire [15:0]         preproc_CbCr;
    wire               preproc_valid, preproc_hsync, preproc_vsync;
    wire               preproc_sof;
    wire [31:0]         dead_cnt_w_int;

    assign preproc_sof = preproc_valid & preproc_vsync;

    img_preprocessor #(
        .PIXEL_W  (PIXEL_W),
        .LINE_LEN (LINE_LEN)
    ) u_preproc (
        .clk            (pl_clk),
        .rst_n          (rst_n),
        .s_raw_data     (si_raw_data),
        .s_raw_valid    (si_raw_valid),
        .s_raw_hsync    (si_raw_hsync),
        .s_raw_vsync    (si_raw_vsync),
        .s_raw_ready    (),
        .m_Y_data       (preproc_Y),
        .m_CbCr_data    (preproc_CbCr),
        .m_pix_valid    (preproc_valid),
        .m_pix_hsync    (preproc_hsync),
        .m_pix_vsync    (preproc_vsync),
        .lut_wr_data    (gamma_lut_wd),
        .lut_wr_addr    (gamma_lut_wa),
        .lut_wr_en      (gamma_lut_we),
        .wb_gain_r      (r_wb_gain_r),
        .wb_gain_g      (r_wb_gain_g),
        .wb_gain_b      (r_wb_gain_b),
        .black_level    (r_black_level),
        .bayer_fmt      (2'b00),
        .dead_pixel_cnt (dead_cnt_w_int)
    );

    // =========================================================================
    // G. 11 行行缓冲
    // =========================================================================
    localparam NUM_LINES = 11;
    wire [PIXEL_W*NUM_LINES-1:0] col_pixels;
    wire                          col_valid;
    wire [10:0]                   col_x, col_y;
    wire                          col_sof;

    line_buffer_ctrl #(
        .PIXEL_W   (PIXEL_W),
        .LINE_LEN  (LINE_LEN),
        .NUM_LINES (NUM_LINES),
        .IMG_H     (IMG_H)
    ) u_linebuf (
        .clk            (pl_clk),
        .rst_n          (rst_n),
        .s_pixel_tdata  (preproc_Y),
        .s_pixel_tvalid (preproc_valid),
        .s_pixel_tlast  (preproc_hsync),
        .s_pixel_sof    (preproc_sof),
        .s_pixel_tready (),
        .col_pixels     (col_pixels),
        .col_valid      (col_valid),
        .col_x          (col_x),
        .col_y          (col_y),
        .col_sof        (col_sof),
        .buf_full       (),
        .fill_lines     (),
        .wr_ptr_x       ()
    );

    wire [PIXEL_W-1:0] centre_pix = col_pixels[5*PIXEL_W +: PIXEL_W];

    // =========================================================================
    // H. 11x11 局部细节增强
    // =========================================================================
    wire [PIXEL_W-1:0] enh_Y;
    wire               enh_valid;
    wire               enh_sof;
    wire [10:0]        enh_x, enh_y;

    local_detail_enhance_11x11 #(
        .PIXEL_W  (PIXEL_W),
        .WIN_SIZE (11),
        .LINE_LEN (LINE_LEN)
    ) u_detail_enh (
        .clk         (pl_clk),
        .rst_n       (rst_n),
        .col_pixels  (col_pixels),
        .col_valid   (col_valid),
        .col_x       (col_x),
        .col_y       (col_y),
        .col_sof     (col_sof),
        .centre_pix  (centre_pix),
        .lut_wr_data (sy_lut_wd),
        .lut_wr_addr (sy_lut_wa),
        .lut_wr_en   (sy_lut_we),
        .m_enh_data  (enh_Y),
        .m_enh_valid (enh_valid),
        .m_enh_x     (enh_x),
        .m_enh_y     (enh_y),
        .m_enh_sof   (enh_sof)
    );

    // =========================================================================
    // I. 双边滤波 5x5
    // =========================================================================
    wire [PIXEL_W-1:0] bilat_Y;
    wire               bilat_valid;
    wire               bilat_sof;

    bilateral_filter #(
        .PIXEL_W    (PIXEL_W),
        .LINE_LEN   (LINE_LEN),
        .WIN_HALF   (2),
        .NORM_SHIFT (8)
    ) u_bilateral (
        .clk         (pl_clk),
        .rst_n       (rst_n),
        .s_pix_data  (enh_Y),
        .s_pix_valid (enh_valid),
        .lut_wr_addr (8'b0),
        .lut_wr_data (8'b0),
        .lut_wr_en   (1'b0),
        .m_pix_data  (bilat_Y),
        .m_pix_valid (bilat_valid)
    );

    // =========================================================================
    // J. CLAHE (with ingress FIFO + backpressure)
    // =========================================================================
    localparam CLAHE_FIFO_DEPTH = 2048;
    localparam CLAHE_FIFO_AW    = $clog2(CLAHE_FIFO_DEPTH);

    wire [PIXEL_W-1:0] clahe_Y;
    wire               clahe_valid;
    wire               clahe_sof;
    wire               clahe_s_pix_ready;
    wire [PIXEL_W:0]   clahe_fifo_wdata;
    wire [PIXEL_W:0]   clahe_fifo_rdata;
    wire               clahe_fifo_wr;
    wire               clahe_fifo_rd;
    wire               clahe_fifo_full;
    wire               clahe_fifo_empty;
    wire [PIXEL_W-1:0] clahe_s_pix_data;
    wire               clahe_s_pix_valid;

    assign bilat_sof = bilat_valid && (bilat_frame_pix_r == 21'd0);

    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n)
            bilat_frame_pix_r <= 21'd0;
        else if (bilat_valid) begin
            if (bilat_frame_pix_r == ETH_FRAME_PIX[20:0] - 1)
                bilat_frame_pix_r <= 21'd0;
            else
                bilat_frame_pix_r <= bilat_frame_pix_r + 21'd1;
        end
    end

    assign clahe_fifo_wdata = {bilat_sof, bilat_Y};
    assign clahe_fifo_wr   = bilat_valid && !clahe_fifo_full;

    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n)
            fifo_ovf_cnt_r <= 32'd0;
        else if (bilat_valid && clahe_fifo_full)
            fifo_ovf_cnt_r <= fifo_ovf_cnt_r + 32'd1;
    end

    fifo_sync #(
        .DATA_W (PIXEL_W + 1),
        .DEPTH  (CLAHE_FIFO_DEPTH),
        .ADDR_W (CLAHE_FIFO_AW),
        .DO_REG (1),
        .FWFT   (0)
    ) u_clahe_fifo (
        .clk          (pl_clk),
        .rst_n        (rst_n),
        .wr_en        (clahe_fifo_wr),
        .wr_data      (clahe_fifo_wdata),
        .full         (clahe_fifo_full),
        .almost_full  (clahe_fifo_almost_full),
        .rd_en        (clahe_fifo_rd),
        .rd_data      (clahe_fifo_rdata),
        .rd_data_vld  (),
        .empty        (clahe_fifo_empty),
        .almost_empty (),
        .data_count   ()
    );

    assign clahe_fifo_rd    = clahe_s_pix_ready && !clahe_fifo_empty;
    assign clahe_s_pix_valid = clahe_fifo_rd;
    assign clahe_s_pix_data  = clahe_fifo_rdata[PIXEL_W-1:0];

    clahe_engine #(
        .PIXEL_W    (PIXEL_W),
        .IMG_W      (IMG_W),
        .IMG_H      (IMG_H),
        .TILE_W     (32),
        .TILE_H     (32),
        .HIST_BITS  (8),
        .CLIP_LIMIT (40)
    ) u_clahe (
        .clk          (pl_clk),
        .rst_n        (rst_n),
        .s_pix_data   (clahe_s_pix_data),
        .s_pix_valid  (clahe_s_pix_valid),
        .s_pix_ready  (clahe_s_pix_ready),
        .m_pix_data   (clahe_Y),
        .m_pix_valid  (clahe_valid),
        .m_pix_sof    (clahe_sof)
    );

    // K. DDR 乒乓 + AXI4 HP1
    // =========================================================================
    wire [PIXEL_W-1:0] disp_pix;
    wire               disp_pix_valid;

    ddr3_pixel_buf #(
        .PIXEL_W   (PIXEL_W),
        .AXI_DW    (AXI_DW),
        .AXI_AW    (AXI_AW),
        .BURST_LEN (16),
        .IMG_W     (IMG_W),
        .IMG_H     (IMG_H)
    ) u_ddr3_buf (
        .clk           (pl_clk),
        .rst_n         (rst_n),
        .s_pix_data    (clahe_Y),
        .s_pix_valid   (clahe_valid),
        .buf_base_addr (r_ddr3_base),
        .m_pix_data    (disp_pix),
        .m_pix_valid   (disp_pix_valid),
        // AXI4 HP1 写通道
        .m_axi_awaddr  (m_axi_hp1_awaddr),
        .m_axi_awlen   (m_axi_hp1_awlen),
        .m_axi_awsize  (m_axi_hp1_awsize),
        .m_axi_awburst (m_axi_hp1_awburst),
        .m_axi_awvalid (m_axi_hp1_awvalid),
        .m_axi_awready (m_axi_hp1_awready),
        .m_axi_wdata   (m_axi_hp1_wdata),
        .m_axi_wstrb   (m_axi_hp1_wstrb),
        .m_axi_wlast   (m_axi_hp1_wlast),
        .m_axi_wvalid  (m_axi_hp1_wvalid),
        .m_axi_wready  (m_axi_hp1_wready),
        .m_axi_bresp   (m_axi_hp1_bresp),
        .m_axi_bvalid  (m_axi_hp1_bvalid),
        .m_axi_bready  (m_axi_hp1_bready),
        // AXI4 HP1 读通道
        .m_axi_araddr  (m_axi_hp1_araddr),
        .m_axi_arlen   (m_axi_hp1_arlen),
        .m_axi_arsize  (m_axi_hp1_arsize),
        .m_axi_arburst (m_axi_hp1_arburst),
        .m_axi_arvalid (m_axi_hp1_arvalid),
        .m_axi_arready (m_axi_hp1_arready),
        .m_axi_rdata   (m_axi_hp1_rdata),
        .m_axi_rresp   (m_axi_hp1_rresp),
        .m_axi_rvalid  (m_axi_hp1_rvalid),
        .m_axi_rlast   (m_axi_hp1_rlast),
        .m_axi_rready  (m_axi_hp1_rready),
        .wr_page       (),
        .wr_frame_cnt  (),
        .wr_fifo_full  (),
        .rd_fifo_empty ()
    );

    // =========================================================================
    // K2. 以太网帧发送：CLAHE 输出 -> AXI DMA
    // =========================================================================

    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n) begin
            raw_pixel_cnt_r   <= 32'd0;
            clahe_pixel_cnt_r <= 32'd0;
        end else begin
            if (si_raw_valid)
                raw_pixel_cnt_r <= raw_pixel_cnt_r + 32'd1;
            if (clahe_valid)
                clahe_pixel_cnt_r <= clahe_pixel_cnt_r + 32'd1;
        end
    end

    wire [PIXEL_W-1:0] eth_src_data  = eth_from_clahe ? clahe_Y : bilat_Y;
    wire               eth_src_valid = eth_from_clahe ? clahe_valid : bilat_valid;
    wire               eth_src_sof   = eth_from_clahe ? clahe_sof : bilat_sof;

    wire [PIXEL_W-1:0] eth_pix_data  = eth_src_data;
    wire               eth_pix_valid = eth_src_valid;
    wire               eth_pix_sof   = eth_src_sof;

    (* mark_debug = "true" *) wire dbg_eth_valid = eth_pix_valid;
    (* mark_debug = "true" *) wire dbg_axis_tvalid = eth_axis_tvalid;
    (* mark_debug = "true" *) wire dbg_axis_tready = eth_axis_tready;
    (* mark_debug = "true" *) wire dbg_axis_tlast  = eth_axis_tlast;

    frame_eth_tx #(
        .PIXEL_W  (PIXEL_W),
        .IMG_W    (IMG_W),
        .IMG_H    (IMG_H),
        .AXIS_DW  (8)
    ) u_frame_eth (
        .clk            (pl_clk),
        .rst_n          (rst_n),
        .s_pix_data     (eth_pix_data),
        .s_pix_valid    (eth_pix_valid),
        .s_pix_sof      (eth_pix_sof),
        // AXI-Stream → BD 内 AXI DMA
        .m_axis_tdata   (eth_axis_tdata),
        .m_axis_tvalid  (eth_axis_tvalid),
        .m_axis_tready  (eth_axis_tready),
        .m_axis_tlast   (eth_axis_tlast),
        // 抽帧：r_ctrl[7:4] 控制发送帧率（默认每2帧发1帧）
        .frame_skip     (r_ctrl[7:4]),
        .tx_frame_cnt   (eth_tx_frame_cnt)
    );


    // =========================================================================
    // L. 显示控制：AXI4 HP0 写 DDR + VGA 时序
    // =========================================================================
    zynq_display_ctrl #(
        .PIXEL_W   (PIXEL_W),
        .AXI_DW    (AXI_DW),
        .AXI_AW    (AXI_AW),
        .BURST_LEN (16),
        .FB_H      (IMG_W),
        .FB_V      (IMG_H),
        .FB_PIX_W  (32)
    ) u_display (
        .clk            (pl_clk),
        .pclk           (pclk),     // 148.5 MHz MMCM 像素时钟
        .pclk_rst_n     (pclk_resetn),
        .rst_n          (rst_n),
        .s_pix_data     (disp_pix),
        .s_pix_valid    (disp_pix_valid),
        .fb_addr_a      (r_fb_addr_a),
        .fb_addr_b      (r_fb_addr_b),
        .cfg_start      (cfg_start),
        .res_sel        (res_sel),
        // AXI4 HP0 写通道
        .m_axi_awaddr   (m_axi_hp0_awaddr),
        .m_axi_awlen    (m_axi_hp0_awlen),
        .m_axi_awsize   (m_axi_hp0_awsize),
        .m_axi_awburst  (m_axi_hp0_awburst),
        .m_axi_awvalid  (m_axi_hp0_awvalid),
        .m_axi_awready  (m_axi_hp0_awready),
        .m_axi_wdata    (m_axi_hp0_wdata),
        .m_axi_wstrb    (m_axi_hp0_wstrb),
        .m_axi_wlast    (m_axi_hp0_wlast),
        .m_axi_wvalid   (m_axi_hp0_wvalid),
        .m_axi_wready   (m_axi_hp0_wready),
        .m_axi_bresp    (m_axi_hp0_bresp),
        .m_axi_bvalid   (m_axi_hp0_bvalid),
        .m_axi_bready   (m_axi_hp0_bready),
        // VGA 中间信号（再经 pclk 寄存送 HDMI）
        .vga_hsync      (vga_hsync_i),
        .vga_vsync      (vga_vsync_i),
        .vga_de         (vga_de_i),
        .vga_pixel      (vga_pixel_i),
        .vga_active     (vga_active_i),
        .frame_done_irq (frame_done_irq_w),
        .buf_sel        (buf_sel_w)
    );

    // =========================================================================
    wire [31:0] raw_pixel_cnt_w = raw_pixel_cnt_r;

    // =========================================================================
    // M. 状态回读寄存器
    // =========================================================================
    assign cfg_status = {
        fifo_ovf_cnt_r,
        clahe_pixel_cnt_r,
        raw_pixel_cnt_w,
        mipi_pix_cnt_w,
        mipi_beat_cnt_w,
        {16'd0, eth_tx_frame_cnt, buf_sel_w},
        dead_cnt_w_int
    };

    // =========================================================================
    // N. HDMI：灰度 Y[12:5] -> RGB24 -> ADV7511
    //    ADV7511：24-bit 并行 RGB + 同步
    //    灰度图: R=G=B=luma8=vga_pixel_i[12:5]
    //    pclk 直连 hdmi_clk；ADV7511 边沿采样
    // =========================================================================
    // pclk 域输出寄存：满足 IOB/源同步时序
    // 可接受 1 拍延迟：同步信号与数据同拍寄存
    wire [7:0] hdmi_luma_w = vga_pixel_i[PIXEL_W-1 -: 8];

    reg [23:0] hdmi_d_r;
    reg        hdmi_hsync_r, hdmi_vsync_r, hdmi_de_r;

    always @(posedge pclk or negedge pclk_resetn) begin
        if (!pclk_resetn) begin
            hdmi_d_r     <= 24'b0;
            hdmi_hsync_r <= 1'b0;
            hdmi_vsync_r <= 1'b0;
            hdmi_de_r    <= 1'b0;
        end else begin
            hdmi_d_r     <= {hdmi_luma_w, hdmi_luma_w, hdmi_luma_w};
            hdmi_hsync_r <= vga_hsync_i;
            hdmi_vsync_r <= vga_vsync_i;
            hdmi_de_r    <= vga_de_i;
        end
    end

    assign hdmi_clk   = pclk;
    assign hdmi_d     = hdmi_d_r;
    assign hdmi_hsync = hdmi_hsync_r;
    assign hdmi_vsync = hdmi_vsync_r;
    assign hdmi_de    = hdmi_de_r;

    // =========================================================================
    // 观测：frame_done_irq 由 u_display -> BD -> PS GIC
    // =========================================================================
    //assign buf_sel_out         = buf_sel_w;
    //assign dead_pixel_cnt_out  = dead_cnt_w_int;
    assign dead_cnt_w = dead_cnt_w_int;

endmodule