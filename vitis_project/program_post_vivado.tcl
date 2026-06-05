# Vivado HW Manager 已 Program Device (DONE=HIGH) 后，在 XSCT 执行
# 勿 rst-system；勿重复 fpga
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}

set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
set psu [file join $script_dir zynq_imgproc_platform hw psu_init.tcl]
foreach f [list $elf $psu] {
    if {![file exists $f]} { puts "ERROR: missing $f"; exit 1 }
}

proc log_step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}

log_step {=== post-Vivado: stop A53 -> psu_init -> dow -> con ===}
catch {disconnect}
after 1500
connect
if {[targets] eq ""} { puts "ERROR: no JTAG targets"; exit 1 }

catch {targets -set -filter {name =~ "Cortex-A53 #0"}}
catch {stop -timeout 10000}
log_step {A53 stopped}

catch {targets -set -filter {name == "PSU"}}
configparams force-mem-accesses 1
source $psu
log_step {psu_init... (factory DDR, 约 30s~6min；若上轮卡住请先断电重上电)}
if {[catch {psu_init} err]} {
    log_step "ERROR: psu_init: $err"
    log_step "HINT: 运行 vivado_proj/regen_psu_init_and_sync.bat 对齐 DDR psu_init"
    configparams force-mem-accesses 0
    exit 1
}
log_step {psu_init done}
catch {psu_ps_pl_isolation_removal}
catch {psu_ps_pl_reset_config}
configparams force-mem-accesses 0

catch {targets -set -filter {name =~ "Cortex-A53 #0"}}
catch {rst -processor}
after 500
if {[catch {dow -clear $elf} err]} {
    log_step "ERROR: dow: $err"
    exit 1
}
log_step {dow OK}
con

set f [open $ok_flag w]; puts $f ok; close $f
log_step {OK post-vivado UART0 115200}
exit 0
