open_project imgproc_axu4evb_ov5640.xpr
set bd [get_files zynq_imgproc_bd.bd]
puts "BD: $bd"
open_bd_design $bd
validate_bd_design
save_bd_design
generate_target all $bd
puts OK
exit 0
