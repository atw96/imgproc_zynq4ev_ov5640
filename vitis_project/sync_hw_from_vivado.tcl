# 将 Vivado impl 产物同步到 Vitis platform/hw（bit + 可选 xsa）
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file dirname $script_dir]
set vivado_proj [file join $repo_root vivado_proj]
set vitis_hw [file join $script_dir zynq_imgproc_platform hw]

set bit_src [file join $vivado_proj imgproc_axu4evb_ov5640.runs impl_1 imgproc_top_ov5640.bit]
set bit_dst [file join $vitis_hw imgproc_top_ov5640.bit]
set xsa_src [file join $script_dir imgproc_top_ov5640.xsa]
set xsa_dst [file join $vitis_hw imgproc_top_ov5640.xsa]

if {![file exists $bit_src]} {
    return -code error "Vivado bit 不存在: $bit_src\n请先完成 Vivado impl_1。"
}

file mkdir $vitis_hw
file copy -force $bit_src $bit_dst
puts "INFO: bit -> $bit_dst"

# psu_init 必须与 Vivado PS DDR 配置一致（JTAG 下载前须 psu_init）
set psu_candidates [list \
    [file join $vivado_proj imgproc_axu4evb_ov5640.srcs sources_1 bd zynq_imgproc_bd ip zynq_imgproc_bd_zynq_ultra_ps_e_0_0 psu_init.tcl] \
    [file join $vivado_proj imgproc_axu4evb_ov5640.ip_user_files mem_init_files psu_init.tcl] \
]
set psu_dst [file join $vitis_hw psu_init.tcl]
foreach psu_src $psu_candidates {
    if {[file exists $psu_src]} {
        file copy -force $psu_src $psu_dst
        puts "INFO: psu_init.tcl -> $psu_dst"
        break
    }
}
if {![file exists $psu_dst]} {
    puts "WARN: 未找到 psu_init.tcl，JTAG 可能卡在 DDR 初始化"
} else {
    set sz [file size $psu_dst]
    puts "INFO: psu_init.tcl $sz bytes"
    if {$sz < 800000} {
        puts "WARN: psu_init 偏小 (doc/factory_vivado board_test 约 894KB)"
        puts "WARN: 请运行 vivado_proj/regen_psu_init_and_sync.bat 后 deploy.bat sync"
    } else {
        puts "INFO: psu_init 大小正常；若 BD 已 apply_alinx_ddr_config 则 DDR 段应与 factory 一致"
    }
    set ide_psu [file join $script_dir imgproc_baremetal _ide psinit psu_init.tcl]
    file mkdir [file dirname $ide_psu]
    file copy -force $psu_dst $ide_psu
    puts "INFO: ide psu_init -> $ide_psu"
}

if {[file exists $xsa_src]} {
    file copy -force $xsa_src $xsa_dst
    puts "INFO: xsa -> $xsa_dst"
}

# 同步到 app _ide/bitstream（Vitis IDE 调试常用路径）
set ide_bit [file join $script_dir imgproc_baremetal _ide bitstream imgproc_top_ov5640.bit]
file mkdir [file dirname $ide_bit]
file copy -force $bit_dst $ide_bit
puts "INFO: ide bit -> $ide_bit"
