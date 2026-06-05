# connect 后直接 psu_init，不做 rst -system
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}

set bit [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]
set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
set psu [file join $script_dir zynq_imgproc_platform hw psu_init.tcl]

proc log_step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}
proc jtag_set_name {needle} {
    foreach line [split [string trim [targets]] \n] {
        if {[string match *$needle* $line]} {
            if {[regexp {^\s*(\d+)\s+} $line -> id]} {
                targets -set $id
                return 1
            }
        }
    }
    return 0
}

log_step {=== psu_first ===}
catch {disconnect}
after 2000
connect
configparams force-mem-accesses 1
if {![jtag_set_name "PSU"]} { exit 1 }
source $psu
log_step {psu_init...}
if {[catch {psu_init} err]} { log_step "ERROR: psu_init: $err"; exit 1 }
log_step {psu_init done}
catch {psu_ps_pl_isolation_removal}
catch {psu_ps_pl_reset_config}

if {[jtag_set_name "PL"]} { catch {fpga -file $bit} }
if {![jtag_set_name "Cortex-A53 #0"]} { exit 1 }
catch {stop -timeout 10000}
catch {rst -processor}
after 1000
if {[catch {dow -clear $elf} err]} { log_step "ERROR: dow: $err"; exit 1 }
log_step {dow OK}
con
configparams force-mem-accesses 0
set f [open $ok_flag w]; puts $f ok; close $f
exit 0
