# Hot reload ELF when PS/DDR already up (skip psu_init/fpga)
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}

set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
if {![file exists $elf]} { puts "ERROR: missing $elf"; exit 1 }

proc log_step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}

catch {disconnect}
after 2000
connect
log_step "targets:\n[targets]"

catch {targets -set -filter {name =~ "Cortex-A53 #0"}}
catch {stop -timeout 15000}
after 500
if {[catch {dow -clear $elf} err]} {
    log_step "ERROR: dow: $err"
    exit 1
}
log_step "dow OK (hot reload)"
con

set f [open $ok_flag w]; puts $f ok; close $f
log_step "OK hot reload UART0 115200"
exit 0
