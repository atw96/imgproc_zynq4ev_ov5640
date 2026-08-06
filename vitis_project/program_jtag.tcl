# Canonical HOT burn sequence (do not reorder):
#   psu_init → fpga → halt A53 (bootloop + clear-registers) → dow → con
# Never halt/rst-processor BEFORE fpga (leaves DONE low / DAP stuck).
# Never re-run psu_init/fpga after a failed dow — re-halt and retry dow only;
# if still sctlr_el3 timeout → cold-boot once, then use this script again.
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}
set bit [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]
set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
set psu [file join $script_dir zynq_imgproc_platform hw psu_init.tcl]

proc step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}
proc jtag_set_name {needle} {
    foreach line [split [string trim [targets]] \n] {
        if {[string match *$needle* $line]} {
            if {[regexp {^\s*(\d+)\s+} $line -> id]} {
                targets -set $id
                step "target $id <= $line"
                return 1
            }
        }
    }
    return 0
}

proc a53_halt_for_dow {} {
    # Hot reload often leaves A53 Running after fpga. Calling stop first can
    # hang DAP (sctlr_el3 timeout). Write bootloop first, then processor reset.
    configparams force-mem-accesses 1
    if {[jtag_set_name "PSU"]} {
        catch {mwr -force 0xffff0000 0x14000000}
        after 100
    }
    if {![jtag_set_name "Cortex-A53 #0"]} {
        configparams force-mem-accesses 0
        return 0
    }
    catch {mwr -force 0xffff0000 0x14000000}
    after 100
    catch {rst -processor -clear-registers}
    after 3000
    catch {stop -timeout 10000}
    after 500
    catch {mwr -force 0xffff0000 0x14000000}
    after 200
    return 1
}

# After cold boot, hw_server sometimes only shows PS TAP/PMU/PL until
# PS TAP rst -system brings PSU up. Do not confuse with "halt before fpga".
proc ensure_psu {ms} {
    if {[jtag_set_name "PSU"]} {
        return 1
    }
    step "WARN: PSU missing; PS TAP rst -system to enumerate"
    if {![jtag_set_name "PS TAP"]} {
        puts "ERROR: PS TAP not found"
        return 0
    }
    catch {rst -system}
    after 5000
    set deadline [expr {[clock milliseconds] + $ms}]
    while {[clock milliseconds] < $deadline} {
        if {[jtag_set_name "PSU"]} {
            return 1
        }
        after 500
    }
    return 0
}

set ::HW_SERVER_URL "TCP:127.0.0.1:12000"
step {=== JTAG HOT: psu_init -> fpga -> halt A53 -> dow ===}
catch {disconnect}
after 2000
if {[info exists env(XSCT_HW_URL)] && $env(XSCT_HW_URL) ne ""} {
    connect -url $env(XSCT_HW_URL)
} elseif {[info exists ::HW_SERVER_URL]} {
    connect -url $::HW_SERVER_URL
} else {
    connect
}
if {[targets] eq ""} { puts "ERROR: no JTAG targets"; exit 1 }
step "INFO: targets:\n[targets]"

# Hot multi-load prefix: A53 still Running OR Suspended (e.g. AXI hang left
# EL3 Suspended) -> rst -system ONCE before psu_init. Not "halt before fpga"
# (rst -processor breaks DONE). Suspended was missing and caused sctlr_el3.
set need_sysrst 0
set a53_state ""
foreach line [split [string trim [targets]] \n] {
    if {[string match "*Cortex-A53 #0*" $line]} {
        if {[string match "*Running*" $line] ||
            [string match "*Suspended*" $line]} {
            set need_sysrst 1
            set a53_state $line
            break
        }
    }
}
if {$need_sysrst} {
    step "INFO: A53 Running/Suspended -> rst -system before psu_init ($a53_state)"
    if {[jtag_set_name "PSU"] || [jtag_set_name "PS TAP"]} {
        catch {mwr -force 0xffff0000 0x14000000}
        catch {rst -system}
        after 3000
    }
}

if {![ensure_psu 15000]} { puts "ERROR: PSU not found"; exit 1 }
configparams force-mem-accesses 1
source $psu
step {INFO: psu_init...}
if {[catch {psu_init} err]} { puts "ERROR: psu_init: $err"; exit 1 }
step {INFO: psu_init done}
catch {psu_ps_pl_isolation_removal}
catch {psu_ps_pl_reset_config}
configparams force-mem-accesses 0

if {![jtag_set_name "PL"]} { puts "ERROR: PL target not found"; exit 1 }
step "INFO: fpga $bit"
if {[catch {fpga -file $bit} fpga_err]} { puts "ERROR: fpga: $fpga_err"; exit 1 }
step {INFO: fpga OK}

if {![a53_halt_for_dow]} { puts "ERROR: A53 not found"; exit 1 }
configparams force-mem-accesses 1
if {[catch {dow -clear $elf} err]} {
    step "WARN: dow retry after re-halt: $err"
    catch {a53_halt_for_dow}
    after 1000
    if {[catch {dow -clear $elf} err2]} {
        puts "ERROR: dow: $err2"
        puts "HINT: DAP stuck -> cold-boot once, then burn_hot again (no pre-fpga halt)"
        exit 1
    }
}
configparams force-mem-accesses 0
step {INFO: dow OK}
con
set f [open $ok_flag w]
puts $f ok
close $f
step {OK program HOT UART0 115200}
exit 0
