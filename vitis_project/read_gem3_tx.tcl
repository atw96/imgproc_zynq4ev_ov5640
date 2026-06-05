# read_gem3_tx.tcl -- 非侵入式读取 GEM3 TX 统计寄存器（不停止 CPU）
# GEM3 base = 0xFF0E0000, TX Frames OK = offset 0x108

proc step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}

catch {disconnect}
after 500
connect
step "INFO: connected"

# 列出所有可用目标
set tgt_list [targets]
step "INFO: available targets:\n$tgt_list"

# 优先选 APU / PSU，退而选 A53
set selected 0
foreach line [split [string trim $tgt_list] \n] {
    foreach needle {PSU APU "Cortex-A53 #0"} {
        if {[string match *$needle* $line] && !$selected} {
            if {[regexp {^\s*(\d+)\s+} $line -> id]} {
                targets -set $id
                step "INFO: selected target $id ($needle)"
                set selected 1
                break
            }
        }
    }
}
if {!$selected} {
    # 选第一个可用目标
    set firstline [lindex [split [string trim $tgt_list] \n] 0]
    if {[regexp {^\s*(\d+)\s+} $firstline -> id]} {
        targets -set $id
        step "INFO: fallback to first target $id"
    }
}

configparams force-mem-accesses 1

# GEM3 寄存器读取
set GEM3_BASE 0xFF0E0000
set tx_ok   [mrd -value -force [expr {$GEM3_BASE + 0x108}]]
set tx_err  [mrd -value -force [expr {$GEM3_BASE + 0x138}]]
set rx_ok   [mrd -value -force [expr {$GEM3_BASE + 0x158}]]
set net_ctrl [mrd -value -force [expr {$GEM3_BASE + 0x000}]]
set net_cfg  [mrd -value -force [expr {$GEM3_BASE + 0x004}]]
set net_stat [mrd -value -force [expr {$GEM3_BASE + 0x008}]]

configparams force-mem-accesses 0

step "=== GEM3 寄存器 ==="
step "  NET_CTRL  (0x000) = [format 0x%08X $net_ctrl]  (bit3=TX_EN, bit2=RX_EN)"
step "  NET_CFG   (0x004) = [format 0x%08X $net_cfg]   (bit10=100M, bit0=SPEED)"
step "  NET_STAT  (0x008) = [format 0x%08X $net_stat]  (bit2=PHY_MGMT_IDLE)"
step "  TX Frames OK      = $tx_ok"
step "  TX Errors         = $tx_err"
step "  RX Frames OK      = $rx_ok"
step "==="
step "诊断："
if {$tx_ok == 0} {
    step "  ❌ TX=0 → GEM3 没有发出任何帧！检查固件 net_init 是否成功"
} else {
    step "  ✅ TX=$tx_ok → GEM3 确实在发帧，问题在 PC 侧（网线/防火墙）"
}

disconnect
exit 0
