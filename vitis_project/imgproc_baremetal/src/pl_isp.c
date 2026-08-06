/*
 * PL ISP / display config (M_AXIL_CFG @ imgproc_top_ov5640)
 * r_ctrl[8]  legacy ETH test_pat bypass
 * r_ctrl[9]  ISP test RAW source
 * r_ctrl[10] ETH from CLAHE
 * r_dbg@0x28 N18 DDR debug mux (safe; do NOT write r_ctrl@0x08)
 *
 * N12: axil_cfg_reg wready gate fixed — CFG writes are safe again.
 */
#include "pl_isp.h"
#include "xparameters.h"
#include "xil_io.h"
#include "xil_printf.h"

#ifndef XPAR_M_AXIL_CFG_BASEADDR
#define XPAR_M_AXIL_CFG_BASEADDR 0xA0000000U
#endif

#define PL_ISP_CTRL_OFF         0x08U
#define PL_ISP_BLACK_OFF        0x0CU
#define PL_ISP_WB_R_OFF         0x10U
#define PL_ISP_WB_G_OFF         0x14U
#define PL_ISP_WB_B_OFF         0x18U
#define PL_ISP_GAMMA_OFF        0x1CU /* cfg_wreg[7] = r_gamma_wr */
#define PL_ISP_ETH_CAP_OFF      0x20U /* cfg_wreg[8] = r_ddr3_base */
#define PL_ISP_DBG_OFF          0x28U /* cfg_wreg[10] = r_dbg N18 */
#define PL_ISP_STATUS_BASE      0x200U
#define PL_ISP_ST_DEAD_CNT      (PL_ISP_STATUS_BASE + 0x00U)
#define PL_ISP_ST_ETH_BUF       (PL_ISP_STATUS_BASE + 0x04U)
#define PL_ISP_ST_MIPI_BEAT     (PL_ISP_STATUS_BASE + 0x08U)
#define PL_ISP_ST_MIPI_PIX      (PL_ISP_STATUS_BASE + 0x0CU)
#define PL_ISP_ST_RAW_PIX       (PL_ISP_STATUS_BASE + 0x10U)
#define PL_ISP_ST_CLAHE_PIX     (PL_ISP_STATUS_BASE + 0x14U)
#define PL_ISP_ST_FIFO_OVF      (PL_ISP_STATUS_BASE + 0x18U)
#define PL_ISP_ST_LINE_PX       (PL_ISP_STATUS_BASE + 0x1CU) /* N16 measured_line_px */
#define PL_ISP_ST_SI_GEOM       (PL_ISP_STATUS_BASE + 0x20U) /* N18 {h,w} */
#define PL_ISP_ST_SI_FLAGS      (PL_ISP_STATUS_BASE + 0x24U) /* N18 locked/bayer/pre_line */
#define PL_ISP_ST_WR_LINES      (PL_ISP_STATUS_BASE + 0x28U) /* N18 wr lines/frame */
#define PL_ISP_ST_CSI_LINE      (PL_ISP_STATUS_BASE + 0x2CU) /* N22 ungated CSI line px */
#define PL_ISP_ST_WR_DROP       (PL_ISP_STATUS_BASE + 0x30U) /* N23 DDR packer drop cnt */

#define PL_CTRL_RES_1080P       0x00000002U
#define PL_CTRL_TEST_PAT        0x00000100U
#define PL_CTRL_ISP_TEST_RAW    0x00000200U
#define PL_CTRL_ETH_FROM_CLAHE  0x00000400U

static u32 s_dbg_src;
static u32 s_bayer_phase; /* N25: r_dbg[4:3] */

static void pl_write32(u32 off, u32 val)
{
	Xil_Out32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + off, val);
}

static void pl_write_ctrl(u32 ctrl)
{
	pl_write32(PL_ISP_CTRL_OFF, ctrl);
}

int PlIsp_Init(void)
{
	/* N12: CFG write path fixed in RTL, but keep init conservative —
	 * source select still comes from Vivado generics. WB uses PlIsp_SetWbGains. */
	PlIsp_EthCapture(0);
	s_dbg_src = 0U;
	/* N25b colorbar sweep winner: phase 3 (BGGR base + row/col XOR) → 8/8 */
	s_bayer_phase = 3U;
	xil_printf("[PL] ISP init (N25b r_dbg@0x28 src+[4:3] bayer default=3)\r\n");
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
	u32 ctrl = PL_CTRL_RES_1080P;
	if (!enable_mipi)
		ctrl |= PL_CTRL_ISP_TEST_RAW;
	pl_write_ctrl(ctrl);
	xil_printf("[PL] isp_src=%s\r\n", enable_mipi ? "MIPI" : "test_raw");
	return XST_SUCCESS;
}

void PlIsp_EthCapture(int enable)
{
	(void)enable;
}

void PlIsp_SetWbGains(u16 gain_r, u16 gain_g, u16 gain_b)
{
	pl_write32(PL_ISP_WB_R_OFF, (u32)gain_r);
	pl_write32(PL_ISP_WB_G_OFF, (u32)gain_g);
	pl_write32(PL_ISP_WB_B_OFF, (u32)gain_b);
	xil_printf("[PL] WB gains R=%u G=%u B=%u (Q10)\r\n",
		   (unsigned)gain_r, (unsigned)gain_g, (unsigned)gain_b);
}

void PlIsp_SetBlackLevel(u16 black)
{
	pl_write32(PL_ISP_BLACK_OFF, (u32)black);
}

/*
 * N24: gamma 2.2 LUT (13-bit out). Bit has no gamma22_13b.mem INIT_FILE, so
 * BRAM starts at 0 and go_*_eff falls back to linear. Write via r_gamma_wr:
 *   [20:13]=addr, [12:0]=data; each CFG write pulses lut_wr_en.
 * Approximate pow(i/255, 1/2.2)*8191 with a fixed piecewise table.
 */
void PlIsp_LoadGammaLut(void)
{
	static const u16 g22[256] = {
		   0,  660,  904, 1087, 1239, 1371, 1490, 1598, 1698, 1791, 1879, 1963, 2042, 2117, 2190, 2260,
		2327, 2392, 2455, 2516, 2575, 2633, 2689, 2744, 2798, 2850, 2902, 2952, 3001, 3049, 3097, 3143,
		3189, 3234, 3278, 3321, 3364, 3406, 3448, 3489, 3529, 3569, 3608, 3647, 3685, 3723, 3761, 3798,
		3834, 3870, 3906, 3941, 3976, 4011, 4045, 4079, 4112, 4146, 4178, 4211, 4243, 4275, 4307, 4338,
		4370, 4401, 4431, 4462, 4492, 4522, 4551, 4581, 4610, 4639, 4668, 4696, 4725, 4753, 4781, 4809,
		4836, 4863, 4891, 4918, 4945, 4971, 4998, 5024, 5050, 5076, 5102, 5128, 5153, 5179, 5204, 5229,
		5254, 5279, 5303, 5328, 5352, 5377, 5401, 5425, 5449, 5472, 5496, 5520, 5543, 5566, 5589, 5612,
		5635, 5658, 5681, 5703, 5726, 5748, 5771, 5793, 5815, 5837, 5859, 5880, 5902, 5924, 5945, 5967,
		5988, 6009, 6030, 6051, 6072, 6093, 6114, 6135, 6155, 6176, 6196, 6217, 6237, 6257, 6277, 6297,
		6317, 6337, 6357, 6377, 6396, 6416, 6436, 6455, 6474, 6494, 6513, 6532, 6551, 6570, 6589, 6608,
		6627, 6646, 6665, 6683, 6702, 6721, 6739, 6757, 6776, 6794, 6812, 6831, 6849, 6867, 6885, 6903,
		6921, 6938, 6956, 6974, 6992, 7009, 7027, 7044, 7062, 7079, 7097, 7114, 7131, 7148, 7166, 7183,
		7200, 7217, 7234, 7251, 7268, 7284, 7301, 7318, 7335, 7351, 7368, 7384, 7401, 7417, 7434, 7450,
		7467, 7483, 7499, 7515, 7531, 7548, 7564, 7580, 7596, 7612, 7628, 7644, 7659, 7675, 7691, 7707,
		7722, 7738, 7754, 7769, 7785, 7800, 7816, 7831, 7847, 7862, 7877, 7892, 7908, 7923, 7938, 7953,
		7968, 7983, 7998, 8013, 8028, 8043, 8058, 8073, 8088, 8103, 8118, 8132, 8147, 8162, 8176, 8191
	};
	u32 i;

	for (i = 0U; i < 256U; i++) {
		u32 v = ((i & 0xFFU) << 13) | ((u32)g22[i] & 0x1FFFU);
		pl_write32(PL_ISP_GAMMA_OFF, v);
	}
	xil_printf("[PL] gamma 2.2 LUT loaded (256 entries, 13-bit)\r\n");
}

void PlIsp_SetDbgSrc(u32 src)
{
	/* [1:0]=ddr src; [2]=force pat; [4:3]=Bayer phase (N25) */
	u32 v = (src & 0x7U) | ((s_bayer_phase & 0x3U) << 3);
	s_dbg_src = src & 0x3U;
	pl_write32(PL_ISP_DBG_OFF, v);
	xil_printf("[PL] r_dbg=0x%X ddr_src=%u bayer=%u "
		   "(0=bilat 1=mipi_raw 2=pat 3=preproc)\r\n",
		   (unsigned)v, (unsigned)s_dbg_src,
		   (unsigned)s_bayer_phase);
}

u32 PlIsp_GetDbgSrc(void)
{
	return s_dbg_src;
}

void PlIsp_SetBayerPhase(u32 ph)
{
	s_bayer_phase = ph & 0x3U;
	/* rewrite r_dbg preserving ddr src (SetDbgSrc prints phase) */
	PlIsp_SetDbgSrc(s_dbg_src);
}

u32 PlIsp_GetBayerPhase(void)
{
	return s_bayer_phase;
}

u32 PlIsp_ReadFrameGeom(u16 *width, u16 *height, u32 *locked)
{
	UINTPTR base = (UINTPTR)XPAR_M_AXIL_CFG_BASEADDR;
	u32 geom = Xil_In32(base + PL_ISP_ST_SI_GEOM);
	u32 flags = Xil_In32(base + PL_ISP_ST_SI_FLAGS);
	if (width)
		*width = (u16)(geom & 0xFFFFU);
	if (height)
		*height = (u16)((geom >> 16) & 0xFFFFU);
	if (locked)
		*locked = (flags >> 31) & 1U;
	return geom;
}

u32 PlIsp_ReadWrLines(void)
{
	return Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_ST_WR_LINES) &
	       0xFFFFU;
}

u32 PlIsp_ReadSkidOvf(void)
{
	u32 ethb = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_ST_ETH_BUF);
	return (ethb >> 16) & 0xFFFFU;
}

u32 PlIsp_ReadDeadPixelCnt(void)
{
	return Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_ST_DEAD_CNT);
}

u32 PlIsp_ReadWrStatus(u32 *wr_frame, u32 *wr_page)
{
	u32 v = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + PL_ISP_ST_CLAHE_PIX);
	if (wr_frame)
		*wr_frame = v & 0xFFFFU;
	if (wr_page)
		*wr_page = (v >> 31) & 1U;
	return v;
}

void PlIsp_DumpStatus(void)
{
	UINTPTR base = (UINTPTR)XPAR_M_AXIL_CFG_BASEADDR;
	u32 dead = Xil_In32(base + PL_ISP_ST_DEAD_CNT);
	u32 ethb = Xil_In32(base + PL_ISP_ST_ETH_BUF);
	u32 mbeat = Xil_In32(base + PL_ISP_ST_MIPI_BEAT);
	u32 mpix = Xil_In32(base + PL_ISP_ST_MIPI_PIX);
	u32 raw = Xil_In32(base + PL_ISP_ST_RAW_PIX);
	u32 wrst = Xil_In32(base + PL_ISP_ST_CLAHE_PIX);
	u32 sofdiag = Xil_In32(base + PL_ISP_ST_FIFO_OVF);
	u32 linepx = Xil_In32(base + PL_ISP_ST_LINE_PX);
	u32 geom = Xil_In32(base + PL_ISP_ST_SI_GEOM);
	u32 flags = Xil_In32(base + PL_ISP_ST_SI_FLAGS);
	u32 wrlines = Xil_In32(base + PL_ISP_ST_WR_LINES);
	u32 csi_ln = Xil_In32(base + PL_ISP_ST_CSI_LINE);
	u32 wr_drop = Xil_In32(base + PL_ISP_ST_WR_DROP);
	u32 cap = Xil_In32(base + PL_ISP_ETH_CAP_OFF);
	u32 dbg = Xil_In32(base + PL_ISP_DBG_OFF);
	xil_printf("[PL] st dead=0x%08X eth_frm=%u skid_ovf=%u mipi_beat=%u mipi_pix=%u "
		   "raw=%u wr_frm=%u wr_page=%u diag=0x%08X line_px=%u cap=0x%08X\r\n",
		   dead, ethb & 0xFFFFU, (ethb >> 16) & 0xFFFFU,
		   mbeat, mpix, raw,
		   wrst & 0xFFFFU, (wrst >> 31) & 1U,
		   sofdiag, linepx & 0xFFFFU, cap);
	xil_printf("[PL] n18 si_w=%u si_h=%u locked=%u bayer=%u pre_line=%u "
		   "wr_lines=%u csi_line=%u wr_drop=%u r_dbg=0x%X\r\n",
		   (unsigned)(geom & 0xFFFFU),
		   (unsigned)((geom >> 16) & 0xFFFFU),
		   (unsigned)((flags >> 31) & 1U),
		   (unsigned)((flags >> 24) & 3U),
		   (unsigned)(flags & 0xFFFFU),
		   (unsigned)(wrlines & 0xFFFFU),
		   (unsigned)(csi_ln & 0xFFFFU),
		   (unsigned)wr_drop,
		   (unsigned)dbg);
}
