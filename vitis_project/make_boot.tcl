# 生成 SD/QSPI 启动镜像 BOOT.bin（FSBL + PMUFW + bit + app）
set script_dir [file dirname [file normalize [info script]]]
set out_dir [file join $script_dir boot_images]
file mkdir $out_dir

set fsbl [file join $script_dir zynq_imgproc_platform export zynq_imgproc_platform sw zynq_imgproc_platform boot fsbl.elf]
set pmufw [file join $script_dir zynq_imgproc_platform export zynq_imgproc_platform sw zynq_imgproc_platform boot pmufw.elf]
set bit  [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]
set app  [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]

foreach {label path} [list FSBL $fsbl PMUFW $pmufw BIT $bit APP $app] {
    if {![file exists $path]} {
        return -code error "$label 不存在: $path"
    }
}

set bif [file join $out_dir boot.bif]
set fh [open $bif w]
fconfigure $fh -encoding ascii -translation crlf
puts $fh "//arch=zynqmp"
puts $fh "all: \{"
puts $fh "\[bootloader,destination_cpu=a53-0\] $fsbl"
puts $fh "\[pmufw_image\] $pmufw"
puts $fh "\[destination_device=pl\] $bit"
puts $fh "\[destination_cpu=a53-0,exception_level=el-3,trustzone\] $app"
puts $fh "\}"
close $fh
puts "INFO: 写入 $bif"

set bootbin [file join $out_dir BOOT.bin]
puts "INFO: bootgen -arch zynqmp -image $bif -o $bootbin -w"
if {[catch {exec bootgen -arch zynqmp -image $bif -o $bootbin -w} msg]} {
    return -code error "bootgen 失败: $msg"
}
puts $msg
puts "INFO: BOOT.bin -> $bootbin"
