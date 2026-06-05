# =============================================================================
# imgproc_axu4evb_ov5640.xdc
# 目标器件 : xczu4ev-sfvc784-2-i (ALINX AXU4EVB + ACU4EV 核心板)
# 顶层模块  : imgproc_top_ov5640
# 摄像头   : ALINX AV5641 (OV5640, MIPI CSI-2 2-lane)
#
# --- 关于 doc/*.pdf 原理图与“能否从 PDF 自动读出球号” ---
# 本地 PDF 用文本抽取工具可以读到网络名（如 MIPI_CLK_P、CAM_SCL）以及核心板
# 上 PS_MIOxx 与封装球的对应表；但底板原理图里 PL 走线常与符号/标注顺序打乱，
# 抽取文本无法可靠地把“网络名 ↔ PACKAGE_PIN”自动对齐，这不是“网上没有”，而是
# PDF 不适合机器解析引脚表。请务必在 PDF 阅读器里 Ctrl+F 搜索网络名，对照芯片
# 引脚或核心板 Bank65/66 页上的 IO_L*_*_65<球号> 再核对下面 PL 的 PACKAGE_PIN。
#
# 已从 PDF 文本核对（ACU4EV 核心板 MIO 表 + AXU4EVB-P 网络名存在性）的 PS 侧配置
# 写在 create_bd_ov5640.tcl 头部注释；此处为 PL 侧 PACKAGE_PIN。
#
# 下列 PL 球号与同仓库 imgproc_mpsoc_4ev 中 imgproc_zu4ev.xdc（J20 FPC 方案）一致，
# 若你手边原理图修订版与之下不符，以原理图搜索网络名为准修改本文件。
#
# 端口说明:
#   - MIPI: mipi_phy_if_clk_p/n, mipi_phy_if_data_p/n[1:0]
#   - I2C:  iic_scl_io, iic_sda_io (IOBUF 在 RTL)
#   - GPIO: ov5640_reset_n, ov5640_pwdn, ov5640_mclk
# =============================================================================

# =============================================================================
# 1. MIPI CSI-2 差分引脚 (HP Bank 65, VCCIO=1.8V, 与参考 XDC 一致)
# =============================================================================
set_property PACKAGE_PIN  W8    [get_ports mipi_phy_if_clk_p]
set_property PACKAGE_PIN  Y8    [get_ports mipi_phy_if_clk_n]
set_property IOSTANDARD   MIPI_DPHY_DCI [get_ports mipi_phy_if_clk_p]
set_property IOSTANDARD   MIPI_DPHY_DCI [get_ports mipi_phy_if_clk_n]

set_property PACKAGE_PIN  U9    [get_ports {mipi_phy_if_data_p[0]}]
set_property PACKAGE_PIN  V9    [get_ports {mipi_phy_if_data_n[0]}]
set_property IOSTANDARD   MIPI_DPHY_DCI [get_ports {mipi_phy_if_data_p[0]}]
set_property IOSTANDARD   MIPI_DPHY_DCI [get_ports {mipi_phy_if_data_n[0]}]

set_property PACKAGE_PIN  U8    [get_ports {mipi_phy_if_data_p[1]}]
set_property PACKAGE_PIN  V8    [get_ports {mipi_phy_if_data_n[1]}]
set_property IOSTANDARD   MIPI_DPHY_DCI [get_ports {mipi_phy_if_data_p[1]}]
set_property IOSTANDARD   MIPI_DPHY_DCI [get_ports {mipi_phy_if_data_n[1]}]

# 1b. MIPI 时钟说明（SupportLevel=1 架构变更后无需 CLOCK_BUFFER_TYPE 约束）：
#   - MIPI IP 内含 PLL，CLKOUTPHY 路径由 IP 自身 XDC 约束，Vivado 自动保证物理可达。
#   - clk_wiz_mipi_ref 只提供 200 MHz 参考到 dphy_clk_200M（普通 BUFG 路径），合法。
#   - 旧的 set_property CLOCK_BUFFER_TYPE none [get_pins ...] 已删除：
#     该属性在 Vivado 2020.1 中不适用于 pin 对象（Netlist 29-69），故移除。


# =============================================================================
# 2. I2C (PL, LVCMOS33, 与参考 XDC 一致)
# =============================================================================
set_property PACKAGE_PIN  Y9     [get_ports iic_scl_io]
set_property IOSTANDARD   LVCMOS33    [get_ports iic_scl_io]
set_property PULLUP       true        [get_ports iic_scl_io]
set_property PACKAGE_PIN  AA8    [get_ports iic_sda_io]
set_property IOSTANDARD   LVCMOS33    [get_ports iic_sda_io]
set_property PULLUP       true        [get_ports iic_sda_io]


# =============================================================================
# 3. OV5640 控制信号 (LVCMOS33, 与参考 XDC 一致)
# =============================================================================
#set_property PACKAGE_PIN  A20    [get_ports ov5640_reset_n]
#set_property IOSTANDARD   LVCMOS33    [get_ports ov5640_reset_n]
#
# AE10 = CAM_GPIO（官方 mipi.xdc 为 cam_gpio_tri_io[0]，复位/上电控制）
set_property PACKAGE_PIN  AE10   [get_ports ov5640_pwdn]
set_property IOSTANDARD   LVCMOS33    [get_ports ov5640_pwdn]
set_property PULLUP       true        [get_ports ov5640_pwdn]

set_property PACKAGE_PIN  AF10   [get_ports ov5640_mclk]
set_property IOSTANDARD   LVCMOS33    [get_ports ov5640_mclk]


# =============================================================================
# 4. 异步路径约束
# =============================================================================
# GPIO 控制信号为软件异步驱动
#set_false_path -to [get_ports ov5640_reset_n]
set_false_path -to [get_ports ov5640_pwdn]
set_false_path -to [get_ports ov5640_mclk]


# =============================================================================
# 5. 异步时钟组 (须与 timing_summary 中 Clock 名一致)
#    impl_1 曾报: Inter-clock clk_pl_0 <-> clk_out1_zynq_imgproc_bd_clk_wiz_0_0
#    Requirement ~0.017ns — 两钟假对齐所致假违规；CDC 由 fifo_async 完成。
#
#    注: MIPI RXBYTECLKHS 由 MIPI CSI-2 RX Subsystem IP 内部自动创建约束，
#    Vivado 在 IP 层 XDC 中已声明其为 generated clock，无需在此重复引用。
#    若实现后 report_clock_interaction 仍显示 MIPI 相关跨域，可在 Tcl 中执行
#    get_clocks -filter {NAME =~ *RXBYTECLKHS*} 获取实际时钟名后单独添加。
# =============================================================================
# ─────────────────────────────────────────────────────────────────────────────
# 跨时钟域豁免：clk_pl_0 (150 MHz) ↔ clk_out1_zynq_imgproc_bd_clk_wiz_0_0 (148.5 MHz)
#
# 背景：两钟共源于同一 MMCM，Vivado 视为主-生成时钟对，在 t≈660ns 处的最近上升沿间隔
# 仅 0.067ns，导致 50 条跨域假违规。实际 CDC 由 u_display/u_disp_fifo 异步 FIFO 安全处理。
#
# 为何不用 set_clock_groups:
#   Vivado 2020.1 对主时钟与其 MMCM 生成子时钟的 set_clock_groups -asynchronous
#   有已知限制——约束被静默忽略（不报错、不生效）。
#   必须改用 set_false_path，对该时钟对在实现阶段直接生效。
#
# 为何不用 if + llength guard:
#   1) 旧版 XDC 使用 catch，Vivado XDC 不支持 catch（CRITICAL WARNING [Designutils 20-1307]），
#      整段 set_false_path 被跳过，导致 50 条跨域路径全部违例。
#   2) llength 对 Vivado collection 对象兼容性不可靠。
#   3) 本 XDC 已设 PROCESSING_ORDER=LATE，此时 IP 时钟已全部创建，
#      get_clocks 一定能找到目标时钟，无需 guard。
# ─────────────────────────────────────────────────────────────────────────────
set_false_path -from [get_clocks clk_pl_0] \
               -to   [get_clocks clk_out1_zynq_imgproc_bd_clk_wiz_0_0]
set_false_path -from [get_clocks clk_out1_zynq_imgproc_bd_clk_wiz_0_0] \
               -to   [get_clocks clk_pl_0]

set_false_path -from [get_clocks clk_pl_0] \
               -to   [get_clocks clk_hdmi_fwd]
set_false_path -from [get_clocks clk_hdmi_fwd] \
               -to   [get_clocks clk_pl_0]


# =============================================================================
# 6. Floorplan 约束 (适配 ZU4EV 8 个时钟区域)
# =============================================================================
create_pblock pb_pipeline
add_cells_to_pblock [get_pblocks pb_pipeline] \
    [get_cells -hierarchical -filter {NAME =~ "*u_linebuf*" ||
                                      NAME =~ "*u_preproc*"}]
resize_pblock [get_pblocks pb_pipeline] \
    -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y2}

create_pblock pb_filter_disp
add_cells_to_pblock [get_pblocks pb_filter_disp] \
    [get_cells -hierarchical -filter {NAME =~ "*u_bilateral*" ||
                                      NAME =~ "*u_clahe*"     ||
                                      NAME =~ "*u_display*"   ||
                                      NAME =~ "*u_ddr3_buf*"}]
resize_pblock [get_pblocks pb_filter_disp] \
    -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y2}

# HDMI 输出寄存器靠近 Bank66 / clk_wiz BUFGCE，减轻源同步输出 Setup 压力
create_pblock pb_hdmi_out
add_cells_to_pblock [get_pblocks pb_hdmi_out] \
    [get_cells -filter {NAME =~ "hdmi_*_reg*"}]
resize_pblock [get_pblocks pb_hdmi_out] \
    -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y1}


# =============================================================================
# 7. BRAM / DONT_TOUCH
# =============================================================================
set_property RAM_STYLE BLOCK \
    [get_cells -hierarchical -filter {NAME =~ "*u_row_bram*"}]

set_property DONT_TOUCH true \
    [get_cells -hierarchical -filter {NAME =~ "*u_linebuf*"}]
set_property DONT_TOUCH true \
    [get_cells -hierarchical -filter {NAME =~ "*u_detail_enh*"}]
set_property DONT_TOUCH true \
    [get_cells -hierarchical -filter {NAME =~ "*u_bilateral*"}]
set_property DONT_TOUCH true \
    [get_cells -hierarchical -filter {NAME =~ "*u_clahe*"}]
set_property DONT_TOUCH true \
    [get_cells -hierarchical -filter {NAME =~ "*u_preproc*"}]


# =============================================================================
# 8. HDMI 输出 -- ADV7511 并行接口 (Bank 66, LVCMOS33)
#
# 8a. 引脚分配
# =============================================================================
set_property PACKAGE_PIN  F11   [get_ports hdmi_clk]
set_property PACKAGE_PIN  L13   [get_ports hdmi_hsync]
set_property PACKAGE_PIN  A15   [get_ports hdmi_vsync]
set_property PACKAGE_PIN  L14   [get_ports hdmi_de]

# D[23:0] -- R[7:0]=D[23:16], G[7:0]=D[15:8], B[7:0]=D[7:0]
set_property PACKAGE_PIN  B15   [get_ports {hdmi_d[23]}]   ;# R7
set_property PACKAGE_PIN  D15   [get_ports {hdmi_d[22]}]   ;# R6
set_property PACKAGE_PIN  D14   [get_ports {hdmi_d[21]}]   ;# R5
set_property PACKAGE_PIN  G15   [get_ports {hdmi_d[20]}]   ;# R4
set_property PACKAGE_PIN  G14   [get_ports {hdmi_d[19]}]   ;# R3
set_property PACKAGE_PIN  G13   [get_ports {hdmi_d[18]}]   ;# R2
set_property PACKAGE_PIN  F13   [get_ports {hdmi_d[17]}]   ;# R1
set_property PACKAGE_PIN  H14   [get_ports {hdmi_d[16]}]   ;# R0
set_property PACKAGE_PIN  H13   [get_ports {hdmi_d[15]}]   ;# G7
set_property PACKAGE_PIN  J14   [get_ports {hdmi_d[14]}]   ;# G6
set_property PACKAGE_PIN  K14   [get_ports {hdmi_d[13]}]   ;# G5
set_property PACKAGE_PIN  J12   [get_ports {hdmi_d[12]}]   ;# G4
set_property PACKAGE_PIN  H12   [get_ports {hdmi_d[11]}]   ;# G3
set_property PACKAGE_PIN  A12   [get_ports {hdmi_d[10]}]   ;# G2
set_property PACKAGE_PIN  A11   [get_ports {hdmi_d[9]}]    ;# G1
set_property PACKAGE_PIN  F12   [get_ports {hdmi_d[8]}]    ;# G0
set_property PACKAGE_PIN  E13   [get_ports {hdmi_d[7]}]    ;# B7
set_property PACKAGE_PIN  E14   [get_ports {hdmi_d[6]}]    ;# B6
set_property PACKAGE_PIN  A13   [get_ports {hdmi_d[5]}]    ;# B5
set_property PACKAGE_PIN  B13   [get_ports {hdmi_d[4]}]    ;# B4
set_property PACKAGE_PIN  A14   [get_ports {hdmi_d[3]}]    ;# B3
set_property PACKAGE_PIN  B14   [get_ports {hdmi_d[2]}]    ;# B2
set_property PACKAGE_PIN  C13   [get_ports {hdmi_d[1]}]    ;# B1
set_property PACKAGE_PIN  C14   [get_ports {hdmi_d[0]}]    ;# B0

set_property IOSTANDARD LVCMOS33 [get_ports hdmi_clk]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_hsync]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_vsync]
set_property IOSTANDARD LVCMOS33 [get_ports hdmi_de]
set_property IOSTANDARD LVCMOS33 [get_ports {hdmi_d[*]}]

# 降低驱动强度 + 快速翻转，减少 EMI，满足 ADV7511 建立/保持时序
set_property DRIVE  8    [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de}]
set_property SLEW   FAST [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de hdmi_clk}]


# =============================================================================
# 8b. HDMI 视频接口输出时序约束 (源同步 Source-Synchronous)
#
# ADV7511 AC 规格 (Hardware User Guide Rev.D Table 1):
#   tVSU  = 1.0 ns min  (视频数据相对 CLK 上升沿建立时间, @0.9V 测试)
#   tVHLD = 0.7 ns min  (视频数据相对 CLK 上升沿保持时间, @0.9V 测试)
#   注: ADV7511 可通过寄存器 0x15[7:5] 以 400ps 步进在 +-1.2ns 内调整建立/保持
#
# 源同步输出延迟公式:
#   output_delay_max = board_skew_max + tVSU  = 0.3 ns + 1.0 ns = 1.3 ns
#   output_delay_min = board_skew_min - tVHLD = 0.0 ns - 0.7 ns = -0.7 ns
#   (board_skew: 板上 CLK/DATA 偏斜假设 <= 0.3 ns；ADV7511 0x15[7:5] 可微调)
#
# 参考时钟: clk_out1_zynq_imgproc_bd_clk_wiz_0_0 (pclk, 148.5 MHz, T=6.734 ns)
#   有效 Tco 预算 = T - output_delay_max = 6.734 - 1.3 = 5.434 ns
# =============================================================================
# 注意: 不使用 IOB TRUE
# Bank 66 LVCMOS33 的 HDIOLOGIC 输出 FF 最高支持 125 MHz (Min Period = 8 ns)
# pclk = 148.5 MHz 超过此限制，强制 IOB 封装会导致 Pulse Width / Min Period 违例
# 输出寄存器保留在 Fabric FDCE (支持 370 MHz+)，Setup 时序依然充足:
#   FDCE Tco + 走线到 OBUF + OBUF 延迟 < 5.434 ns 预算

# hdmi_clk: assign hdmi_clk = pclk (直接转发像素时钟给 ADV7511 CLK 引脚)
# 声明转发时钟，让 output_delay 以 clk_hdmi_fwd 为参考；
# 数据 OBUF 与时钟 OBUF 同在 Bank66，延迟相近，两者在分析中互相抵消，
# 消除以 MMCM 内部时钟为参考时产生的 ~2.7 ns 虚假 OBUF 延迟。
create_generated_clock \
    -name clk_hdmi_fwd \
    -source [get_pins u_bd/zynq_imgproc_bd_i/clk_wiz_0/inst/clkout1_buf/O] \
    -divide_by 1 \
    [get_ports hdmi_clk]

# output_delay 参考转发时钟 clk_hdmi_fwd（而非 MMCM 内部时钟）
# 分析路径：FDCE → 数据OBUF → 管脚，参考：hdmi_clk OBUF → 管脚
# 两个 OBUF 延迟相互抵消，实际建立裕量约 = T - FDCE_Tco - route - 1.3 ≈ +4.8 ns
set_output_delay \
    -clock clk_hdmi_fwd \
    -max 1.3 \
    [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de}]

set_output_delay \
    -clock clk_hdmi_fwd \
    -min -0.7 \
    [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de}]


# =============================================================================
# 9. 调试输出端口 -- false_path
#    dead_pixel_cnt_out / buf_sel_out 为设计内部状态观测口，无外部时序要求
# =============================================================================
#set_false_path -to [get_ports dead_pixel_cnt_out]
#set_false_path -to [get_ports buf_sel_out]


# =============================================================================
# 10. I2C 双向端口 -- false_path
#     IIC 最高 400 kHz，远低于任何内部时钟，无需高速时序分析
# =============================================================================
set_false_path -to   [get_ports iic_scl_io]
set_false_path -to   [get_ports iic_sda_io]
set_false_path -from [get_ports iic_scl_io]
set_false_path -from [get_ports iic_sda_io]
