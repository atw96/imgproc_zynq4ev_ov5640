#
# This file was created by Xilinx Vitis tool.
#


#
# tools
#

RM = rm -f
RMDIR = rm -rf



#
# variables
#

SDCARD_GEN = sdcard_gen
GENERATE_BIF = ::scw::generate_bif

XPFM_PATH = D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/zynq_imgproc_platform/export/zynq_imgproc_platform/zynq_imgproc_platform.xpfm
SYS_CONFIG = zynq_imgproc_platform
DOMAINS = standalone_psu_cortexa53_0
BIF_PATH = D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal_system/Debug/system.bif

BITSTREAM_PATH = D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/_ide/bitstream/imgproc_top_ov5640.bit
SD_FILES = --elf D:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/Debug/imgproc_baremetal.elf,psu_cortexa53_0

#
# primary build targets
#

all: package

package:
	-@echo Generating bif file for the system project
	generate_system_bif.bat 13825 ${XPFM_PATH} ${DOMAINS} ${BIF_PATH}
	${SDCARD_GEN} --xpfm ${XPFM_PATH} --sys_config ${SYS_CONFIG} --bif ${BIF_PATH} --bitstream ${BITSTREAM_PATH} ${SD_FILES}

clean:
	$(RMDIR) ./_sds
	${RMDIR} package
	${RM} system.bif

.PHONY: all package clean


