# 将 PS DDR 配置对齐 ALINX 工厂工程 / 教程 (AXU4EV)
# 教程: doc/course_s2...pdf 1.2.1 — Load DDR Presets: DDR4_MICRON_MT40A256M16GE_083E
# 参考: doc/factory_vivado/board_test (PSU__ACT_DDR_FREQ_MHZ = 1200)
#
# 用法 (Vivado Tcl Console 或 batch):
#   cd vivado_proj
#   vivado -mode batch -source scripts/apply_alinx_ddr_config.tcl

set repo_root [file normalize [file join [file dirname [info script]] .. ..]]
set proj_dir [file join $repo_root vivado_proj]
set xpr [file join $proj_dir imgproc_axu4evb_ov5640.xpr]

if {![file exists $xpr]} {
    return -code error "找不到工程: $xpr"
}

open_project $xpr
set bd_file [get_files -quiet zynq_imgproc_bd.bd]
if {$bd_file eq ""} {
    return -code error "找不到 zynq_imgproc_bd.bd"
}
open_bd_design $bd_file

set ps [get_bd_cells -quiet zynq_ultra_ps_e_0]
if {$ps eq ""} {
    return -code error "BD 中未找到 zynq_ultra_ps_e_0"
}

puts "INFO: 应用 ALINX DDR4_MICRON_MT40A256M16GE_083E 等效参数..."

# 与 factory_vivado/design_1_zynq_ultra_ps_e_0_1 一致的 DDR/时钟关键项
set_property -dict [list \
    CONFIG.PSU__ACT_DDR_FREQ_MHZ {1199.988037} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__FREQMHZ {1200} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__DIVISOR0 {2} \
    CONFIG.PSU__CRF_APB__DDR_CTRL__SRCSEL {DPLL} \
    CONFIG.PSU__DDRC__SPEED_BIN {DDR4_2400P} \
    CONFIG.PSU__DDRC__DEVICE_CAPACITY {8192 MBits} \
    CONFIG.PSU__DDRC__DRAM_WIDTH {16 Bits} \
    CONFIG.PSU__DDRC__BUS_WIDTH {64 Bit} \
    CONFIG.PSU__DDRC__ROW_ADDR_COUNT {16} \
    CONFIG.PSU__DDRC__COL_ADDR_COUNT {10} \
    CONFIG.PSU__DDRC__BANK_ADDR_COUNT {2} \
    CONFIG.PSU__DDRC__BG_ADDR_COUNT {1} \
    CONFIG.PSU__DDRC__CL {16} \
    CONFIG.PSU__DDRC__CWL {12} \
    CONFIG.PSU__DDRC__DDR4_ADDR_MAPPING {0} \
    CONFIG.PSU__DDRC__SB_TARGET {15-15-15} \
    CONFIG.PSU__DDRC__T_RCD {16} \
    CONFIG.PSU__DDRC__T_RP {16} \
    CONFIG.PSU__DDRC__T_RC {45.32} \
    CONFIG.PSU__DDRC__T_RAS_MIN {32} \
    CONFIG.PSU__DDRC__T_FAW {30.0} \
    CONFIG.PSU__DDRC__TRAIN_DATA_EYE {1} \
    CONFIG.PSU__DDRC__TRAIN_READ_GATE {1} \
    CONFIG.PSU__DDRC__TRAIN_WRITE_LEVEL {1} \
] $ps

if {[catch {validate_bd_design} err]} {
    puts "WARN: validate_bd_design: $err"
}

save_bd_design
puts "INFO: BD 已保存。正在重新生成 PS 的 psu_init..."

# 嵌套 IP 须由父 BD 统一 generate（不可单独 reset 子 xci）
if {[catch {
    generate_target all [get_files zynq_imgproc_bd.bd]
} err]} {
    puts "WARN: generate_target BD: $err"
    puts "HINT: 在 Vivado 中对 zynq_imgproc_bd 右键 Generate Output Products"
}

set psu_out [file join $proj_dir imgproc_axu4evb_ov5640.srcs sources_1 bd zynq_imgproc_bd ip zynq_imgproc_bd_zynq_ultra_ps_e_0_0 psu_init.tcl]
if {[file exists $psu_out]} {
    puts "INFO: 新 psu_init.tcl -> $psu_out"
    puts "INFO: 大小 [file size $psu_out] bytes (工厂参考约 894KB)"
} else {
    puts "WARN: 未找到 $psu_out，请在 Vivado 中对 BD 执行 Generate Output Products"
}

puts "INFO: 完成。请重新 Run Implementation，再执行 vitis_project/deploy.bat sync && deploy.bat program"
