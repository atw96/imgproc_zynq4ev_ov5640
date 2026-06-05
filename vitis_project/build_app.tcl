# XSCT — 仅编译已有 workspace 中的 imgproc_baremetal（不重建 platform）
set script_dir [file dirname [file normalize [info script]]]
cd $script_dir
setws $script_dir

puts "INFO: app build imgproc_baremetal"
if {[catch {app build -name imgproc_baremetal} err]} {
    return -code error "app build 失败: $err"
}
puts "INFO: build 完成"
