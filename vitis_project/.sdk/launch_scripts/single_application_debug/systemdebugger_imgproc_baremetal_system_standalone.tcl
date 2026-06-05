connect -url tcp:127.0.0.1:3121
source D:/Xilinx/Vitis/2020.1/scripts/vitis/util/zynqmp_utils.tcl
targets -set -nocase -filter {name =~"APU*"}
rst -system
after 3000
targets -set -filter {jtag_cable_name =~ "Digilent JTAG-HS1 210512180081" && level==0 && jtag_device_ctx=="jsn-JTAG-HS1-210512180081-04721093-0"}
fpga -file D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/_ide/bitstream/imgproc_top_ov5640.bit
targets -set -nocase -filter {name =~"APU*"}
loadhw -hw D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/hw/imgproc_top_ov5640.xsa -mem-ranges [list {0x80000000 0xbfffffff} {0x400000000 0x5ffffffff} {0x1000000000 0x7fffffffff}] -regs
configparams force-mem-access 1
targets -set -nocase -filter {name =~"APU*"}
set mode [expr [mrd -value 0xFF5E0200] & 0xf]
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/sw/zynq_imgproc_platform/boot/fsbl.elf
set bp_35_17_fsbl_bp [bpadd -addr &XFsbl_Exit]
con -block -timeout 60
bpremove $bp_35_17_fsbl_bp
targets -set -nocase -filter {name =~ "*A53*#0"}
rst -processor
dow D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/Debug/imgproc_baremetal.elf
configparams force-mem-access 0
targets -set -nocase -filter {name =~ "*A53*#0"}
con
