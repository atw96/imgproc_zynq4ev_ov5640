# fix_dma_length_and_build.tcl
# Fix: axi_dma_eth c_sg_length_width 14->26 (max 64MB per transfer)
# Then re-run synthesis + impl + bitstream

set proj_dir [file normalize [file join [file dirname [info script]] ..]]
set xpr      [file join $proj_dir imgproc_axu4evb_ov5640.xpr]

puts "INFO: opening project $xpr"
open_project $xpr

# --- Modify Block Design --------------------------------------------------
# Use explicit path to the top-level BD (avoid picking up sub-IP BDs)
set bd_file [file join $proj_dir \
    imgproc_axu4evb_ov5640.srcs sources_1 bd zynq_imgproc_bd zynq_imgproc_bd.bd]
if {![file exists $bd_file]} {
    # Fallback: first Block Design file
    set bd_file [lindex [get_files -filter {FILE_TYPE == "Block Designs"}] 0]
}
puts "INFO: opening BD: $bd_file"
open_bd_design $bd_file

set dma [get_bd_cells axi_dma_eth]
if {$dma eq ""} { return -code error "ERROR: axi_dma_eth not found in BD" }

set old_w [get_property CONFIG.c_sg_length_width $dma]
puts "INFO: current c_sg_length_width = $old_w  (max xfer = [expr {(1<<$old_w)-1}] bytes)"

set_property -dict [list CONFIG.c_sg_length_width {26}] $dma
set new_w [get_property CONFIG.c_sg_length_width $dma]
puts "INFO: new     c_sg_length_width = $new_w  (max xfer = [expr {(1<<$new_w)-1}] bytes)"

validate_bd_design -quiet
save_bd_design

# 先强制清除 IP 缓存的 OOC DCP，再重新生成，确保 c_sg_length_width 真正生效
reset_target all [get_files $bd_file]
generate_target all [get_files $bd_file]
export_ip_user_files -of_objects [get_files $bd_file] -no_script -sync -force -quiet
puts "INFO: BD reset + regenerated (OOC DCP cache cleared)"

# --- Rebuild RTL (test_pat_gen.v) ----------------------------------------
set tpat [file normalize [file join $proj_dir ../files/sources_1/project/src/test_pat_gen.v]]
set_property top imgproc_top_ov5640 [current_fileset]
if {[llength [get_files -quiet $tpat]] == 0} {
    add_files -fileset sources_1 $tpat
}
catch { set_property AUTO_DISABLED false [get_files $tpat] }
catch { set_property USED_IN {synthesis implementation simulation} [get_files $tpat] }
update_compile_order -fileset sources_1

# --- Run synthesis + implementation + bitstream ---------------------------
puts "INFO: reset synth_1 + impl_1 ..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
    return -code error "ERROR: synth_1 failed"
}
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    return -code error "ERROR: impl_1 failed"
}

set bit [file join $proj_dir imgproc_axu4evb_ov5640.runs impl_1 imgproc_top_ov5640.bit]
puts "INFO: OK bit -> $bit  size=[file size $bit]"
