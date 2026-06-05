# Vivado batch: program PL bit (ZynqMP also runs PS init in HW flow)
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_bit.ok]
catch {file delete -force $ok_flag}
set proj_dir [file normalize [file join $script_dir .. vivado_proj]]
set bit [file normalize [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]]
if {![file exists $bit]} {
    set bit [file normalize [file join $proj_dir imgproc_axu4evb_ov5640.runs impl_1 imgproc_top_ov5640.bit]]
}
if {![file exists $bit]} {
    puts "ERROR: bit not found"
    exit 1
}
puts "INFO: bit=$bit"

open_hw_manager
connect_hw_server -allow_non_jtag
set tgts [get_hw_targets]
if {[llength $tgts] == 0} {
    puts "ERROR: no hw targets"
    exit 1
}
open_hw_target [lindex $tgts 0]
set devs [get_hw_devices]
if {[llength $devs] == 0} {
    puts "ERROR: no hw devices"
    exit 1
}
set dev [lindex $devs 0]
current_hw_device $dev
refresh_hw_device -update_hw_probes false $dev
set_property PROGRAM.FILE $bit $dev
if {[catch {program_hw_devices $dev} err]} {
    puts "ERROR: program_hw_devices: $err"
    exit 1
}
puts "OK vivado program bit"
set f [open $ok_flag w]; puts $f ok; close $f
close_hw_target
disconnect_hw_server
exit 0
