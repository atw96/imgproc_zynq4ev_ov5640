/*
 * PL ISP / display config (M_AXIL_CFG @ imgproc_top_ov5640)
 * r_ctrl[8]  legacy ETH test_pat bypass (direct test_pat_gen -> frame_eth_tx)
 * r_ctrl[9]  ISP test RAW source (isp_raw_pat_gen -> preprocessor)
 * r_ctrl[10] ETH from CLAHE output (default via RTL ISP_USE_TEST_RAW/ETH_USE_CLAHE)
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
#define PL_ISP_ST_FIFO_OVF      (PL_ISP_STATUS_BASE + 0x18U)

#define PL_CTRL_RES_1080P       0x00000002U
#define PL_CTRL_TEST_PAT        0x00000100U
#define PL_CTRL_ISP_TEST_RAW    0x00000200U
#define PL_CTRL_ETH_FROM_CLAHE  0x00000400U

static void pl_write_ctrl(u32 ctrl)
{
	/* PS д M_AXIL_CFG+0x08 ������ AXI���� RTL localparam ISP_USE_TEST_RAW/ETH_USE_CLAHE */
	(void)ctrl;
}

int PlIsp_Init(void)
{
	pl_write_ctrl(PL_CTRL_RES_1080P);
	xil_printf("[PL] ISP res=1080p (RTL defaults: test_raw+clahe_eth)\r\n");
	return XST_SUCCESS;
}

int PlIsp_EnableTestPattern(int enable)
{
	xil_printf("[PL] enable legacy eth test_pattern=%d...\r\n", enable ? 1 : 0);
	u32 ctrl = PL_CTRL_RES_1080P;
	if (enable)
		ctrl |= PL_CTRL_TEST_PAT;
	pl_write_ctrl(ctrl);
	return XST_SUCCESS;
}

int PlIsp_UseMipiSource(int enable_mipi)
{
	u32 ctrl = PL_CTRL_RES_1080P | PL_CTRL_ETH_FROM_CLAHE;
	if (!enable_mipi)
		ctrl |= PL_CTRL_ISP_TEST_RAW;
	pl_write_ctrl(ctrl);
	xil_printf("[PL] isp_src=%s eth=clahe\r\n", enable_mipi ? "MIPI" : "test_raw");
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
	u32 fifo_ovf = Xil_In32(base + PL_ISP_ST_FIFO_OVF);
	xil_printf("[PL] st dead=0x%08X eth=0x%08X mipi_beat=%u mipi_pix=%u raw=%u clahe=%u fifo_ovf=%u\r\n",
		   dead, ethb, mbeat, mpix, raw, clahe, fifo_ovf);
}

u32 PlIsp_ReadDeadPixelCnt(void)
{
	return Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_ST_DEAD_CNT);
}
