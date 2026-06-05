###############################################################
# create_bd_ov5640.tcl
# Block Design 创建脚本 — ZU4EV + OV5640 MIPI CSI-2
#
# BD 架构说明:
#   BD 包含 PS 基础设施 + HDMI 像素时钟生成:
#     zynq_ultra_ps_e_0, mipi_csi2_rx_subsystem_0,
#     axi_iic_0, axi_gpio_0, proc_sys_reset_0,
#     axi_sc_cfg (1→4), axi_sc_hp0 (1→1), axi_sc_hp1 (1→1),
#     clk_wiz_0 (MMCM: 150 MHz → 148.5 MHz pclk), rst_pclk_0
#
#   BD 对外暴露的接口 (连接到 imgproc_top_ov5640.v):
#     输出到 RTL:
#       pl_clk        — 系统时钟 ~150 MHz (PS FCLK_CLK0)
#       rst_n         — 同步低有效复位 (peripheral_aresetn, pl_clk 域)
#       pclk          — HDMI 像素时钟 148.5 MHz (板内 MMCM 精确输出)
#       pclk_resetn   — 像素时钟域同步复位
#       VIDEO_OUT     — MIPI CSI-2 解包后的 AXI4-Stream (20-bit, 2pix/clk)
#       M_AXIL_CFG    — AXI4-Lite Master, 32-bit (PS→imgproc 配置)
#     从 RTL 输入:
#       S_AXI_HP0     — AXI4 Slave, 64-bit (display_ctrl 帧写入)
#       S_AXI_HP1     — AXI4 Slave, 64-bit (ddr3_pixel_buf 乒乓)
#       frame_done_irq — 帧完成中断 → PS pl_ps_irq0
#     物理引脚 (→ XDC):
#       mipi_phy_if   — MIPI CSI-2 差分接口
#       iic_scl/sda   — OV5640 I2C (tristate, IOBUF 在 RTL top)
#       ov5640_reset_n, ov5640_pwdn — GPIO 控制
#       ov5640_mclk   — 24 MHz 来自 PS FCLK_CLK1
#
# --- 与 doc/ACU4EV核心板原理图.pdf、doc/AXU4EVB-P开发板原理图.pdf 文本抽取对照 ---
# 核心板：UART0 -> PS_MIO42/43；SD1 数据线 MIO46..51、CD MIO45（硬件为 SD 2.0）。
# PS 配置：SD1 SLOT_TYPE=SD 2.0，PERIPHERAL_IO={MIO 39 .. 51}（Vivado 枚举），与 UART0 同开。
# 底板 PDF：MIPI_*、CAM_*、FPC J23；PL 见 imgproc_axu4evb_ov5640.xdc。
#
# 以太网（PS GEM3 / ENET3 + PHY1）：与《AXU4EVB-P》原理图一致 — RGMII MIO64..75，
# MDIO MIO76/77。XCZU4EV 上 GEM0 仅允许 MIO26..37 或 EMIO，故 PHY1 必须用 GEM3。
# 修改 BD 后请在 Vivado 中 Regenerate Block Design / Generate Output Products，
# 以刷新 zynq_imgproc_bd_wrapper.v 的 ETH_AXIS_S2MM_* 端口。
################################################################
proc create_bd_ov5640 {} {
    set design_name zynq_imgproc_bd
    # ── 创建 BD ──────────────────────────────────────────────
    create_bd_design $design_name
    current_bd_design $design_name
    # ═══════════════════════════════════════════════════════
    # 1. Zynq UltraScale+ PS (ZU4EV 配置)
    # ═══════════════════════════════════════════════════════
    set ps8 [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:zynq_ultra_ps_e:3.3 \
        zynq_ultra_ps_e_0]
    set_property -dict [list \
        CONFIG.PSU__CRL_APB__PL0_REF_CTRL__FREQMHZ   {150} \
        CONFIG.PSU__CRL_APB__PL1_REF_CTRL__FREQMHZ   {24}  \
        CONFIG.PSU__FPGA_PL0_ENABLE                   {1}   \
        CONFIG.PSU__FPGA_PL1_ENABLE                   {1}   \
        CONFIG.PSU__FPGA_PL2_ENABLE                   {0}   \
        CONFIG.PSU__USE__M_AXI_GP0                    {1}   \
        CONFIG.PSU__MAXIGP0__DATA_WIDTH                {32}  \
        CONFIG.PSU__USE__S_AXI_GP2                    {1}   \
        CONFIG.PSU__SAXIGP2__DATA_WIDTH                {64}  \
        CONFIG.PSU__USE__S_AXI_GP3                    {1}   \
        CONFIG.PSU__SAXIGP3__DATA_WIDTH                {64}  \
        CONFIG.PSU__USE__S_AXI_GP4                    {1}   \
        CONFIG.PSU__SAXIGP4__DATA_WIDTH                {64}  \
        CONFIG.PSU__USE__IRQ0                          {1}   \
        CONFIG.PSU__USE__IRQ1                          {1}   \
        CONFIG.PSU__ENET0__PERIPHERAL__ENABLE          {0}   \
        CONFIG.PSU__ENET3__PERIPHERAL__ENABLE          {1}   \
        CONFIG.PSU__ENET3__PERIPHERAL__IO            {MIO 64 .. 75} \
        CONFIG.PSU__ENET3__GRP_MDIO__ENABLE          {1}   \
        CONFIG.PSU__ENET3__GRP_MDIO__IO              {MIO 76 .. 77} \
        CONFIG.PSU__UART0__PERIPHERAL__ENABLE          {1}   \
        CONFIG.PSU__UART0__PERIPHERAL__IO              {MIO 42 .. 43} \
        CONFIG.PSU__I2C0__PERIPHERAL__ENABLE           {0}   \
        CONFIG.PSU__SD1__PERIPHERAL__ENABLE            {0}   \
        CONFIG.PSU__SD1__GRP_CD__ENABLE                {0}   \
    ] $ps8
    # NOTE: SD1 disabled in PS IP (Vivado IP_Flow 19-3478: MIO39..51 conflicts with UART0 MIO42..43).
    # Hardware SD lines (MIO46..51+CD45) are physically connected; SD boot works via FSBL/U-Boot
    # without PS IP enabling it in the Block Design.
    puts {INFO: PS: UART0 MIO42-43 ON; SD1 DISABLED in BD (MIO conflict) - SD still usable via FSBL}
    # ═══════════════════════════════════════════════════════
    # 2. proc_sys_reset
    # ═══════════════════════════════════════════════════════
    set rst0 [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
        rst_ps8_0_150m]
    set_property CONFIG.C_EXT_RST_WIDTH {1} $rst0
    # ═══════════════════════════════════════════════════════
    # 3. MIPI CSI-2 RX Subsystem
    # ═══════════════════════════════════════════════════════
    set mipi_rx [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:mipi_csi2_rx_subsystem:5.0 \
        mipi_csi2_rx_subsystem_0]
    set_property -dict [list \
        CONFIG.CMN_NUM_LANES        {2}      \
        CONFIG.C_DPHY_LANES         {2}      \
        CONFIG.CMN_PXL_FORMAT       {RAW10}  \
        CONFIG.CMN_NUM_PIXELS       {2}      \
        CONFIG.DPY_LINE_RATE        {500}    \
        CONFIG.CMN_VC               {All}    \
        CONFIG.SupportLevel         {1}      \
        CONFIG.DPY_EN_REG_IF        {true}   \
    ] $mipi_rx
    # 注: DPY_LINE_RATE=500 Mbps 为保守估算,
    #     需根据 OV5640 实际 PLL 配置核实 (见 TODO)
    # ═══════════════════════════════════════════════════════
    # 4. AXI IIC (OV5640 寄存器配置, I2C 地址 0x3C)
    # ═══════════════════════════════════════════════════════
    set iic [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_iic:2.0 \
        axi_iic_0]
    set_property -dict [list \
        CONFIG.IIC_FREQ_KHZ  {100} \
        CONFIG.USE_BOARD_FLOW {false} \
    ] $iic
    # ═══════════════════════════════════════════════════════
    # 5. AXI GPIO (ov5640_reset_n[0], ov5640_pwdn[1])
    # ═══════════════════════════════════════════════════════
    set gpio [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_gpio:2.0 \
        axi_gpio_0]
    set_property -dict [list \
        CONFIG.C_GPIO_WIDTH      {2}  \
        CONFIG.C_ALL_OUTPUTS     {1}  \
        CONFIG.C_DOUT_DEFAULT    {0x0} \
        CONFIG.C_IS_DUAL         {0}  \
    ] $gpio
    # bit[0]=reset_n, bit[1]=pwdn
    # 默认值 0x0 → reset_n=0 (复位中), pwdn=0 (上电)
    # 软件初始化时先拉高 pwdn, 再释放 reset_n
    # ═══════════════════════════════════════════════════════
    # 6. SmartConnect — 配置总线 (PS HPM0 → 5 路 AXI-Lite 从)
    #    M00: imgproc_top AXI-Lite cfg @ 0xA000_0000
    #    M01: AXI IIC              @ 0xA001_0000
    #    M02: AXI GPIO             @ 0xA002_0000
    #    M03: MIPI CSI-2 RX ctrl  @ 0xA003_0000
    #    M04: AXI DMA eth ctrl     @ 0xA004_0000
    # ═══════════════════════════════════════════════════════
    set sc_cfg [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:smartconnect:1.0 \
        axi_sc_cfg]
    set_property -dict [list \
        CONFIG.NUM_SI {1} \
        CONFIG.NUM_MI {5} \
    ] $sc_cfg
    # ═══════════════════════════════════════════════════════
    # 7. SmartConnect — HP0 (imgproc 帧缓冲写 → PS HP0_FPD)
    # ═══════════════════════════════════════════════════════
    set sc_hp0 [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:smartconnect:1.0 \
        axi_sc_hp0]
    set_property -dict [list \
        CONFIG.NUM_SI {1} \
        CONFIG.NUM_MI {1} \
    ] $sc_hp0
    # ═══════════════════════════════════════════════════════
    # 8. SmartConnect — HP1 (imgproc DDR3 乒乓 → PS HP1_FPD)
    # ═══════════════════════════════════════════════════════
    set sc_hp1 [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:smartconnect:1.0 \
        axi_sc_hp1]
    set_property -dict [list \
        CONFIG.NUM_SI {1} \
        CONFIG.NUM_MI {1} \
    ] $sc_hp1
    # ═══════════════════════════════════════════════════════
    # 8b. AXI DMA（S2MM）+ SmartConnect — PL 帧流写 PS DDR（HP2）
    # ═══════════════════════════════════════════════════════
    set dma_eth [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:axi_dma:7.1 \
        axi_dma_eth]
    # AXI DMA v7.1：无 c_s2mm_stream_data_width；S_AXIS 位宽用 c_s_axis_s2mm_tdata_width。
    # 未开异步时钟时无独立 s_axis_s2mm_aclk，仅需 s_axi_lite_aclk + m_axi_s2mm_aclk。
    # 必须关闭 Scatter-Gather（与 eth_stream.c 中 XAxiDma_SimpleTransfer 一致），
    # 否则保留 m_axi_sg_aclk 且未连接会报 BD 41-758。
    set_property -dict [list \
        CONFIG.c_include_mm2s                 {0} \
        CONFIG.c_include_s2mm                 {1} \
        CONFIG.c_include_sg                   {0} \
        CONFIG.c_sg_length_width              {26} \
        CONFIG.c_s2mm_burst_size              {256} \
        CONFIG.c_s_axis_s2mm_tdata_width      {8} \
        CONFIG.c_m_axi_s2mm_data_width        {32} \
    ] $dma_eth
    set sc_hp2 [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:smartconnect:1.0 \
        axi_sc_hp2]
    set_property -dict [list \
        CONFIG.NUM_SI {1} \
        CONFIG.NUM_MI {1} \
    ] $sc_hp2
    # ═══════════════════════════════════════════════════════
    # 9. Clocking Wizard — HDMI 像素时钟 148.5 MHz (1080p60)
    #    板上时钟方案: PS FCLK_CLK0 150 MHz → 板内 MMCM，仅 HDMI 用 CLKOUT1。
    # 9b. 独立 clk_wiz_mipi_ref — 仅输出 200 MHz 供 MIPI dphy_clk_200M
    #    勿用 PS pl_clk2（BUFG_PS→BITSLICE 不可达）；勿与 HDMI 共用同一 MMCM 第二路
    #    （clk_out2 易在实现阶段整片 UNROUTED/PARTIAL）；单独 MMCM 利于 Placer 靠近 HPIO。
    # ═══════════════════════════════════════════════════════
    set clk_wiz [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:clk_wiz:6.0 \
        clk_wiz_0]
    set_property -dict [list \
        CONFIG.PRIMITIVE                  {MMCM}    \
        CONFIG.CLKOUT1_USED               {true}    \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {148.5}   \
        CONFIG.USE_RESET                  {false}   \
        CONFIG.USE_LOCKED                 {true}    \
        CONFIG.PRIM_SOURCE                {No_buffer} \
    ] $clk_wiz
    set clk_mipi_ref [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:clk_wiz:6.0 \
        clk_wiz_mipi_ref]
    # SupportLevel=1 时 MIPI IP 内含 PLL，自行产生 CLKOUTPHY 驱动 BITSLICE_CONTROL.PLL_CLK。
    # 此处 clk_wiz_mipi_ref 只需提供 200 MHz 到 dphy_clk_200M（IP 内部 PLL 的参考时钟），
    # 用普通 Buffer(BUFG) 模式即可；CLKOUTPHY 路径由 IP 自动约束，无需 No_buffer 绕过。
    set_property -dict [list \
        CONFIG.PRIMITIVE                  {MMCM}    \
        CONFIG.CLKOUT1_USED               {true}    \
        CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {200}     \
        CONFIG.USE_RESET                  {false}   \
        CONFIG.USE_LOCKED                 {true}    \
    ] $clk_mipi_ref
    # proc_sys_reset for pixel clock domain (rst_pclk_0)
    # dcm_locked 输入确保 MMCM 锁定后才解除复位
    set rst_pclk [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:proc_sys_reset:5.0 \
        rst_pclk_0]
    set_property CONFIG.C_EXT_RST_WIDTH {1} $rst_pclk
    # ═══════════════════════════════════════════════════════
    # 10. 创建 BD 外部端口
    # ═══════════════════════════════════════════════════════
    # ── 时钟/复位输出到 RTL ──
    # 不设 FREQ_HZ，由 BD 从连接的 PS pl_clk0 引脚自动继承实际频率 (149998505 Hz)
    set pl_clk_port [create_bd_port -dir O -type clk pl_clk]
    set rst_n_port  [create_bd_port -dir O -type rst rst_n]
    # pclk: 148.5 MHz HDMI 像素时钟 (来自 clk_wiz_0 MMCM 输出)
    set pclk_port [create_bd_port -dir O -type clk pclk]
    # FREQ_HZ not set; Vivado auto-inherits from clk_wiz_0/clk_out1
    set pclk_resetn_port [create_bd_port -dir O -type rst pclk_resetn]
    # ── MIPI 物理差分接口 (→ XDC 约束) ──
    set mipi_phy_if_port [create_bd_intf_port \
        -mode Slave \
        -vlnv xilinx.com:interface:mipi_phy_rtl:1.0 \
        mipi_phy_if]
    # ── MIPI AXI-Stream 输出到 RTL (2pix×10bit=20bit tdata) ──
    set video_out_port [create_bd_intf_port \
        -mode Master \
        -vlnv xilinx.com:interface:axis_rtl:1.0 \
        VIDEO_OUT]
    # ── AXI-Lite Master → imgproc_top 配置寄存器 ──
    set m_axil_cfg_port [create_bd_intf_port \
        -mode Master \
        -vlnv xilinx.com:interface:aximm_rtl:1.0 \
        M_AXIL_CFG]
    set_property -dict [list \
        CONFIG.PROTOCOL  {AXI4LITE} \
        CONFIG.ADDR_WIDTH {32} \
        CONFIG.DATA_WIDTH {32} \
    ] $m_axil_cfg_port
    # ── AXI4 Slave HP0 — 从 imgproc zynq_display_ctrl 接收 (写专用) ──
    # 注: BD Slave 端口接受来自外部 RTL Master 的写事务
    #     READ_WRITE_MODE 设为 WRITE_ONLY 使 Wrapper 不生成 AR/R 端口
    set s_axi_hp0_port [create_bd_intf_port \
        -mode Slave \
        -vlnv xilinx.com:interface:aximm_rtl:1.0 \
        S_AXI_HP0]
    set_property -dict [list \
        CONFIG.PROTOCOL         {AXI4}       \
        CONFIG.ADDR_WIDTH       {32}         \
        CONFIG.DATA_WIDTH       {64}         \
        CONFIG.READ_WRITE_MODE  {WRITE_ONLY} \
        CONFIG.HAS_BURST        {1}          \
        CONFIG.HAS_LOCK         {0}          \
        CONFIG.HAS_CACHE        {0}          \
        CONFIG.HAS_REGION       {0}          \
        CONFIG.HAS_QOS          {0}          \
        CONFIG.HAS_WSTRB        {1}          \
        CONFIG.HAS_BRESP        {1}          \
        CONFIG.ID_WIDTH         {0}          \
    ] $s_axi_hp0_port
    # ── AXI4 Slave HP1 — 从 imgproc ddr3_pixel_buf 接收 (读写双向) ──
    set s_axi_hp1_port [create_bd_intf_port \
        -mode Slave \
        -vlnv xilinx.com:interface:aximm_rtl:1.0 \
        S_AXI_HP1]
    set_property -dict [list \
        CONFIG.PROTOCOL         {AXI4}       \
        CONFIG.ADDR_WIDTH       {32}         \
        CONFIG.DATA_WIDTH       {64}         \
        CONFIG.READ_WRITE_MODE  {READ_WRITE} \
        CONFIG.HAS_BURST        {1}          \
        CONFIG.HAS_LOCK         {0}          \
        CONFIG.HAS_CACHE        {0}          \
        CONFIG.HAS_REGION       {0}          \
        CONFIG.HAS_QOS          {0}          \
        CONFIG.HAS_WSTRB        {1}          \
        CONFIG.HAS_BRESP        {1}          \
        CONFIG.ID_WIDTH         {0}          \
    ] $s_axi_hp1_port
    # ── 帧完成中断 (RTL → PS) ──
    create_bd_port -dir I frame_done_irq
    # ── PL AXI-Stream → AXI DMA S2MM（project/src/frame_eth_tx.v → axi_dma_eth）──
    set eth_axis_port [create_bd_intf_port -mode Slave \
        -vlnv xilinx.com:interface:axis_rtl:1.0 \
        ETH_AXIS_S2MM]
    set_property -dict [list \
        CONFIG.TDATA_NUM_BYTES {1} \
        CONFIG.HAS_TLAST {1} \
    ] $eth_axis_port
    # ── OV5640 GPIO 控制 ──
    create_bd_port -dir O ov5640_reset_n
    create_bd_port -dir O ov5640_pwdn
    create_bd_port -dir O ov5640_mclk    ;# 来自 FCLK_CLK1 (24 MHz)
    # ── IIC tristate signals (IOBUF 在 imgproc_top_ov5640.v 中) ──
    create_bd_port -dir I iic_scl_i
    create_bd_port -dir O iic_scl_o
    create_bd_port -dir O iic_scl_t
    create_bd_port -dir I iic_sda_i
    create_bd_port -dir O iic_sda_o
    create_bd_port -dir O iic_sda_t
    # ═══════════════════════════════════════════════════════
    # 10. 时钟连接
    # ═══════════════════════════════════════════════════════
    # FCLK_CLK0 → 系统时钟网络 (约 148 MHz 实际值)
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_ports pl_clk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins rst_ps8_0_150m/slowest_sync_clk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_sc_cfg/aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_sc_hp0/aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_sc_hp1/aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_iic_0/s_axi_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_gpio_0/s_axi_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins mipi_csi2_rx_subsystem_0/video_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins mipi_csi2_rx_subsystem_0/lite_aclk]
    # PS AXI 时钟端口 (必须连接否则综合报错)
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_fpd_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins zynq_ultra_ps_e_0/saxihp0_fpd_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins zynq_ultra_ps_e_0/saxihp1_fpd_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins zynq_ultra_ps_e_0/saxihp2_fpd_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_dma_eth/s_axi_lite_aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_dma_eth/m_axi_s2mm_aclk]
    # 若 SG 仍被打开（参数未生效等），m_axi_sg_aclk 存在则接到 pl_clk0，避免 BD 41-758
    if {[llength [get_bd_pins -quiet axi_dma_eth/m_axi_sg_aclk]]} {
        connect_bd_net \
            [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
            [get_bd_pins axi_dma_eth/m_axi_sg_aclk]
    }
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins axi_sc_hp2/aclk]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins zynq_ultra_ps_e_0/maxihpm0_lpd_aclk]
    # MIPI D-PHY 200 MHz：独立 MMCM；dphy_clk_200M 与 clkoutphy_in 同源（单核常见接法）
    connect_bd_net \
        [get_bd_pins clk_wiz_mipi_ref/clk_out1] \
        [get_bd_pins mipi_csi2_rx_subsystem_0/dphy_clk_200M]
    # SupportLevel=1: clkoutphy_in 已移入 IP 内部，不再暴露为外部端口，故删除该连接。
    # FCLK_CLK0 -> 两路 MMCM 输入
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins clk_wiz_0/clk_in1]
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk0] \
        [get_bd_pins clk_wiz_mipi_ref/clk_in1]
    # clk_wiz_0/clk_out1 (148.5 MHz) -> pclk port + rst_pclk_0
    connect_bd_net \
        [get_bd_pins clk_wiz_0/clk_out1] \
        [get_bd_ports pclk]
    connect_bd_net \
        [get_bd_pins clk_wiz_0/clk_out1] \
        [get_bd_pins rst_pclk_0/slowest_sync_clk]
    # FCLK_CLK1 → OV5640 MCLK (24 MHz)
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_clk1] \
        [get_bd_ports ov5640_mclk]
    # ═══════════════════════════════════════════════════════
    # 11. 复位连接
    # ═══════════════════════════════════════════════════════
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
        [get_bd_pins rst_ps8_0_150m/ext_reset_in]
    # interconnect_aresetn → SmartConnect
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/interconnect_aresetn] \
        [get_bd_pins axi_sc_cfg/aresetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/interconnect_aresetn] \
        [get_bd_pins axi_sc_hp0/aresetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/interconnect_aresetn] \
        [get_bd_pins axi_sc_hp1/aresetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/interconnect_aresetn] \
        [get_bd_pins axi_sc_hp2/aresetn]
    # pl_resetn0 + clk_wiz locked -> rst_pclk_0 (pixel clock reset)
    connect_bd_net \
        [get_bd_pins zynq_ultra_ps_e_0/pl_resetn0] \
        [get_bd_pins rst_pclk_0/ext_reset_in]
    connect_bd_net \
        [get_bd_pins clk_wiz_0/locked] \
        [get_bd_pins rst_pclk_0/dcm_locked]
    connect_bd_net \
        [get_bd_pins rst_pclk_0/peripheral_aresetn] \
        [get_bd_ports pclk_resetn]
    # peripheral_aresetn → 外设 + BD rst_n 端口
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/peripheral_aresetn] \
        [get_bd_ports rst_n]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/peripheral_aresetn] \
        [get_bd_pins mipi_csi2_rx_subsystem_0/video_aresetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/peripheral_aresetn] \
        [get_bd_pins mipi_csi2_rx_subsystem_0/lite_aresetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/peripheral_aresetn] \
        [get_bd_pins axi_iic_0/s_axi_aresetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/peripheral_aresetn] \
        [get_bd_pins axi_dma_eth/axi_resetn]
    connect_bd_net \
        [get_bd_pins rst_ps8_0_150m/peripheral_aresetn] \
        [get_bd_pins axi_gpio_0/s_axi_aresetn]
    # ═══════════════════════════════════════════════════════
    # 12. MIPI CSI-2 物理接口连接
    # ═══════════════════════════════════════════════════════
    connect_bd_intf_net \
        [get_bd_intf_ports mipi_phy_if] \
        [get_bd_intf_pins mipi_csi2_rx_subsystem_0/mipi_phy_if]
    # MIPI video_out (AXI-Stream) → BD 外部端口
    connect_bd_intf_net \
        [get_bd_intf_pins mipi_csi2_rx_subsystem_0/video_out] \
        [get_bd_intf_ports VIDEO_OUT]
    # ═══════════════════════════════════════════════════════
    # 13. AXI 配置总线连接 (axi_sc_cfg)
    # ═══════════════════════════════════════════════════════
    # 上游: PS HPM0_FPD (32-bit Master) → sc_cfg S00
    connect_bd_intf_net \
        [get_bd_intf_pins zynq_ultra_ps_e_0/M_AXI_HPM0_FPD] \
        [get_bd_intf_pins axi_sc_cfg/S00_AXI]
    # 下游 M00: imgproc_top AXI-Lite 配置
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_cfg/M00_AXI] \
        [get_bd_intf_ports M_AXIL_CFG]
    # 下游 M01: AXI IIC
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_cfg/M01_AXI] \
        [get_bd_intf_pins axi_iic_0/S_AXI]
    # 下游 M02: AXI GPIO
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_cfg/M02_AXI] \
        [get_bd_intf_pins axi_gpio_0/S_AXI]
    # 下游 M03: MIPI CSI-2 RX 状态寄存器
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_cfg/M03_AXI] \
        [get_bd_intf_pins mipi_csi2_rx_subsystem_0/csirxss_s_axi]
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_cfg/M04_AXI] \
        [get_bd_intf_pins axi_dma_eth/S_AXI_LITE]
    # ═══════════════════════════════════════════════════════
    # 13b. AXI DMA：S_AXIS（外部 RTL）+ M_AXI_S2MM → HP2
    # ═══════════════════════════════════════════════════════
    connect_bd_intf_net \
        [get_bd_intf_ports ETH_AXIS_S2MM] \
        [get_bd_intf_pins axi_dma_eth/S_AXIS_S2MM]
    connect_bd_intf_net \
        [get_bd_intf_pins axi_dma_eth/M_AXI_S2MM] \
        [get_bd_intf_pins axi_sc_hp2/S00_AXI]
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_hp2/M00_AXI] \
        [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP2_FPD]
    connect_bd_net \
        [get_bd_pins axi_dma_eth/s2mm_introut] \
        [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq1]
    # ═══════════════════════════════════════════════════════
    # 14. AXI HP0 连接 (显示帧缓冲写入)
    # ═══════════════════════════════════════════════════════
    connect_bd_intf_net \
        [get_bd_intf_ports S_AXI_HP0] \
        [get_bd_intf_pins axi_sc_hp0/S00_AXI]
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_hp0/M00_AXI] \
        [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP0_FPD]
    # ═══════════════════════════════════════════════════════
    # 15. AXI HP1 连接 (DDR 乒乓缓冲)
    # ═══════════════════════════════════════════════════════
    connect_bd_intf_net \
        [get_bd_intf_ports S_AXI_HP1] \
        [get_bd_intf_pins axi_sc_hp1/S00_AXI]
    connect_bd_intf_net \
        [get_bd_intf_pins axi_sc_hp1/M00_AXI] \
        [get_bd_intf_pins zynq_ultra_ps_e_0/S_AXI_HP1_FPD]
    # ═══════════════════════════════════════════════════════
    # 16. 帧完成中断 → PS PL_PS_IRQ0
    # ═══════════════════════════════════════════════════════
    connect_bd_net \
        [get_bd_ports frame_done_irq] \
        [get_bd_pins zynq_ultra_ps_e_0/pl_ps_irq0]
    # ═══════════════════════════════════════════════════════
    # 17. OV5640 GPIO 输出连接
    # gpio_io_o[0] = reset_n, gpio_io_o[1] = pwdn
    # ═══════════════════════════════════════════════════════
    # 使用 slice IP 拆分 gpio_io_o 总线
    set slice_rst [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:xlslice:1.0 xlslice_rst]
    set_property -dict [list \
        CONFIG.DIN_WIDTH {2} \
        CONFIG.DIN_FROM  {0} \
        CONFIG.DIN_TO    {0} \
    ] $slice_rst
    set slice_pwdn [create_bd_cell -type ip \
        -vlnv xilinx.com:ip:xlslice:1.0 xlslice_pwdn]
    set_property -dict [list \
        CONFIG.DIN_WIDTH {2} \
        CONFIG.DIN_FROM  {1} \
        CONFIG.DIN_TO    {1} \
    ] $slice_pwdn
    connect_bd_net \
        [get_bd_pins axi_gpio_0/gpio_io_o] \
        [get_bd_pins xlslice_rst/Din]
    connect_bd_net \
        [get_bd_pins axi_gpio_0/gpio_io_o] \
        [get_bd_pins xlslice_pwdn/Din]
    connect_bd_net \
        [get_bd_pins xlslice_rst/Dout] \
        [get_bd_ports ov5640_reset_n]
    connect_bd_net \
        [get_bd_pins xlslice_pwdn/Dout] \
        [get_bd_ports ov5640_pwdn]
    # ═══════════════════════════════════════════════════════
    # 18. IIC tristate 信号连接
    # ═══════════════════════════════════════════════════════
    connect_bd_net \
        [get_bd_pins axi_iic_0/scl_i] \
        [get_bd_ports iic_scl_i]
    connect_bd_net \
        [get_bd_pins axi_iic_0/scl_o] \
        [get_bd_ports iic_scl_o]
    connect_bd_net \
        [get_bd_pins axi_iic_0/scl_t] \
        [get_bd_ports iic_scl_t]
    connect_bd_net \
        [get_bd_pins axi_iic_0/sda_i] \
        [get_bd_ports iic_sda_i]
    connect_bd_net \
        [get_bd_pins axi_iic_0/sda_o] \
        [get_bd_ports iic_sda_o]
    connect_bd_net \
        [get_bd_pins axi_iic_0/sda_t] \
        [get_bd_ports iic_sda_t]
    # ═══════════════════════════════════════════════════════
    # 19. 地址分配
    # ═══════════════════════════════════════════════════════
    # PS M_AXI_HPM0_FPD → imgproc cfg
    assign_bd_address -target_address_space \
        /zynq_ultra_ps_e_0/Data \
        [get_bd_addr_segs M_AXIL_CFG/Reg] \
        -range 4K -offset 0xA0000000
    # PS M_AXI_HPM0_FPD → AXI IIC
    assign_bd_address -target_address_space \
        /zynq_ultra_ps_e_0/Data \
        [get_bd_addr_segs axi_iic_0/S_AXI/Reg] \
        -range 4K -offset 0xA0010000
    # PS M_AXI_HPM0_FPD → AXI GPIO
    assign_bd_address -target_address_space \
        /zynq_ultra_ps_e_0/Data \
        [get_bd_addr_segs axi_gpio_0/S_AXI/Reg] \
        -range 4K -offset 0xA0020000
    # PS M_AXI_HPM0_FPD → MIPI CSI-2 RX ctrl
    assign_bd_address -target_address_space \
        /zynq_ultra_ps_e_0/Data \
        [get_bd_addr_segs mipi_csi2_rx_subsystem_0/csirxss_s_axi/Reg] \
        -range 8K -offset 0xA0030000
    assign_bd_address -target_address_space \
        /zynq_ultra_ps_e_0/Data \
        [get_bd_addr_segs axi_dma_eth/S_AXI_LITE/Reg] \
        -range 64K -offset 0xA0040000
    # HP0 -> S_AXI_HP0 address space -> PS HP0_FPD DDR + OCM
    assign_bd_address -target_address_space /S_AXI_HP0 \
        [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_DDR_LOW] \
        -range 2G -offset 0x00000000
    assign_bd_address -target_address_space /S_AXI_HP0 \
        [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP2/HP0_LPS_OCM] \
        -range 256K -offset 0xFFFC0000
    # HP1 -> S_AXI_HP1 address space -> PS HP1_FPD DDR + OCM
    assign_bd_address -target_address_space /S_AXI_HP1 \
        [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP3/HP1_DDR_LOW] \
        -range 2G -offset 0x00000000
    assign_bd_address -target_address_space /S_AXI_HP1 \
        [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP3/HP1_LPS_OCM] \
        -range 256K -offset 0xFFFC0000
    # AXI DMA S2MM 主机 → PS DDR（SAXIGP4 / HP2）；帧缓冲在 DDR，不必映射 HP2_LPS_OCM
    # （双段映射时工具常会 “Excluding … OCM”，且易与 HP0/HP1 OCM 认知混淆）。
    assign_bd_address -target_address_space [get_bd_addr_spaces axi_dma_eth/Data_S2MM] \
        [get_bd_addr_segs zynq_ultra_ps_e_0/SAXIGP4/HP2_DDR_LOW] \
        -range 2G -offset 0x00000000
    # Associate AXI interface ports to pl_clk: fixes BD41-2559 and BD41-237 FREQ_HZ mismatch
    set_property CONFIG.ASSOCIATED_BUSIF {S_AXI_HP0:S_AXI_HP1:M_AXIL_CFG:VIDEO_OUT:ETH_AXIS_S2MM} $pl_clk_port
    # ═══════════════════════════════════════════════════════
    # 20. 验证 BD
    # ═══════════════════════════════════════════════════════
    validate_bd_design
    save_bd_design
    puts "INFO: Block Design 'zynq_imgproc_bd' created and validated"
}
# 调用创建函数
create_bd_ov5640
