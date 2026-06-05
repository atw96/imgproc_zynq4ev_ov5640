open_project imgproc_axu4evb_ov5640.xpr
set mipi [get_files -quiet */zynq_imgproc_bd_mipi_csi2_rx_subsystem_0_0.xci]
puts "MIPI: $mipi"
generate_target all $mipi
puts OK
exit 0
