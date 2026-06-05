set proj_dir [file normalize [file join [file dirname [info script]] ..]]
set xpr [file join $proj_dir imgproc_axu4evb_ov5640.xpr]
set tpat [file normalize [file join $proj_dir ../files/sources_1/project/src/test_pat_gen.v]]
open_project $xpr
set_property top imgproc_top_ov5640 [current_fileset]
if {[llength [get_files -quiet $tpat]] == 0} {
  add_files -fileset sources_1 $tpat
}
catch { set_property AUTO_DISABLED false [get_files $tpat] }
catch { set_property USED_IN {synthesis implementation simulation} [get_files $tpat] }
update_compile_order -fileset sources_1
puts "INFO: reset synth_1 + impl_1 ..."
reset_run synth_1
launch_runs synth_1 -jobs 8
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] != "100%"} { return -code error "synth_1 failed" }
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} { return -code error "impl_1 failed" }
set bit [file join $proj_dir imgproc_axu4evb_ov5640.runs impl_1 imgproc_top_ov5640.bit]
puts "INFO: OK bit -> $bit size=[file size $bit]"