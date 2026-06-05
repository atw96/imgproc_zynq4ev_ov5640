# 在修改 system.mss 加入 ttcps 后，重新生成 standalone_psu_cortexa53_0 BSP
set script_dir [file dirname [file normalize [info script]]]
cd $script_dir
setws $script_dir

set plat_dir [file join $script_dir zynq_imgproc_platform]
set plat_spr [file join $plat_dir platform.spr]
set dom standalone_psu_cortexa53_0

if {![file exists $plat_spr]} {
    return -code error "未找到 platform.spr: $plat_spr"
}

puts "INFO: platform read $plat_spr"
if {[catch {platform read $plat_spr} e1]} {
    return -code error "platform read 失败: $e1"
}

if {[catch {domain active $dom} e3]} {
    return -code error "domain active $dom 失败: $e3"
}

puts "INFO: platform generate"
if {[catch {platform generate} e4]} {
    return -code error "platform generate 失败: $e4"
}

set hdr [file join $plat_dir psu_cortexa53_0 standalone_psu_cortexa53_0 bsp psu_cortexa53_0 include xttcps.h]
if {![file exists $hdr]} {
    return -code error "BSP 仍无 xttcps.h: $hdr"
}
puts "INFO: OK $hdr"
