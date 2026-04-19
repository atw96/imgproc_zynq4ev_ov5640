#include "xil_printf.h"
#include "sleep.h"
#include "pl_iic_ov5640.h"
#include "eth_stream.h"

int main(void)
{
	xil_printf("\r\n=== imgproc baremetal: AXI IIC + OV5640 ===\r\n");
	if (PlIic_Init() != XST_SUCCESS) {
		xil_printf("PlIic_Init failed.\r\n");
		return -1;
	}
	if (Ov5640_Probe() != XST_SUCCESS) {
		xil_printf("OV5640 probe failed.\r\n");
		return -1;
	}
	if (Ov5640_InitMinimal() != XST_SUCCESS) {
		xil_printf("Ov5640_InitMinimal failed.\r\n");
		return -1;
	}
	xil_printf("OK: minimal init done.\r\n");
	(void)eth_stream_main();
	return 0;
}
