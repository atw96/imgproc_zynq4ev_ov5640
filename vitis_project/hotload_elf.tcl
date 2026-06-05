# hotload_elf.tcl — 板子已在运行时，只重载 ELF，不做 psu_init/fpga
# 适用场景: DDR 已初始化，只需更新固件（如修改目标 IP）
set script_dir [file dirname [file normalize [info script]]]
set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
if {![file exists $elf]} { puts "ERROR: missing $elf"; exit 1 }

proc step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}
proc jtag_set_name {needle} {
    foreach line [split [string trim [targets]] \n] {
        if {[string match *$needle* $line]} {
            if {[regexp {^\s*(\d+)\s+} $line -> id]} {
                targets -set $id; return 1
            }
        }
    }
    return 0
}

set ::HW_SERVER_URL "TCP:127.0.0.1:7000"

catch {disconnect}
after 1000
if {[info exists env(XSCT_HW_URL)] && $env(XSCT_HW_URL) ne ""} {
    connect -url $env(XSCT_HW_URL)
} elseif {[info exists ::HW_SERVER_URL]} {
    connect -url $::HW_SERVER_URL
} else {
    connect
}
step "INFO: targets:\n[targets]"

if {![jtag_set_name "Cortex-A53 #0"]} { puts "ERROR: A53 not found"; exit 1 }
catch {stop -timeout 20000}
after 500
catch {rst -processor}
after 1500
catch {stop -timeout 20000}

# 加载新 ELF（不清除 DDR，直接覆盖代码段）
configparams force-mem-accesses 1
step "INFO: dow (hotload)..."
if {[catch {dow $elf} err]} {
    puts "ERROR: dow: $err"; configparams force-mem-accesses 0; exit 1
}
configparams force-mem-accesses 0
step "INFO: dow OK"
con
step "OK hotload done — UART0 115200"
exit 0
