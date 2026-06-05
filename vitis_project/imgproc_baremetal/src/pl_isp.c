/*
 * PL ISP / display config (M_AXIL_CFG @ imgproc_top_ov5640)
 * r_ctrl[8]=1: test pattern -> frame_eth_tx (bypass ISP for ETH debug)
 */
#include "pl_isp.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"

#ifndef XPAR_M_AXIL_CFG_BASEADDR
#define XPAR_M_AXIL_CFG_BASEADDR 0xA0000000U
#endif

#define PL_ISP_CTRL_OFF         0x08U
#define PL_ISP_STATUS_BASE      0x200U
#define PL_ISP_ST_DEAD_CNT      (PL_ISP_STATUS_BASE + 0x00U)
#define PL_ISP_ST_ETH_BUF       (PL_ISP_STATUS_BASE + 0x04U)
#define PL_ISP_ST_MIPI_BEAT     (PL_ISP_STATUS_BASE + 0x08U)
#define PL_ISP_ST_MIPI_PIX      (PL_ISP_STATUS_BASE + 0x0CU)
#define PL_ISP_ST_RAW_PIX       (PL_ISP_STATUS_BASE + 0x10U)
#define PL_ISP_ST_CLAHE_PIX     (PL_ISP_STATUS_BASE + 0x14U)

#define PL_CTRL_RES_1080P       0x00000002U
#define PL_CTRL_TEST_PAT        0x00000100U

static void pl_write_ctrl(u32 ctrl)
{
	/* device memory */
	Xil_Out32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_CTRL_OFF, ctrl);
}

int PlIsp_Init(void)
{
	pl_write_ctrl(PL_CTRL_RES_1080P);
	xil_printf("[PL] ISP res=1080p cfg_start=0\r\n");
	return XST_SUCCESS;
}

int PlIsp_EnableTestPattern(int enable)
{
	xil_printf("[PL] enable test_pattern=%d...\r\n", enable ? 1 : 0);
	u32 ctrl = PL_CTRL_RES_1080P;
	if (enable)
		ctrl |= PL_CTRL_TEST_PAT;
	pl_write_ctrl(ctrl);
	xil_printf("[PL] test_pattern=%d (r_ctrl bit8)\r\n", enable ? 1 : 0);
	return XST_SUCCESS;
}

void PlIsp_DumpStatus(void)
{
	UINTPTR base = (UINTPTR)XPAR_M_AXIL_CFG_BASEADDR;
	u32 dead = Xil_In32(base + PL_ISP_ST_DEAD_CNT);
	u32 ethb = Xil_In32(base + PL_ISP_ST_ETH_BUF);
	u32 mbeat = Xil_In32(base + PL_ISP_ST_MIPI_BEAT);
	u32 mpix = Xil_In32(base + PL_ISP_ST_MIPI_PIX);
	u32 raw = Xil_In32(base + PL_ISP_ST_RAW_PIX);
	u32 clahe = Xil_In32(base + PL_ISP_ST_CLAHE_PIX);
	xil_printf("[PL] st dead=0x%08X eth=0x%08X mipi_beat=%u mipi_pix=%u raw=%u clahe=%u\r\n",
		   dead, ethb, mbeat, mpix, raw, clahe);
}

u32 PlIsp_ReadDeadPixelCnt(void)
{
	return Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_ST_DEAD_CNT);
}
