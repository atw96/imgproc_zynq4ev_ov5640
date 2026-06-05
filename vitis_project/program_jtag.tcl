# XSCT JTAG — 单次会话: psu_init -> fpga -> dow -> con（对齐 UG1400 / 2026_5_28）
# 关闭 Vivado Hardware Manager 后再运行
set script_dir [file dirname [file normalize [info script]]]
set ok_flag [file join $script_dir .program_jtag.ok]
catch {file delete -force $ok_flag}

set bit [file join $script_dir zynq_imgproc_platform hw imgproc_top_ov5640.bit]
set elf [file join $script_dir imgproc_baremetal Debug imgproc_baremetal.elf]
set psu [file join $script_dir zynq_imgproc_platform hw psu_init.tcl]
foreach f [list $bit $elf $psu] {
    if {![file exists $f]} { puts "ERROR: missing $f"; exit 1 }
}

proc step {msg} {
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
proc wait_for_target {needle {timeout_sec 25}} {
    set deadline [expr {[clock seconds] + $timeout_sec}]
    while {[clock seconds] < $deadline} {
        if {[jtag_set_name $needle]} { return 1 }
        after 1000
    }
    return 0
}
proc select_psu_context {} {
    foreach name {PSU "PS TAP" APU DAP} {
        if {[wait_for_target $name 5]} {
            step "INFO: psu_init context: $name"
            return 1
        }
    }
    return 0
}

# hw_server 端口（Windows 可能保留 3065-3164，3121 不可用）
set ::HW_SERVER_URL "TCP:127.0.0.1:7000"

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

# 等待 APU/PSU 目标出现（冷启动时常需几秒）
if {![wait_for_target "Cortex-A53 #0" 20]} {
    step "WARN: A53 not yet visible, retry connect..."
    catch {disconnect}
    after 3000
    if {[info exists env(XSCT_HW_URL)] && $env(XSCT_HW_URL) ne ""} {
        connect -url $env(XSCT_HW_URL)
    } elseif {[info exists ::HW_SERVER_URL]} {
        connect -url $::HW_SERVER_URL
    } else {
        connect
    }
    step "INFO: targets after retry:\n[targets]"
}

if {[jtag_set_name "Cortex-A53 #0"]} {
    catch {stop -timeout 15000}
    step "INFO: A53 stopped before psu_init"
}
if {![select_psu_context]} {
    puts "ERROR: PSU/PS TAP not found — 请确认 JTAG 线、板子上电、关闭 Vivado HW Manager"
    exit 1
}
step "INFO: rst -system (PS reset before psu_init)"
catch {mwr -force 0xffff0000 0x14000000}
catch {rst -system}
after 2000
configparams force-mem-accesses 1
source $psu
step "INFO: psu_init..."
if {[catch {psu_init} err]} {
    puts "ERROR: psu_init: $err"
    configparams force-mem-accesses 0
    exit 1
}
step "INFO: psu_init done"
catch {psu_ps_pl_isolation_removal}
catch {psu_ps_pl_reset_config}
configparams force-mem-accesses 0

step "INFO: fpga bitstream"
if {[jtag_set_name "PL"]} {
    if {[catch {fpga -file $bit} err]} {
        step "WARN: fpga: $err"
    } else {
        step "INFO: fpga OK"
    }
} else {
    step "WARN: PL target not found"
}

if {![jtag_set_name "Cortex-A53 #0"]} { puts "ERROR: A53 not found"; exit 1 }
catch {stop -timeout 15000}
after 500
catch {rst -processor}
after 2000
step "INFO: dow..."
configparams force-mem-accesses 1
if {[catch {dow -clear $elf} err]} {
    step "WARN: dow retry: $err"
    catch {stop -timeout 15000}
    catch {rst -processor}
    after 2000
    if {[catch {dow -clear $elf} err2]} {
        puts "ERROR: dow: $err2"
        configparams force-mem-accesses 0
        exit 1
    }
}
configparams force-mem-accesses 0
step "INFO: dow OK"
con

set f [open $ok_flag w]; puts $f ok; close $f
step "OK program UART0 115200"
exit 0
