# XSCT — 准备 SDK 联接并编译 imgproc_baremetal（Debug）
set script_dir [file dirname [file normalize [info script]]]
cd $script_dir
setws $script_dir

# platform_zynqmp.c (09_ps_net) 需要 BSP 含 ttcps -> xttcps.h
set xttc_pre [file join $script_dir imgproc_baremetal Debug _sdk bsp psu_cortexa53_0 include xttcps.h]
if {![file exists $xttc_pre]} {
    puts "INFO: regenerate BSP ttcps (regen_bsp_ttcps.tcl)"
    if {[catch {source [file join $script_dir regen_bsp_ttcps.tcl]} e1]} {
        return -code error "BSP regen 失败: $e1"
    }
}

# 确保 platform BSP 已生成（sysproj build 会刷新 BSP 库）
puts "INFO: sysproj build imgproc_baremetal_system"
if {[catch {sysproj build -name imgproc_baremetal_system} err]} {
    puts "WARNING: sysproj build: $err"
}

source [file join $script_dir prepare_app_sdk.tcl]

set xttc [file join $script_dir imgproc_baremetal Debug _sdk bsp psu_cortexa53_0 include xttcps.h]
if {![file exists $xttc]} {
    return -code error "BSP 缺少 xttcps.h（platform_zynqmp 需要）。\n请确认 system.mss 已含 psu_ttc_0..3 且 platform generate 成功。\n路径: $xttc"
}
puts "INFO: BSP OK: xttcps.h"

set debug_dir [file join $script_dir imgproc_baremetal Debug]
cd $debug_dir

puts "INFO: make -C $debug_dir"
set make_msg ""
if {[catch {exec cmd /c "make clean all"} make_msg]} {
    puts "WARNING: make 返回非零（常见为 gcc 警告），检查 ELF…"
}
puts $make_msg

set elf [file join $debug_dir imgproc_baremetal.elf]
if {![file exists $elf]} {
    return -code error "未生成 ELF: $elf\n$make_msg"
}
puts "INFO: ELF -> $elf ([file size $elf] bytes)"
