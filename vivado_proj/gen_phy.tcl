open_project imgproc_axu4evb_ov5640.xpr
set phy [get_files -quiet -all */bd_bf7d_phy_0.xci]
puts "PHY: $phy"
generate_target all $phy
puts OK
exit 0
