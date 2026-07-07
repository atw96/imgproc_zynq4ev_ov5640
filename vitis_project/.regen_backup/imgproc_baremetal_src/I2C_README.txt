I2C (AXI IIC) bare-metal for OV5640
Hardware: axi_iic_0 @ 0xA0010000, 400kHz, pins iic_scl_io / iic_sda_io
OV5640: 7-bit addr 0x3C, ID 0x300A/0x300B = 0x56/0x40
Need PL bitstream loaded before AXI IIC works.
Build in Vitis: open workspace vitis_proj, Build project imgproc_baremetal.
