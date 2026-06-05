#include "xil_printf.h"
#include "sleep.h"
#include "platform.h"
#include "pl_iic_ov5640.h"
#include "ov5640_sensor.h"
#include "eth_stream.h"

int main(void)
{
	xil_printf("\r\n=== imgproc baremetal: OV5640 (ALINX 24_an5641) + ETH ===\r\n");
	init_platform();
	xil_printf("[MAIN] init_platform done\r\n");
	if (PlIic_Init() != XST_SUCCESS) {
		xil_printf("PlIic_Init failed.\r\n");
		return -1;
	}
	if (Ov5640_PowerOn() != XST_SUCCESS) {
		xil_printf("Ov5640_PowerOn failed.\r\n");
		return -1;
	}
	usleep(500000);
	if (Ov5640_SensorInit() != XST_SUCCESS) {
		xil_printf("Ov5640_SensorInit failed.\r\n");
		return -1;
	}
	xil_printf("OK: OV5640 init done.\r\n");
	(void)eth_stream_main();
	return 0;
}
