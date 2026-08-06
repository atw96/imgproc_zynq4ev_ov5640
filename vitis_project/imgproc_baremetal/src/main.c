#include "xil_printf.h"
#include "sleep.h"
#include "platform.h"
#include "pl_iic_ov5640.h"
#include "ov5640_sensor.h"
#include "pl_isp.h"
#include "eth_stream.h"

int main(void)
{
	int cam_ok = 0;

	init_platform();
	xil_printf("\r\n=== imgproc baremetal: OV5640 (ALINX 24_an5641) + ETH ===\r\n");
	xil_printf("[MAIN] step: PlIic_Init...\r\n");
	if (PlIic_Init() != XST_SUCCESS) {
		xil_printf("PlIic_Init failed.\r\n");
		return -1;
	}
	/* AN5641 FPC 接触偶发 NACK：PowerOn+Probe 重试，不改 CAM_GPIO 极性 */
	{
		int attempt;

		for (attempt = 1; attempt <= 3; attempt++) {
			xil_printf("[MAIN] step: Ov5640_PowerOn (try %d/3)...\r\n",
				   attempt);
			if (attempt == 3) {
				if (Ov5640_PowerOn_AltPolarity() != XST_SUCCESS) {
					xil_printf("Ov5640_PowerOn_AltPolarity failed.\r\n");
					return -1;
				}
			} else if (Ov5640_PowerOn() != XST_SUCCESS) {
				xil_printf("Ov5640_PowerOn failed.\r\n");
				return -1;
			}
			sleep(1);
			xil_printf("[MAIN] step: Ov5640_Probe (try %d/3)...\r\n",
				   attempt);
			if (Ov5640_Probe() == XST_SUCCESS) {
				xil_printf("[MAIN] step: Ov5640_SensorInit (1080p)...\r\n");
				if (Ov5640_SensorInit() == XST_SUCCESS)
					cam_ok = 1;
				else
					xil_printf("[MAIN] WARN: SensorInit failed\r\n");
				break;
			}
			xil_printf("[MAIN] WARN: I2C NACK try %d/3\r\n", attempt);
		}
		if (!cam_ok)
			xil_printf("[MAIN] WARN: OV5640 I2C/ID failed after retries\r\n");
	}
	(void)PlIsp_Init();
	PlIsp_DumpStatus();
	if (cam_ok) {
		xil_printf("[MAIN] camera_ok=1 (PL source from RTL ISP_USE_TEST_RAW, no PS 0x08 write)\r\n");
		/* N25b: AEC for real-scene brightness (manual ladder too coarse) */
		(void)Ov5640_SetAutoExposure(1);
	} else {
		xil_printf("[MAIN] camera_ok=0, PL ISP test_raw->clahe (bitstream default)\r\n");
	}
	usleep(500000);
	(void)eth_stream_main();
	return 0;
}
