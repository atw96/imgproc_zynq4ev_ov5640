# Low-risk JTAG/DAP probe: connect, enumerate targets, read a few PS registers.
# Does not run psu_init, reset, fpga, dow, or con.
set script_dir [file dirname [file normalize [info script]]]

proc log_step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}

proc read_reg {addr} {
    log_step "mrd $addr"
    if {[catch {mrd -force $addr} err]} {
        log_step "ERROR: mrd $addr: $err"
        return 0
    }
    return 1
}

catch {disconnect}
after 1500
connect

set t [targets]
log_step "targets:\n$t"

if {[catch {targets -set -filter {name == "PSU"}} err]} {
    log_step "ERROR: PSU target not found: $err"
    exit 1
}
configparams force-mem-accesses 1

set ok 1
foreach addr {0xFFCA5000 0xFFD80000 0xFD080030 0xFD070004 0xFF5E005C} {
    if {![read_reg $addr]} {
        set ok 0
        break
    }
}
configparams force-mem-accesses 0

if {$ok} {
    log_step {OK DAP probe}
    exit 0
}
exit 1
