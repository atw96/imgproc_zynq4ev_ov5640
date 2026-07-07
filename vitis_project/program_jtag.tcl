# XSCT JTAG - psu_init -> fpga -> dow -> con
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}
set bit [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]
set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
set psu [file join $script_dir zynq_imgproc_platform hw psu_init.tcl]
proc step {msg} { puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]; flush stdout }
proc jtag_set_name {needle} {
  foreach line [split [string trim [targets]] \n] {
    if {[string match *$needle* $line]} {
      if {[regexp {^\s*(\d+)\s+} $line -> id]} { targets -set $id; return 1 }
    }
  }
  return 0
}
set ::HW_SERVER_URL "TCP:127.0.0.1:10245"
catch {disconnect}
after 2000
if {[info exists env(XSCT_HW_URL)] && $env(XSCT_HW_URL) ne ""} { connect -url $env(XSCT_HW_URL) } elseif {[info exists ::HW_SERVER_URL]} { connect -url $::HW_SERVER_URL } else { connect }
if {[targets] eq ""} { puts "ERROR: no JTAG targets"; exit 1 }
step "INFO: targets:\n[targets]"
if {[jtag_set_name "Cortex-A53 #0"]} { catch {stop -timeout 15000} }
if {![jtag_set_name "PSU"]} { puts "ERROR: PSU not found"; exit 1 }
catch {mwr -force 0xffff0000 0x14000000}
catch {rst -system}
after 2000
configparams force-mem-accesses 1
source $psu
step "INFO: psu_init..."
if {[catch {psu_init} err]} { puts "ERROR: psu_init: $err"; exit 1 }
step "INFO: psu_init done"
catch {psu_ps_pl_isolation_removal}
catch {psu_ps_pl_reset_config}
configparams force-mem-accesses 0
if {![jtag_set_name "PL"]} { puts "ERROR: PL target not found"; exit 1 }
step "INFO: fpga $bit"
if {[catch {fpga -file $bit} fpga_err]} { puts "ERROR: fpga: $fpga_err"; exit 1 }
step "INFO: fpga OK"
if {![jtag_set_name "Cortex-A53 #0"]} { puts "ERROR: A53 not found"; exit 1 }
catch {stop -timeout 15000}
after 500
catch {rst -processor}
after 2000
configparams force-mem-accesses 1
if {[catch {dow -clear $elf} err]} { puts "ERROR: dow: $err"; exit 1 }
configparams force-mem-accesses 0
step "INFO: dow OK"
con
set f [open $ok_flag w]; puts $f ok; close $f
step "OK program UART0 115200"
exit 0