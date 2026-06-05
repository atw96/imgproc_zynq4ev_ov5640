# 已废弃：请用 program_post_vivado.tcl（Vivado Program 后须 psu_init，不能只 dow）
puts "WARN: program_elf_only.tcl 已合并到 program_post_vivado.tcl"
set script_dir [file dirname [file normalize [info script]]]
source [file join $script_dir program_post_vivado.tcl]
