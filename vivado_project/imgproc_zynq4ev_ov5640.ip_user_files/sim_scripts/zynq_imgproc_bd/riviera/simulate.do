onbreak {quit -force}
onerror {quit -force}

asim +access +r +m+zynq_imgproc_bd -L xilinx_vip -L axi_infrastructure_v1_1_0 -L axi_vip_v1_1_7 -L zynq_ultra_ps_e_vip_v1_0_7 -L xil_defaultlib -L lib_cdc_v1_0_2 -L proc_sys_reset_v5_0_13 -L generic_baseblocks_v2_1_0 -L axi_register_slice_v2_1_21 -L fifo_generator_v13_2_5 -L axi_data_fifo_v2_1_20 -L axi_crossbar_v2_1_22 -L mipi_csi2_rx_ctrl_v1_0_8 -L high_speed_selectio_wiz_v3_6_0 -L mipi_dphy_v4_2_0 -L axis_infrastructure_v1_1_0 -L axis_register_slice_v1_1_21 -L axis_dwidth_converter_v1_1_20 -L vfb_v1_0_15 -L lib_pkg_v1_0_2 -L axi_lite_ipif_v3_0_4 -L interrupt_control_v3_1_4 -L axi_iic_v2_0_24 -L axi_gpio_v2_0_23 -L xlconstant_v1_1_7 -L smartconnect_v1_0 -L lib_fifo_v1_0_14 -L lib_srl_fifo_v1_0_2 -L axi_datamover_v5_1_23 -L axi_sg_v4_1_13 -L axi_dma_v7_1_22 -L xlslice_v1_0_2 -L xilinx_vip -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.zynq_imgproc_bd xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {zynq_imgproc_bd.udo}

run -all

endsim

quit -force
