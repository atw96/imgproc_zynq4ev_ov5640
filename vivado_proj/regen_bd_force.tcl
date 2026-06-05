open_project imgproc_axu4evb_ov5640.xpr
set bd [get_files zynq_imgproc_bd.bd]
open_bd_design $bd
reset_target all $bd
generate_target all $bd
puts OK
exit 0
