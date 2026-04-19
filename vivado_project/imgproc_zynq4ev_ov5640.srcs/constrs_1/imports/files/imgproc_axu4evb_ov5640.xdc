# =============================================================================
# imgproc_axu4evb_ov5640.xdc
# Target device: xczu4ev-sfvc784-2-i (ALINX AXU4EVB + ACU4EV SOM)
# Top module  : imgproc_top_ov5640
# Camera      : ALINX AV5641 (OV5640, MIPI CSI-2 2-lane)
#
# --- doc/*.pdf schematics and "can PDF text extraction recover ball numbers?" ---
# Local PDF text extraction can read net names (e.g. MIPI_CLK_P, CAM_SCL) and the
# PS_MIOxx-to-ball tables on the SOM; carrier schematics often scramble PL routing
# vs symbol order, so extracted text cannot reliably auto-align "net name <-> PACKAGE_PIN".
# This is not "missing on the web" but PDF being a poor machine-readable pin table.
# Always Ctrl+F net names in a PDF viewer, cross-check device pins or SOM Bank65/66
# pages (IO_L*_*_65<ball>) against the PL PACKAGE_PINs below.
#
# PS-side settings already cross-checked from PDF text (ACU4EV SOM MIO table +
# AXU4EVB-P net-name presence) are documented in create_bd_ov5640.tcl header comments;
# this file lists PL PACKAGE_PINs.
#
# The PL ball numbers below match imgproc_zu4ev.xdc in repo imgproc_mpsoc_4ev
# (J20 FPC). If your schematic revision differs, search net names in the schematic
# and edit this file accordingly.
#
# Port summary:
#   - MIPI: mipi_phy_if_clk_p/n, mipi_phy_if_data_p/n[1:0]
#   - I2C:  iic_scl_io, iic_sda_io (IOBUF in RTL)
#   - GPIO: ov5640_reset_n, ov5640_pwdn, ov5640_mclk
# =============================================================================

# =============================================================================
# 1. MIPI CSI-2 differential pins (HP Bank 65, VCCIO=1.8V, same as reference XDC)
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

# 1b. MIPI clock notes (SupportLevel=1: no CLOCK_BUFFER_TYPE constraint needed):
#   - MIPI IP includes PLL; CLKOUTPHY is constrained by the IP XDC; Vivado ensures physical reachability.
#   - clk_wiz_mipi_ref only feeds 200 MHz ref to dphy_clk_200M (plain BUFG path), which is legal.
#   - Legacy set_property CLOCK_BUFFER_TYPE none [get_pins ...] removed:
#     That property is not applicable to pin objects in Vivado 2020.1 (Netlist 29-69), so it was dropped.


# =============================================================================
# 2. I2C (PL, LVCMOS33, same as reference XDC)
# =============================================================================
set_property PACKAGE_PIN  Y9     [get_ports iic_scl_io]
set_property IOSTANDARD   LVCMOS33    [get_ports iic_scl_io]
set_property PACKAGE_PIN  AA8    [get_ports iic_sda_io]
set_property IOSTANDARD   LVCMOS33    [get_ports iic_sda_io]


# =============================================================================
# 3. OV5640 control signals (LVCMOS33, same as reference XDC)
# =============================================================================
#set_property PACKAGE_PIN  A20    [get_ports ov5640_reset_n]
#set_property IOSTANDARD   LVCMOS33    [get_ports ov5640_reset_n]
#
set_property PACKAGE_PIN  AE10   [get_ports ov5640_pwdn]
set_property IOSTANDARD   LVCMOS33    [get_ports ov5640_pwdn]

set_property PACKAGE_PIN  AF10   [get_ports ov5640_mclk]
set_property IOSTANDARD   LVCMOS33    [get_ports ov5640_mclk]


# =============================================================================
# 4. Asynchronous path constraints
# =============================================================================
# GPIO control driven asynchronously by software
#set_false_path -to [get_ports ov5640_reset_n]
set_false_path -to [get_ports ov5640_pwdn]
set_false_path -to [get_ports ov5640_mclk]


# =============================================================================
# 5. Asynchronous clock domains (names must match timing_summary Clock names)
#    impl_1 reported: Inter-clock clk_pl_0 <-> clk_out1_zynq_imgproc_bd_clk_wiz_0_0
#    Requirement ~0.017ns — false violation from false clock alignment; CDC handled by fifo_async.
#
#    Note: MIPI RXBYTECLKHS constraints are auto-created inside MIPI CSI-2 RX Subsystem IP;
#    Vivado declares it as generated clock in the IP XDC; no need to repeat here.
#    If report_clock_interaction still shows MIPI-related crossings after implementation, run
#    get_clocks -filter {NAME =~ *RXBYTECLKHS*} in Tcl to get the real clock name and add constraints.
# =============================================================================
# ─────────────────────────────────────────────────────────────────────────────
# CDC exception: clk_pl_0 (150 MHz) <-> clk_out1_zynq_imgproc_bd_clk_wiz_0_0 (148.5 MHz)
#
# Background: both from same MMCM; Vivado treats them as primary/generated pair; nearest rising
# edges at t~660ns are only 0.067ns apart, causing ~50 false CDC violations. Real CDC is safe in
# u_display/u_disp_fifo async FIFOs.
#
# Why not set_clock_groups:
#   Vivado 2020.1 has a known limitation: set_clock_groups -asynchronous between a primary clock
#   and its MMCM-generated child is silently ignored (no error, no effect).
#   Use set_false_path on the pair so it takes effect in implementation.
#
# Why not if + llength guard:
#   1) Old XDC used catch; Vivado XDC does not support catch (CRITICAL WARNING [Designutils 20-1307]),
#      so the whole set_false_path block was skipped and all ~50 CDC paths failed.
#   2) llength on Vivado collection objects is unreliable.
#   3) This XDC sets PROCESSING_ORDER=LATE; by then IP clocks exist, get_clocks finds targets — no guard needed.
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
# 6. Floorplan constraints (fits ZU4EV 8 clock regions)
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

# Place HDMI output registers near Bank66 / clk_wiz BUFGCE to ease source-synchronous setup
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
# 8. HDMI output -- ADV7511 parallel interface (Bank 66, LVCMOS33)
#
# 8a. Pin assignment
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

# Lower drive strength + fast slew to reduce EMI and meet ADV7511 setup/hold
set_property DRIVE  8    [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de}]
set_property SLEW   FAST [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de hdmi_clk}]


# =============================================================================
# 8b. HDMI video output timing (source-synchronous)
#
# ADV7511 AC specs (Hardware User Guide Rev.D Table 1):
#   tVSU  = 1.0 ns min  (video data setup to CLK rising edge, @0.9V test)
#   tVHLD = 0.7 ns min  (video data hold to CLK rising edge, @0.9V test)
#   Note: ADV7511 register 0x15[7:5] can trim setup/hold in +-1.2ns steps of 400ps
#
# Source-synchronous output delay:
#   output_delay_max = board_skew_max + tVSU  = 0.3 ns + 1.0 ns = 1.3 ns
#   output_delay_min = board_skew_min - tVHLD = 0.0 ns - 0.7 ns = -0.7 ns
#   (board_skew: assume <=0.3 ns CLK/DATA skew on PCB; 0x15[7:5] can fine-tune)
#
# Reference clock: clk_out1_zynq_imgproc_bd_clk_wiz_0_0 (pclk, 148.5 MHz, T=6.734 ns)
#   Effective Tco budget = T - output_delay_max = 6.734 - 1.3 = 5.434 ns
# =============================================================================
# Note: do not use IOB TRUE
# Bank 66 LVCMOS33 HDIOLOGIC output FFs max 125 MHz (Min Period = 8 ns)
# pclk = 148.5 MHz exceeds this; forcing IOB packing causes pulse width / min period violations
# Keep output registers in fabric FDCE (370 MHz+); setup margin remains adequate:
#   FDCE Tco + route to OBUF + OBUF delay < 5.434 ns budget

# hdmi_clk: assign hdmi_clk = pclk (forward pixel clock to ADV7511 CLK pin)
# Declare forwarded clock so output_delay uses clk_hdmi_fwd as reference;
# data OBUF and clock OBUF are both in Bank66 with similar delay, largely cancelling in analysis
# and removing ~2.7 ns false OBUF delay when referenced to internal MMCM clock.
create_generated_clock \
    -name clk_hdmi_fwd \
    -source [get_pins u_bd/zynq_imgproc_bd_i/clk_wiz_0/inst/clkout1_buf/O] \
    -divide_by 1 \
    [get_ports hdmi_clk]

# output_delay vs forwarded clk_hdmi_fwd (not internal MMCM clock)
# Analyzed: FDCE -> data OBUF -> pad, ref: hdmi_clk OBUF -> pad
# OBUF delays largely cancel; setup slack ~ T - FDCE_Tco - route - 1.3 ~ +4.8 ns
set_output_delay \
    -clock clk_hdmi_fwd \
    -max 1.3 \
    [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de}]

set_output_delay \
    -clock clk_hdmi_fwd \
    -min -0.7 \
    [get_ports {hdmi_d[*] hdmi_hsync hdmi_vsync hdmi_de}]


# =============================================================================
# 9. Debug output ports -- false_path
#    dead_pixel_cnt_out / buf_sel_out are internal status taps with no external timing
# =============================================================================
#set_false_path -to [get_ports dead_pixel_cnt_out]
#set_false_path -to [get_ports buf_sel_out]


# =============================================================================
# 10. I2C bidirectional ports -- false_path
#     I2C max 400 kHz, far below any internal clock; no high-speed timing needed
# =============================================================================
set_false_path -to   [get_ports iic_scl_io]
set_false_path -to   [get_ports iic_sda_io]
set_false_path -from [get_ports iic_scl_io]
set_false_path -from [get_ports iic_sda_io]
