# resume_impl_mipi.tcl — continue impl from existing synth (gap fix already in DCP)
set proj_dir [file normalize [file join [file dirname [info script]] ..]]
set xpr      [file join $proj_dir imgproc_axu4evb_ov5640.xpr]

open_project $xpr
set_property top imgproc_top_ov5640 [current_fileset]
set_property generic {ISP_USE_TEST_RAW=0 ETH_USE_CLAHE=0} [current_fileset]
puts "INFO: resume impl with ISP_USE_TEST_RAW=0 ETH_USE_CLAHE=0"

set synth_dcp [file join $proj_dir imgproc_axu4evb_ov5640.runs synth_1 imgproc_top_ov5640.dcp]
if {![file exists $synth_dcp]} {
    return -code error "ERROR: synth DCP missing: $synth_dcp"
}
puts "INFO: using synth DCP $synth_dcp mtime=[file mtime $synth_dcp]"

# Do not reset synth; reset incomplete impl and continue to bitstream
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
    return -code error "ERROR: impl_1 failed (MIPI resume)"
}

set bit_src [file join $proj_dir imgproc_axu4evb_ov5640.runs impl_1 imgproc_top_ov5640.bit]
set bit_dst [file join $proj_dir imgproc_axu4evb_ov5640.runs impl_1 imgproc_top_ov5640_mipi.bit]
file copy -force $bit_src $bit_dst
puts "INFO: OK MIPI bit -> $bit_dst size=[file size $bit_dst]"
