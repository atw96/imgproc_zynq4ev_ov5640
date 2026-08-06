// imgproc_top_ov5640.v -- Vivado ????
// ??: ALINX AXU4EVB (xczu4ev-sfvc784-2-i)????: AV5641 (OV5640 MIPI CSI-2)
//
// ????:
//   imgproc_top_ov5640 (????
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
//     +-- u_frame_eth  (project/src/frame_eth_tx.v ??BD AXI DMA S2MM)
//
// BD ??????create_bd_ov5640.tcl ???????
//   BD -> ??RTL:
//     pl_clk, rst_n          ???? ~150 MHz / ?? (pl_clk ??
//     pclk, pclk_resetn      HDMI ???? 148.5 MHz / ?? (MMCM)
//     VIDEO_OUT_tdata[19:0], VIDEO_OUT_tvalid, VIDEO_OUT_tlast,
//     VIDEO_OUT_tuser, VIDEO_OUT_tready
//     M_AXIL_CFG_* (AXI-Lite Master -> ISP ????)
//   ??RTL -> BD:
//     S_AXI_HP0_* (AXI4 ?? 64-bit -> display_ctrl)
//     S_AXI_HP1_* (AXI4 ?? 64-bit -> ddr3_pixel_buf)
//     frame_done_irq
//     ETH_AXIS_S2MM_* ??PL frame_eth_tx ??BD AXI DMA S2MM???PS DDR??
//   ????:
//     mipi_phy_if_*, iic_scl_*, iic_sda_*
//     ov5640_reset_n, ov5640_pwdn, ov5640_mclk
//     hdmi_d[23:0], hdmi_clk, hdmi_hsync, hdmi_vsync, hdmi_de
// =============================================================================

`timescale 1ns/1ps

module imgproc_top_ov5640 #(
    parameter RAW_W    = 10,   // OV5640 RAW10
    parameter PIXEL_W  = 13,   // ?? Q0.13 ????
    parameter AXI_DW   = 64,
    parameter AXI_AW   = 32,
    parameter LINE_LEN = 1920, // OV5640 1080p
    parameter IMG_W    = 1920,
    parameter IMG_H    = 1080,
    /* Compile-time ISP/ETH mux (Vivado generic override for MIPI bit) */
    /* N20: default 0 so dbg_src=1 is real MIPI; pattern via r_dbg=2 / bit2 */
    parameter ISP_USE_TEST_RAW = 1'b0,
    parameter ETH_USE_CLAHE    = 1'b1,
    /* n7r: 1 = eth emits sof-locked ramp (bypass ISP pixels) for N8 path check */
    parameter ETH_FORCE_RAMP   = 1'b0,
    /* PLAN_v3 N9b: ETH from ddr3_pixel_buf readout (gray RGBX); write side=bilat_Y */
    parameter ETH_FROM_DDR3    = 1'b0,
    /* N11e: ddr3 readout = local ramp (skip HP1) for ETH bring-up */
    parameter DDR3_FORCE_RAMP  = 1'b0
)(
    // -------------------------------------------------------------------------
    // ?????PACKAGE_PIN / IOSTANDARD ??XDC??
    // -------------------------------------------------------------------------

    // MIPI CSI-2 ?????? BD mipi_phy_if??
    input  wire        mipi_phy_if_clk_p,
    input  wire        mipi_phy_if_clk_n,
    input  wire [1:0]  mipi_phy_if_data_p,
    input  wire [1:0]  mipi_phy_if_data_n,

    // I2C ?????IOBUF ??????
    inout  wire        iic_scl_io,
    inout  wire        iic_sda_io,

    // OV5640 ?? GPIO
    //output wire        ov5640_reset_n,
    output wire        ov5640_pwdn,
    output wire        ov5640_mclk,    // 24 MHz from PS FCLK_CLK1

    // -------------------------------------------------------------------------
    // HDMI ?? -> ADV7511 ?? 24-bit RGB (Bank 66, LVCMOS33)
    //   pclk = 148.5 MHz (MMCM)??920x1080@60Hz ????
    //   ????: R=G=B = Y[12:5]
    // -------------------------------------------------------------------------
    output wire                  hdmi_clk,
    output wire                  hdmi_hsync,
    output wire                  hdmi_vsync,
    output wire                  hdmi_de,
    output wire [23:0]           hdmi_d

    // -------------------------------------------------------------------------
    // ????????????
    // -------------------------------------------------------------------------
    //output wire [31:0]           dead_pixel_cnt_out,
    //output wire                  buf_sel_out
);

    // =========================================================================
    // A. ????????BD / RTL ??
    // =========================================================================

    // A1. ???????? BD??
    wire        pl_clk;       // ~150 MHz (PS FCLK_CLK0?? AXI / ISP ??)
    wire        rst_n;        // ??????(pl_clk ??peripheral_aresetn)
    wire        pclk;         // 148.5 MHz HDMI ???? (MMCM clk_wiz ??)
    wire        pclk_resetn;  // ??????(pclk ??MMCM locked ????

    // A8. ??????VGA ???? (display_ctrl -> ?????HDMI)
    wire                  vga_hsync_i;
    wire                  vga_vsync_i;
    wire                  vga_de_i;
    wire [PIXEL_W-1:0]    vga_pixel_i;
    wire                  vga_active_i;

    // A2. MIPI AXI-Stream????BD VIDEO_OUT??
    // Vivado ??Master AXIS ??????:
    //   VIDEO_OUT_tdata, VIDEO_OUT_tvalid, VIDEO_OUT_tready,
    //   VIDEO_OUT_tlast, VIDEO_OUT_tuser
    wire [19:0] mipi_tdata_w;
    wire        mipi_tvalid_w;
    wire        mipi_tlast_w;
    wire        mipi_tuser_w;
    wire        mipi_tready_w;

    // A3. AXI4-Lite ???BD M_AXIL_CFG Master -> ??????
    // ??ISP ?? AXI4-Lite ??
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

    // A4. AXI4 HP0?display_ctrl Master -> BD Slave??????
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

    // A5. AXI4 HP1?ddr3_pixel_buf Master -> BD Slave?DDR ????
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
    // AXI DMA S2MM (32-bit RGBX)
    wire [31:0]          eth_axis_tdata;
    wire                 eth_axis_tvalid;
    wire                 eth_axis_tready;
    wire                 eth_axis_tlast;
    wire [3:0]           eth_axis_tkeep;
    wire [15:0]          eth_tx_frame_cnt;
    wire [15:0]          eth_skid_ovf_cnt;
    wire                 eth_pause_src;
    wire [31:0]          mipi_beat_cnt_w;
    wire [31:0]          mipi_pix_cnt_w;
    reg  [31:0]          raw_pixel_cnt_r;
    reg  [31:0]          clahe_pixel_cnt_r;
    reg  [31:0]          fifo_ovf_cnt_r; /* Bit A/N7: reused as sof_diag pack */
    /* N7: sticky SOF pulse counts (sat 255) @0x218 = {bilat,enh,col,pre} */
    reg  [7:0]           sof_cnt_pre_r, sof_cnt_col_r, sof_cnt_enh_r, sof_cnt_bilat_r;
    reg                  sof_pre_d, sof_col_d, sof_enh_d, sof_bilat_d;

    // A6. I2C ???BD ??IOBUF?????????
    wire iic_scl_i_w, iic_scl_o_w, iic_scl_t_w;
    wire iic_sda_i_w, iic_sda_o_w, iic_sda_t_w;

    // A7. ?? / ???
    wire frame_done_irq_w;
    wire buf_sel_w;
    wire [31:0] dead_cnt_w;

    // =========================================================================
    // B. IOBUF?I2C ?? IO
    //    T=1 ?????T=0 ?? iic_*_o_w
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
    // C. Block Design ????
    //    ???? create_bd_ov5640.tcl ??BD ???
    //    AXI ??: <??>_<??>
    // =========================================================================
    zynq_imgproc_bd_wrapper u_bd (
        // MIPI ??????
        .mipi_phy_if_clk_p  (mipi_phy_if_clk_p),
        .mipi_phy_if_clk_n  (mipi_phy_if_clk_n),
        .mipi_phy_if_data_p (mipi_phy_if_data_p),
        .mipi_phy_if_data_n (mipi_phy_if_data_n),

        // ??????
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

        // PL -> BD?AXI DMA S2MM??????????
        .ETH_AXIS_S2MM_tdata  (eth_axis_tdata),
        .ETH_AXIS_S2MM_tvalid (eth_axis_tvalid),
        .ETH_AXIS_S2MM_tready (eth_axis_tready),
        .ETH_AXIS_S2MM_tlast  (eth_axis_tlast),
        .ETH_AXIS_S2MM_tkeep  (eth_axis_tkeep),

        // AXI-Lite ?? Master
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

        // AXI4 HP0 Slave??????
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

        // AXI4 HP1 -> DDR (N11d: drive cache/prot/lock/qos; were left open)
        .S_AXI_HP1_awaddr   (m_axi_hp1_awaddr),
        .S_AXI_HP1_awlen    (m_axi_hp1_awlen),
        .S_AXI_HP1_awsize   (m_axi_hp1_awsize),
        .S_AXI_HP1_awburst  (m_axi_hp1_awburst),
        .S_AXI_HP1_awcache  (4'b0011),
        .S_AXI_HP1_awprot   (3'b000),
        .S_AXI_HP1_awlock   (1'b0),
        .S_AXI_HP1_awqos    (4'b0000),
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
        .S_AXI_HP1_arcache  (4'b0011),
        .S_AXI_HP1_arprot   (3'b000),
        .S_AXI_HP1_arlock   (1'b0),
        .S_AXI_HP1_arqos    (4'b0000),
        .S_AXI_HP1_arvalid  (m_axi_hp1_arvalid),
        .S_AXI_HP1_arready  (m_axi_hp1_arready),
        .S_AXI_HP1_rdata    (m_axi_hp1_rdata),
        .S_AXI_HP1_rresp    (m_axi_hp1_rresp),
        .S_AXI_HP1_rvalid   (m_axi_hp1_rvalid),
        .S_AXI_HP1_rlast    (m_axi_hp1_rlast),
        .S_AXI_HP1_rready   (m_axi_hp1_rready),

        // ??????
        .frame_done_irq     (frame_done_irq_w),

        // OV5640 GPIO
        .ov5640_reset_n     (),//(ov5640_reset_n),
        .ov5640_pwdn        (ov5640_pwdn),
        .ov5640_mclk        (ov5640_mclk),

        // I2C ???
        .iic_scl_i          (iic_scl_i_w),
        .iic_scl_o          (iic_scl_o_w),
        .iic_scl_t          (iic_scl_t_w),
        .iic_sda_i          (iic_sda_i_w),
        .iic_sda_o          (iic_sda_o_w),
        .iic_sda_t          (iic_sda_t_w)
    );

    // =========================================================================
    // D. AXI4-Lite ??????(axil_cfg_reg)
    // =========================================================================
    /* N18: +r_dbg@0x28; +sensor_if / preproc / wr_lines status @0x220+
     * N23: +wr_drop_cnt @0x230 */
    localparam NUM_WR_REGS = 12;
    localparam NUM_RD_REGS = 13;
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

    // ??????
    wire [31:0] r_fb_addr_a   = cfg_wreg[0*32 +: 32];
    wire [31:0] r_fb_addr_b   = cfg_wreg[1*32 +: 32];
    wire [31:0] r_ctrl        = cfg_wreg[2*32 +: 32];
    wire [12:0] r_black_level = cfg_wreg[3*32 +: 13];
    /* PS ?? config ? cfg_wreg=0?wb_gain=0 ?? R/G/B ??? 0 ? ?? */
    wire [11:0] r_wb_gain_r   = (|cfg_wreg[4*32 +: 12]) ? cfg_wreg[4*32 +: 12] : 12'd1024;
    wire [11:0] r_wb_gain_g   = (|cfg_wreg[5*32 +: 12]) ? cfg_wreg[5*32 +: 12] : 12'd1024;
    wire [11:0] r_wb_gain_b   = (|cfg_wreg[6*32 +: 12]) ? cfg_wreg[6*32 +: 12] : 12'd1024;
    wire [31:0] r_gamma_wr    = cfg_wreg[7*32 +: 32];
    wire [31:0] r_ddr3_base   = cfg_wreg[8*32 +: 32];
    /* PS never writes CFG safely; default FB away from low DDR (code/bss/DMA). */
    wire [31:0] ddr3_base_addr = (|r_ddr3_base) ? r_ddr3_base : 32'h6000_0000;
    wire [31:0] r_sy_lut      = cfg_wreg[9*32 +: 32];
    /* N18: r_dbg @ 0x28 — do NOT use r_ctrl@0x08 (PS write hang).
     * [1:0] DDR wr src: 0=bilat 1=MIPI RAW gray 2=pat gray 3=preproc RGB
     * [2]   force isp_src_test (pattern into ISP); auto-set when src==2
     * N23: before first PS write, default src=MIPI so boot does not desync FB */
    wire [31:0] r_dbg         = cfg_wreg[10*32 +: 32];
    reg         dbg_ps_written;
    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n)
            dbg_ps_written <= 1'b0;
        else if (cfg_wreg_wr[10])
            dbg_ps_written <= 1'b1;
    end
    wire [1:0]  dbg_ddr_src   = dbg_ps_written ? r_dbg[1:0] : 2'd1;
    wire        dbg_force_pat = r_dbg[2] | (dbg_ddr_src == 2'd2);
    /* n7o: capture_en tied high; gating = tready rising-edge arm in frame_eth_tx */
    wire        eth_capture_en = 1'b1;

    /* cfg_start still gates display_ctrl AXI FB writes only (see zynq_display_ctrl).
     * res_sel: PS never writes r_ctrl; default 1080p (01) so HDMI timing matches IMG_W/H. */
    wire        cfg_start     = r_ctrl[0];
    wire [1:0]  res_sel       = (|r_ctrl[2:1]) ? r_ctrl[2:1] : 2'b01;
    /* r_ctrl[8]=legacy ETH test_pat bypass; [9]=ISP test RAW; [10]=ETH from CLAHE */
    wire        test_pat_en    = r_ctrl[8];
    wire        isp_src_test   = dbg_force_pat ? 1'b1 :
                                 (((r_ctrl & 32'h00000600) == 32'h0) ?
                                  ISP_USE_TEST_RAW : r_ctrl[9]);
    wire        eth_from_clahe = ((r_ctrl & 32'h00000600) == 32'h0) ?
                                  ETH_USE_CLAHE : r_ctrl[10];
    wire        gamma_lut_we  = cfg_wreg_wr[7];
    wire [7:0]  gamma_lut_wa  = r_gamma_wr[20:13];
    wire [12:0] gamma_lut_wd  = r_gamma_wr[12:0];
    wire        sy_lut_we     = cfg_wreg_wr[9];
    wire [9:0]  sy_lut_wa     = r_sy_lut[22:13];
    wire [12:0] sy_lut_wd     = r_sy_lut[12:0];

    // =========================================================================
    // E. ????MIPI AXI-Stream -> Q0.13 ????
    //    MIPI_MODE=1: ??mipi_tdata[19:0] ?? 2 lane RAW10
    //    Q0.13: P = {RAW10[9:0], 3'b0}????3 ??max=8184)
    // =========================================================================
    wire [PIXEL_W-1:0] si_raw_data;
    wire               si_raw_valid;
    wire               si_raw_hsync;
    wire               si_raw_vsync;

    wire [PIXEL_W-1:0] mipi_raw_data;
    wire               mipi_raw_valid;
    wire               mipi_raw_hsync;
    wire               mipi_raw_vsync;
    wire [1:0]         si_bayer_phase;
    wire [15:0]        si_frame_width;
    wire [15:0]        si_csi_line_px;
    wire [15:0]        si_frame_height;
    wire [31:0]        si_frame_cnt;
    wire               si_locked;

    wire [PIXEL_W-1:0] pat_raw_data;
    wire               pat_raw_valid;
    wire               pat_raw_hsync;
    wire               pat_raw_vsync;
    wire               pat_raw_ready;
    wire               clahe_fifo_almost_full;
    /* Declared early: sensor_if.dst_stall + pat backpressure (driven by ddr3 buf) */
    wire               ddr3_wr_fifo_full;
    wire               ddr3_wr_fifo_prog_full;

    sensor_if #(
        .RAW_W     (RAW_W),
        .PIXEL_W   (PIXEL_W),
        .IMG_W     (IMG_W),
        .IMG_H     (IMG_H),
        .BAYER_FMT (1),        // N23: GRBG (colorbar Mg-R-B-K; was 0=RGGB)
        .VSYNC_POL (0),
        .HREF_POL  (0),
        .MIPI_MODE (1)         // MIPI CSI-2 ??
    ) u_sensor_if (
        .pclk        (pl_clk),  // MIPI?pl_clk ????
        .rst_n       (rst_n),
        // DVP ????0
        .dvp_data    ({RAW_W{1'b0}}),
        .dvp_href    (1'b0),
        .dvp_vsync   (1'b0),
        .dvp_pclk_en (1'b0),
        // MIPI AXI4-Stream ??
        .mipi_tdata  (mipi_tdata_w),
        .mipi_tvalid (mipi_tvalid_w),
        .mipi_tready (mipi_tready_w),
        .mipi_tlast  (mipi_tlast_w),
        .mipi_tuser  (mipi_tuser_w),
        // ??????(Q0.13, pl_clk ??
        .m_raw_data  (mipi_raw_data),
        .m_raw_valid (mipi_raw_valid),
        .m_raw_hsync (mipi_raw_hsync),
        .m_raw_vsync (mipi_raw_vsync),
        .bayer_phase  (si_bayer_phase),
        .frame_width  (si_frame_width),
        .frame_height (si_frame_height),
        .frame_cnt    (si_frame_cnt),
        .locked       (si_locked),
        .mipi_beat_cnt (mipi_beat_cnt_w),
        .mipi_pix_cnt  (mipi_pix_cnt_w),
        .csi_line_px   (si_csi_line_px),
        /* N23: pause CSI when DDR wr FIFO almost full */
        .dst_stall     (ddr3_wr_fifo_prog_full)
    );

    /* N20: dbg src=2 must backpressure on DDR wr FIFO — ready=1 dropped pixels
     * and destroyed geometry (observed period≈2048). Still ignore eth pause. */
    assign pat_raw_ready = (dbg_ddr_src == 2'd2) ? !ddr3_wr_fifo_full :
                           (isp_src_test ? !eth_pause_src : 1'b1);

    isp_raw_pat_gen #(
        .RAW_W         (RAW_W),
        .PIXEL_W       (PIXEL_W),
        .IMG_W         (IMG_W),
        .IMG_H         (IMG_H),
        .LINE_STRIDE_W (IMG_W)
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
    // F. ISP front-end (demosaic RGB + gamma)
    // =========================================================================
    wire [PIXEL_W-1:0] preproc_Y, preproc_R, preproc_G, preproc_B;
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
        .m_R_data       (preproc_R),
        .m_G_data       (preproc_G),
        .m_B_data       (preproc_B),
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
        /* N25: runtime Bayer phase via r_dbg[4:3]; UART 'b' cycles 0..3 */
        .bayer_fmt      (r_dbg[4:3]),
        .dead_pixel_cnt (dead_cnt_w_int)
    );

    // Delay preproc by 1clk so tlast can mark EOL on the previous pixel.
    reg                preproc_valid_d;
    reg [PIXEL_W-1:0]  preproc_R_d, preproc_G_d, preproc_B_d;
    reg                preproc_sof_d;
    wire               preproc_tlast = preproc_valid_d && preproc_valid &&
                                       preproc_hsync && !preproc_vsync;

    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n) begin
            preproc_valid_d <= 1'b0;
            preproc_R_d     <= {PIXEL_W{1'b0}};
            preproc_G_d     <= {PIXEL_W{1'b0}};
            preproc_B_d     <= {PIXEL_W{1'b0}};
            preproc_sof_d   <= 1'b0;
        end else begin
            preproc_valid_d <= preproc_valid;
            preproc_sof_d   <= preproc_sof;
            if (preproc_valid) begin
                preproc_R_d <= preproc_R;
                preproc_G_d <= preproc_G;
                preproc_B_d <= preproc_B;
            end
        end
    end

    // =========================================================================
    // G/H/I. Per-channel linebuf + enhance + bilateral (R/G/B)
    // =========================================================================
    localparam NUM_LINES = 11;

    wire [PIXEL_W-1:0] bilat_R, bilat_G, bilat_B;
    wire               bilat_valid_r, bilat_valid_g, bilat_valid_b;
    wire               bilat_sof_r, bilat_sof_g, bilat_sof_b;
    wire               bilat_hsync_g;

    wire [PIXEL_W*NUM_LINES-1:0] col_pix_r, col_pix_g, col_pix_b;
    wire               col_valid_r, col_valid_g, col_valid_b;
    wire [10:0]        col_x_r, col_y_r, col_x_g, col_y_g, col_x_b, col_y_b;
    wire               col_sof_r, col_sof_g, col_sof_b;

    wire [PIXEL_W-1:0] enh_R, enh_G, enh_B;
    wire               enh_valid_r, enh_valid_g, enh_valid_b;
    wire               enh_sof_r, enh_sof_g, enh_sof_b;
    wire [10:0]        enh_x_r, enh_y_r, enh_x_g, enh_y_g, enh_x_b, enh_y_b;

    line_buffer_ctrl #(.PIXEL_W(PIXEL_W), .LINE_LEN(LINE_LEN), .NUM_LINES(NUM_LINES), .IMG_H(IMG_H)) u_linebuf_r (
        .clk(pl_clk), .rst_n(rst_n),
        .s_pixel_tdata(preproc_R_d), .s_pixel_tvalid(preproc_valid_d),
        .s_pixel_tlast(preproc_tlast), .s_pixel_sof(preproc_sof_d), .s_pixel_tready(),
        .col_pixels(col_pix_r), .col_valid(col_valid_r),
        .col_x(col_x_r), .col_y(col_y_r), .col_sof(col_sof_r),
        .buf_full(), .fill_lines(), .wr_ptr_x()
    );
    line_buffer_ctrl #(.PIXEL_W(PIXEL_W), .LINE_LEN(LINE_LEN), .NUM_LINES(NUM_LINES), .IMG_H(IMG_H)) u_linebuf_g (
        .clk(pl_clk), .rst_n(rst_n),
        .s_pixel_tdata(preproc_G_d), .s_pixel_tvalid(preproc_valid_d),
        .s_pixel_tlast(preproc_tlast), .s_pixel_sof(preproc_sof_d), .s_pixel_tready(),
        .col_pixels(col_pix_g), .col_valid(col_valid_g),
        .col_x(col_x_g), .col_y(col_y_g), .col_sof(col_sof_g),
        .buf_full(), .fill_lines(), .wr_ptr_x()
    );
    line_buffer_ctrl #(.PIXEL_W(PIXEL_W), .LINE_LEN(LINE_LEN), .NUM_LINES(NUM_LINES), .IMG_H(IMG_H)) u_linebuf_b (
        .clk(pl_clk), .rst_n(rst_n),
        .s_pixel_tdata(preproc_B_d), .s_pixel_tvalid(preproc_valid_d),
        .s_pixel_tlast(preproc_tlast), .s_pixel_sof(preproc_sof_d), .s_pixel_tready(),
        .col_pixels(col_pix_b), .col_valid(col_valid_b),
        .col_x(col_x_b), .col_y(col_y_b), .col_sof(col_sof_b),
        .buf_full(), .fill_lines(), .wr_ptr_x()
    );

    wire [PIXEL_W-1:0] centre_r = col_pix_r[5*PIXEL_W +: PIXEL_W];
    wire [PIXEL_W-1:0] centre_g = col_pix_g[5*PIXEL_W +: PIXEL_W];
    wire [PIXEL_W-1:0] centre_b = col_pix_b[5*PIXEL_W +: PIXEL_W];

    local_detail_enhance_11x11 #(.PIXEL_W(PIXEL_W), .WIN_SIZE(11), .LINE_LEN(LINE_LEN)) u_enh_r (
        .clk(pl_clk), .rst_n(rst_n),
        .col_pixels(col_pix_r), .col_valid(col_valid_r),
        .col_x(col_x_r), .col_y(col_y_r), .col_sof(col_sof_r), .centre_pix(centre_r),
        .lut_wr_data(sy_lut_wd), .lut_wr_addr(sy_lut_wa), .lut_wr_en(sy_lut_we),
        .m_enh_data(enh_R), .m_enh_valid(enh_valid_r),
        .m_enh_x(enh_x_r), .m_enh_y(enh_y_r), .m_enh_sof(enh_sof_r)
    );
    local_detail_enhance_11x11 #(.PIXEL_W(PIXEL_W), .WIN_SIZE(11), .LINE_LEN(LINE_LEN)) u_enh_g (
        .clk(pl_clk), .rst_n(rst_n),
        .col_pixels(col_pix_g), .col_valid(col_valid_g),
        .col_x(col_x_g), .col_y(col_y_g), .col_sof(col_sof_g), .centre_pix(centre_g),
        .lut_wr_data(sy_lut_wd), .lut_wr_addr(sy_lut_wa), .lut_wr_en(sy_lut_we),
        .m_enh_data(enh_G), .m_enh_valid(enh_valid_g),
        .m_enh_x(enh_x_g), .m_enh_y(enh_y_g), .m_enh_sof(enh_sof_g)
    );
    local_detail_enhance_11x11 #(.PIXEL_W(PIXEL_W), .WIN_SIZE(11), .LINE_LEN(LINE_LEN)) u_enh_b (
        .clk(pl_clk), .rst_n(rst_n),
        .col_pixels(col_pix_b), .col_valid(col_valid_b),
        .col_x(col_x_b), .col_y(col_y_b), .col_sof(col_sof_b), .centre_pix(centre_b),
        .lut_wr_data(sy_lut_wd), .lut_wr_addr(sy_lut_wa), .lut_wr_en(sy_lut_we),
        .m_enh_data(enh_B), .m_enh_valid(enh_valid_b),
        .m_enh_x(enh_x_b), .m_enh_y(enh_y_b), .m_enh_sof(enh_sof_b)
    );

    wire enh_hsync_r = enh_valid_r & (enh_x_r == 11'd0);
    wire enh_hsync_g = enh_valid_g & (enh_x_g == 11'd0);
    wire enh_hsync_b = enh_valid_b & (enh_x_b == 11'd0);
    /* Frame SOF only from pipeline-delayed enhance SOF (no coordinate fake SOF) */
    wire enh_sof_in_r = enh_sof_r;
    wire enh_sof_in_g = enh_sof_g;
    wire enh_sof_in_b = enh_sof_b;

    bilateral_filter #(.PIXEL_W(PIXEL_W), .LINE_LEN(LINE_LEN), .WIN_HALF(2), .NORM_SHIFT(8)) u_bilat_r (
        .clk(pl_clk), .rst_n(rst_n),
        .s_pix_data(enh_R), .s_pix_valid(enh_valid_r),
        .s_pix_sof(enh_sof_in_r), .s_pix_hsync(enh_hsync_r),
        .lut_wr_addr(8'b0), .lut_wr_data(8'b0), .lut_wr_en(1'b0),
        .m_pix_data(bilat_R), .m_pix_valid(bilat_valid_r),
        .m_pix_sof(bilat_sof_r), .m_pix_hsync()
    );
    bilateral_filter #(.PIXEL_W(PIXEL_W), .LINE_LEN(LINE_LEN), .WIN_HALF(2), .NORM_SHIFT(8)) u_bilat_g (
        .clk(pl_clk), .rst_n(rst_n),
        .s_pix_data(enh_G), .s_pix_valid(enh_valid_g),
        .s_pix_sof(enh_sof_in_g), .s_pix_hsync(enh_hsync_g),
        .lut_wr_addr(8'b0), .lut_wr_data(8'b0), .lut_wr_en(1'b0),
        .m_pix_data(bilat_G), .m_pix_valid(bilat_valid_g),
        .m_pix_sof(bilat_sof_g), .m_pix_hsync(bilat_hsync_g)
    );
    bilateral_filter #(.PIXEL_W(PIXEL_W), .LINE_LEN(LINE_LEN), .WIN_HALF(2), .NORM_SHIFT(8)) u_bilat_b (
        .clk(pl_clk), .rst_n(rst_n),
        .s_pix_data(enh_B), .s_pix_valid(enh_valid_b),
        .s_pix_sof(enh_sof_in_b), .s_pix_hsync(enh_hsync_b),
        .lut_wr_addr(8'b0), .lut_wr_data(8'b0), .lut_wr_en(1'b0),
        .m_pix_data(bilat_B), .m_pix_valid(bilat_valid_b),
        .m_pix_sof(bilat_sof_b), .m_pix_hsync()
    );

    // Align on G channel timing; SOF only from bilateral (no pixel-count fake SOF)
    wire               bilat_valid = bilat_valid_g;
    wire [PIXEL_W-1:0] bilat_Y;
    wire               bilat_sof   = bilat_sof_g;

    // BT.601 Y from filtered RGB (same cycle as bilat_valid)
    wire [22:0] bilat_y_sum = bilat_R * 23'd306 + bilat_G * 23'd601 + bilat_B * 23'd117;
    assign bilat_Y = bilat_y_sum[22:10];

    // =========================================================================
    // J. CLAHE (Y from filtered RGB) + HDMI path
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

    assign clahe_fifo_wdata = {bilat_sof, bilat_Y};
    assign clahe_fifo_wr   = bilat_valid && !clahe_fifo_full;

    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n) begin
            fifo_ovf_cnt_r  <= 32'd0;
            sof_cnt_pre_r   <= 8'd0;
            sof_cnt_col_r   <= 8'd0;
            sof_cnt_enh_r   <= 8'd0;
            sof_cnt_bilat_r <= 8'd0;
            sof_pre_d       <= 1'b0;
            sof_col_d       <= 1'b0;
            sof_enh_d       <= 1'b0;
            sof_bilat_d     <= 1'b0;
        end else begin
            if (bilat_valid && clahe_fifo_full)
                fifo_ovf_cnt_r <= fifo_ovf_cnt_r + 32'd1;

            sof_pre_d   <= preproc_sof;
            sof_col_d   <= col_sof_g;
            sof_enh_d   <= enh_sof_g;
            sof_bilat_d <= bilat_sof;
            if (preproc_sof && !sof_pre_d && sof_cnt_pre_r != 8'hFF)
                sof_cnt_pre_r <= sof_cnt_pre_r + 8'd1;
            if (col_sof_g && !sof_col_d && sof_cnt_col_r != 8'hFF)
                sof_cnt_col_r <= sof_cnt_col_r + 8'd1;
            if (enh_sof_g && !sof_enh_d && sof_cnt_enh_r != 8'hFF)
                sof_cnt_enh_r <= sof_cnt_enh_r + 8'd1;
            if (bilat_sof && !sof_bilat_d && sof_cnt_bilat_r != 8'hFF)
                sof_cnt_bilat_r <= sof_cnt_bilat_r + 8'd1;
        end
    end

    wire [31:0] sof_diag_w = {sof_cnt_bilat_r, sof_cnt_enh_r, sof_cnt_col_r, sof_cnt_pre_r};

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

    // K. DDR + AXI4 HP1 (N12: RGBX 4B/px; DISABLE_AXI_R for PS 2B read path)
    // =========================================================================
    wire [7:0]         disp_r8, disp_g8, disp_b8;
    wire               disp_pix_valid;
    wire               ddr3_wr_page;
    wire [31:0]        ddr3_wr_frame_cnt;
    wire [31:0]        ddr3_axi_diag_cnt;
    wire [15:0]        ddr3_measured_line_px;
    wire [31:0]        ddr3_wr_drop_cnt;

    /* N18 dbg DDR wr mux (r_dbg[1:0]); default 0 = legacy bilat/CLAHE path */
    wire [7:0] mipi_raw8 = mipi_raw_data[PIXEL_W-1 -: 8];
    wire [7:0] pat_raw8  = pat_raw_data[PIXEL_W-1 -: 8];
    wire [7:0] bilat_r8  = ETH_FROM_DDR3 ? bilat_R[12:5] : clahe_Y[12:5];
    wire [7:0] bilat_g8  = ETH_FROM_DDR3 ? bilat_G[12:5] : clahe_Y[12:5];
    wire [7:0] bilat_b8  = ETH_FROM_DDR3 ? bilat_B[12:5] : clahe_Y[12:5];
    wire       bilat_v   = ETH_FROM_DDR3 ? bilat_valid : clahe_valid;
    wire       bilat_s   = ETH_FROM_DDR3 ? bilat_sof   : clahe_sof;

    wire [7:0] ddr3_wr_r = (dbg_ddr_src == 2'd1) ? mipi_raw8 :
                           (dbg_ddr_src == 2'd2) ? pat_raw8  :
                           (dbg_ddr_src == 2'd3) ? preproc_R[12:5] : bilat_r8;
    wire [7:0] ddr3_wr_g = (dbg_ddr_src == 2'd1) ? mipi_raw8 :
                           (dbg_ddr_src == 2'd2) ? pat_raw8  :
                           (dbg_ddr_src == 2'd3) ? preproc_G[12:5] : bilat_g8;
    wire [7:0] ddr3_wr_b = (dbg_ddr_src == 2'd1) ? mipi_raw8 :
                           (dbg_ddr_src == 2'd2) ? pat_raw8  :
                           (dbg_ddr_src == 2'd3) ? preproc_B[12:5] : bilat_b8;
    wire       ddr3_wr_valid = (dbg_ddr_src == 2'd1) ? mipi_raw_valid :
                               (dbg_ddr_src == 2'd2) ? pat_raw_valid  :
                               (dbg_ddr_src == 2'd3) ? preproc_valid  : bilat_v;
    wire       ddr3_wr_sof   = (dbg_ddr_src == 2'd1) ? (mipi_raw_valid & mipi_raw_vsync) :
                               (dbg_ddr_src == 2'd2) ? (pat_raw_valid  & pat_raw_vsync)  :
                               (dbg_ddr_src == 2'd3) ? preproc_sof : bilat_s;
    wire       ddr3_wr_hsync = (dbg_ddr_src == 2'd1) ? mipi_raw_hsync :
                               (dbg_ddr_src == 2'd2) ? pat_raw_hsync  :
                               (dbg_ddr_src == 2'd3) ? preproc_hsync  : bilat_hsync_g;

    /* N18: measure preproc line length + DDR-write lines/frame */
    reg  [15:0] pre_line_cnt_r, pre_measured_line_r;
    reg  [15:0] dbg_wr_line_cnt_r, dbg_wr_lines_frame_r;
    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n) begin
            pre_line_cnt_r      <= 16'd0;
            pre_measured_line_r <= 16'd0;
        end else if (preproc_valid) begin
            if (preproc_hsync) begin
                pre_measured_line_r <= pre_line_cnt_r;
                pre_line_cnt_r      <= 16'd1;
            end else begin
                pre_line_cnt_r <= pre_line_cnt_r + 16'd1;
            end
        end
    end
    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n) begin
            dbg_wr_line_cnt_r    <= 16'd0;
            dbg_wr_lines_frame_r <= 16'd0;
        end else if (ddr3_wr_valid && ddr3_wr_sof) begin
            dbg_wr_lines_frame_r <= dbg_wr_line_cnt_r;
            dbg_wr_line_cnt_r    <= 16'd1;
        end else if (ddr3_wr_valid && ddr3_wr_hsync) begin
            dbg_wr_line_cnt_r <= dbg_wr_line_cnt_r + 16'd1;
        end
    end

    /* display_ctrl still takes PIXEL_W; feed R as luma proxy */
    wire [PIXEL_W-1:0] disp_pix = {disp_r8, 5'b0};

    ddr3_pixel_buf #(
        .PIXEL_W        (PIXEL_W),
        .AXI_DW         (AXI_DW),
        .AXI_AW         (AXI_AW),
        .BURST_LEN      (16),
        .IMG_W          (IMG_W),
        .IMG_H          (IMG_H),
        /* N20: hsync crop to IMG_W; page = 1920*1080*4 */
        .LINE_STRIDE_PX (IMG_W),
        .DROP_EXTRA     (0),
        .CROP_EN        (1),
        .FORCE_RAMP_OUT (DDR3_FORCE_RAMP),
        .DISABLE_AXI_R  (1),
        /* N23: deep FIFO + outstanding writes */
        .WR_FIFO_DEPTH  (2048),
        .MAX_OUTSTANDING(8)
    ) u_ddr3_buf (
        .clk           (pl_clk),
        .rst_n         (rst_n),
        .s_pix_r       (ddr3_wr_r),
        .s_pix_g       (ddr3_wr_g),
        .s_pix_b       (ddr3_wr_b),
        .s_pix_valid   (ddr3_wr_valid),
        .s_pix_sof     (ddr3_wr_sof),
        .s_pix_hsync   (ddr3_wr_hsync),
        .buf_base_addr (ddr3_base_addr),
        .rd_stall      (ETH_FROM_DDR3 ? eth_pause_src : 1'b0),
        .m_pix_r       (disp_r8),
        .m_pix_g       (disp_g8),
        .m_pix_b       (disp_b8),
        .m_pix_valid   (disp_pix_valid),
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
        .wr_page       (ddr3_wr_page),
        .wr_frame_cnt  (ddr3_wr_frame_cnt),
        .wr_fifo_full  (ddr3_wr_fifo_full),
        .wr_fifo_prog_full (ddr3_wr_fifo_prog_full),
        .rd_fifo_empty (),
        .axi_diag_cnt  (ddr3_axi_diag_cnt),
        .measured_line_px (ddr3_measured_line_px),
        .wr_drop_cnt   (ddr3_wr_drop_cnt)
    );

    // =========================================================================
    // K2. ETH from bilat RGB (default) / CLAHE gray as RGBX fallback
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

    /* N9b: synthesize SOF on ddr3 readout (page loop, pixel0 = frame start). */
    localparam integer DDR3_FRAME_PIX = IMG_W * IMG_H;
    reg [20:0] ddr3_rd_pix_cnt;
    always @(posedge pl_clk or negedge rst_n) begin
        if (!rst_n)
            ddr3_rd_pix_cnt <= 21'd0;
        else if (disp_pix_valid) begin
            if (ddr3_rd_pix_cnt == DDR3_FRAME_PIX[20:0] - 21'd1)
                ddr3_rd_pix_cnt <= 21'd0;
            else
                ddr3_rd_pix_cnt <= ddr3_rd_pix_cnt + 21'd1;
        end
    end
    wire ddr3_rd_sof = disp_pix_valid && (ddr3_rd_pix_cnt == 21'd0);

    /* N12: ETH_FROM_DDR3 taps RGB from ddr3 readout (2A); else bilat RGB / clahe gray.
     * Reconstruct Q0.13 so frame_eth_tx [12:5] recovers the 8-bit value. */
    wire [PIXEL_W-1:0] eth_r = ETH_FROM_DDR3 ? {disp_r8, 5'b0} :
                               (eth_from_clahe ? clahe_Y : bilat_R);
    wire [PIXEL_W-1:0] eth_g = ETH_FROM_DDR3 ? {disp_g8, 5'b0} :
                               (eth_from_clahe ? clahe_Y : bilat_G);
    wire [PIXEL_W-1:0] eth_b = ETH_FROM_DDR3 ? {disp_b8, 5'b0} :
                               (eth_from_clahe ? clahe_Y : bilat_B);
    wire               eth_pix_valid = ETH_FROM_DDR3 ? disp_pix_valid :
                                       (eth_from_clahe ? clahe_valid : bilat_valid);
    wire               eth_pix_sof   = ETH_FROM_DDR3 ? ddr3_rd_sof :
                                       (eth_from_clahe ? clahe_sof   : bilat_sof);

    (* mark_debug = "true" *) wire dbg_eth_valid = eth_pix_valid;
    (* mark_debug = "true" *) wire dbg_axis_tvalid = eth_axis_tvalid;
    (* mark_debug = "true" *) wire dbg_axis_tready = eth_axis_tready;
    (* mark_debug = "true" *) wire dbg_axis_tlast  = eth_axis_tlast;
    /* N7 SOF chain probes (first disconnect was linebuf col_sof) */
    (* mark_debug = "true" *) wire dbg_preproc_sof = preproc_sof;
    (* mark_debug = "true" *) wire dbg_col_sof_g   = col_sof_g;
    (* mark_debug = "true" *) wire dbg_enh_sof_g   = enh_sof_g;
    (* mark_debug = "true" *) wire dbg_enh_sof_in_g = enh_sof_in_g;
    (* mark_debug = "true" *) wire dbg_bilat_sof   = bilat_sof;
    (* mark_debug = "true" *) wire dbg_eth_sof     = eth_pix_sof;

    frame_eth_tx #(
        .PIXEL_W         (PIXEL_W),
        .IMG_W           (IMG_W),
        .IMG_H           (IMG_H),
        .AXIS_DW         (32),
        .FORMAT          (8'd1),
        .FORCE_ETH_RAMP  (ETH_FORCE_RAMP)
    ) u_frame_eth (
        .clk            (pl_clk),
        .rst_n          (rst_n),
        .s_pix_r        (eth_r),
        .s_pix_g        (eth_g),
        .s_pix_b        (eth_b),
        .s_pix_valid    (eth_pix_valid),
        .s_pix_sof      (eth_pix_sof),
        .m_axis_tdata   (eth_axis_tdata),
        .m_axis_tvalid  (eth_axis_tvalid),
        .m_axis_tready  (eth_axis_tready),
        .m_axis_tlast   (eth_axis_tlast),
        .m_axis_tkeep   (eth_axis_tkeep),
        .frame_skip     (r_ctrl[7:4]),
        .capture_en     (eth_capture_en),
        .tx_frame_cnt   (eth_tx_frame_cnt),
        .skid_ovf_cnt   (eth_skid_ovf_cnt),
        .pause_src      (eth_pause_src)
    );


    // =========================================================================
    // L. ?????AXI4 HP0 ??DDR + VGA ??
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
        .pclk           (pclk),     // 148.5 MHz MMCM ????
        .pclk_rst_n     (pclk_resetn),
        .rst_n          (rst_n),
        .s_pix_data     (disp_pix),
        .s_pix_valid    (disp_pix_valid),
        .fb_addr_a      (r_fb_addr_a),
        .fb_addr_b      (r_fb_addr_b),
        .cfg_start      (cfg_start),
        .res_sel        (res_sel),
        // AXI4 HP0 ???
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
        // VGA ????????pclk ????HDMI??
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
    // M. ???????
    // =========================================================================
    assign cfg_status = {
        /* 0x230: N23 DDR packer drop count (must stay 0) */
        ddr3_wr_drop_cnt,
        /* 0x22C: N22 ungated CSI line length (px between tlast) */
        {16'b0, si_csi_line_px},
        /* 0x228: DDR wr lines latched at SOF {0, lines_per_frame} */
        {16'b0, dbg_wr_lines_frame_r},
        /* 0x224: [31]=locked [25:24]=bayer [15:0]=preproc_line_px */
        {si_locked, 5'b0, si_bayer_phase, 8'b0, pre_measured_line_r},
        /* 0x220: sensor_if {frame_height, frame_width} */
        {si_frame_height, si_frame_width},
        /* 0x21C: N16 measured input line length (px) before DDR crop */
        {16'b0, ddr3_measured_line_px},
        /* 0x218: SOF diag; ETH_FROM_DDR3 -> axi_diag {b_hs,w_hs,ar_hs,r_hs} */
        (ETH_FROM_DDR3 ? ddr3_axi_diag_cnt : sof_diag_w),
        /* 0x214: clahe pix; ETH_FROM_DDR3 -> {wr_page,15'b0,wr_frame[15:0]} */
        (ETH_FROM_DDR3 ? {ddr3_wr_page, 15'b0, ddr3_wr_frame_cnt[15:0]}
                       : clahe_pixel_cnt_r),
        raw_pixel_cnt_w,
        mipi_pix_cnt_w,
        mipi_beat_cnt_w,
        /* 0x204: [31:16]=skid_ovf sticky, [15:0]=eth tx frame cnt */
        {eth_skid_ovf_cnt, eth_tx_frame_cnt},
        dead_cnt_w_int
    };

    // =========================================================================
    // N. HDMI: true color from display FB luma path still gray; when display
    // is fed R-proxy only, keep R=G=B. Full RGB HDMI needs display_ctrl RGBX.
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
            /* R channel as luma proxy until display_ctrl stores RGBX */
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
    // ???frame_done_irq ??u_display -> BD -> PS GIC
    // =========================================================================
    //assign buf_sel_out         = buf_sel_w;
    //assign dead_pixel_cnt_out  = dead_cnt_w_int;
    assign dead_cnt_w = dead_cnt_w_int;

endmodule