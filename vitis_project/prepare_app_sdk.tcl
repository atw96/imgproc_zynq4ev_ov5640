# 为 imgproc_baremetal Debug 配置创建 _sdk/bsp 目录联接（Windows junction）
set script_dir [file dirname [file normalize [info script]]]
set bsp_src [file join $script_dir zynq_imgproc_platform psu_cortexa53_0 standalone_psu_cortexa53_0 bsp psu_cortexa53_0]
set sdk_bsp [file join $script_dir imgproc_baremetal Debug _sdk bsp]
set link_tgt [file join $sdk_bsp psu_cortexa53_0]

if {![file isdirectory $bsp_src]} {
    return -code error "BSP 目录不存在: $bsp_src\n请先运行 platform generate 或 create_vitis_workspace.tcl"
}

file mkdir [file join $script_dir imgproc_baremetal Debug _sdk]
file mkdir $sdk_bsp

if {[file exists $link_tgt]} {
    puts "INFO: 已存在 $link_tgt"
} else {
    set cmd [format {cmd /c mklink /J "%s" "%s"} $link_tgt $bsp_src]
    puts "INFO: $cmd"
    if {[catch {exec $cmd} msg]} {
        return -code error "创建 junction 失败: $msg"
    }
    puts "INFO: junction 已创建"
}
