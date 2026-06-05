from pathlib import Path

# RTL force test_pat
rtl = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/files/sources_1/rtl_top/imgproc_top_ov5640.v")
t = rtl.read_text(encoding="utf-8")
t = t.replace(
    "    wire        test_pat_en    = r_ctrl[8];",
    "    /* Phase1: default test pattern on (no PS M_AXIL write needed) */\n    wire        test_pat_en    = 1'b1;",
)
rtl.write_text(t, encoding="utf-8")
print("rtl ok")

# main.c
main = r'''#include "xil_printf.h"
#include "sleep.h"
#include "pl_iic_ov5640.h"
#include "ov5640_sensor.h"
#include "eth_stream.h"

int main(void)
{
	xil_printf("\r\n=== imgproc baremetal: OV5640 (ALINX 24_an5641) + ETH ===\r\n");
	xil_printf("[MAIN] step: PlIic_Init...\r\n");
	if (PlIic_Init() != XST_SUCCESS) {
		xil_printf("PlIic_Init failed.\r\n");
		return -1;
	}
	xil_printf("[MAIN] step: Ov5640_PowerOn...\r\n");
	if (Ov5640_PowerOn() != XST_SUCCESS) {
		xil_printf("Ov5640_PowerOn failed.\r\n");
		return -1;
	}
	xil_printf("[MAIN] PL test_pat=1 in bitstream, enter eth_stream...\r\n");
	usleep(100000);
	(void)eth_stream_main();
	return 0;
}
'''
Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/src/main.c").write_text(main, encoding="utf-8")
print("main ok")

# eth_stream.c - remove PlIsp block
eth = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/src/eth_stream.c")
e = eth.read_text(encoding="utf-8")
old = """\t/* Phase1: test pattern already enabled in main(); skip MIPI sensor */
\txil_printf("[ETH] step: pl_isp (test_pattern=1, skip MIPI)...\\r\\n");
\tPlIsp_DumpStatus();

\txil_printf("[ETH] step: arm DMA S2MM...\\r\\n");
\tif (dma_arm_transfer() != XST_SUCCESS) {
\t\txil_printf("[ETH] DMA arm failed\\r\\n");
\t\tPlIsp_DumpStatus();
\t\treturn -1;
\t}"""
new = """\t/* Phase1: test_pat_en=1 in bitstream; skip M_AXIL_CFG access */
\txil_printf("[ETH] step: arm DMA S2MM...\\r\\n");
\tif (dma_arm_transfer() != XST_SUCCESS) {
\t\txil_printf("[ETH] DMA arm failed\\r\\n");
\t\treturn -1;
\t}"""
if old in e:
    e = e.replace(old, new)
else:
    e = e.replace("PlIsp_DumpStatus();", "/* PlIsp skipped */")
e = e.replace("PlIsp_DumpStatus();", "/* PlIsp skipped */")
eth.write_text(e, encoding="utf-8")
print("eth ok")
