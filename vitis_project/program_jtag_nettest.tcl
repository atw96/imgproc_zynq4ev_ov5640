# 09_ps_net net_test 对照 — 仅换 ELF，psu_init/bit 与 program_jtag_norst.tcl 相同
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}

set bit [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]
set elf [file join $script_dir net_test_bm Debug net_test_bm.elf]
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
                log_step "target $id <= $line"
                return 1
            }
        }
    }
    return 0
}

set ::HW_SERVER_URL "TCP:127.0.0.1:10245"
log_step {=== JTAG net_test: psu_init + fpga + net_test_bm.elf ===}
catch {disconnect}
after 2000
if {[info exists env(XSCT_HW_URL)] && $env(XSCT_HW_URL) ne ""} {
    connect -url $env(XSCT_HW_URL)
} elseif {[info exists ::HW_SERVER_URL]} {
    connect -url $::HW_SERVER_URL
} else {
    connect
}
if {![jtag_set_name "PSU"]} { exit 1 }
configparams force-mem-accesses 1
source $psu
log_step {psu_init...}
if {[catch {psu_init} err]} { log_step "ERROR: psu_init: $err"; exit 1 }
log_step {psu_init done}
catch {psu_ps_pl_isolation_removal}
catch {psu_ps_pl_reset_config}
configparams force-mem-accesses 0
if {[jtag_set_name "PL"]} { catch {fpga -file $bit} }
if {![jtag_set_name "Cortex-A53 #0"]} { exit 1 }
catch {stop -timeout 20000}
after 500
catch {mwr -force 0xffff0000 0x14000000}
catch {rst -processor}
after 2000
catch {stop -timeout 20000}
after 500
if {[catch {dow -clear $elf} err]} {
    log_step "WARN: dow retry: $err"
    catch {stop -timeout 20000}
    catch {rst -processor}
    after 2000
    if {[catch {dow -clear $elf} err2]} { log_step "ERROR: dow: $err2"; exit 1 }
}
log_step {dow OK}
con
set f [open $ok_flag w]; puts $f ok; close $f
log_step {OK program net_test}
exit 0
