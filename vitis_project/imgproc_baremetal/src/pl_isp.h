#ifndef PL_ISP_H
#define PL_ISP_H

#include "xstatus.h"
#include "xil_types.h"

/* N18 r_dbg[1:0] DDR write source */
#define PL_DBG_SRC_BILAT   0U
#define PL_DBG_SRC_MIPI    1U
#define PL_DBG_SRC_PAT     2U
#define PL_DBG_SRC_PREPROC 3U

int PlIsp_Init(void);
int PlIsp_EnableTestPattern(int enable);
int PlIsp_UseMipiSource(int enable_mipi);
void PlIsp_DumpStatus(void);
u32 PlIsp_ReadDeadPixelCnt(void);
void PlIsp_EthCapture(int enable);
u32 PlIsp_ReadSkidOvf(void);
/* N12: WB / black / wr_page helpers after axil fix */
void PlIsp_SetWbGains(u16 gain_r, u16 gain_g, u16 gain_b);
void PlIsp_SetBlackLevel(u16 black);
/* N24: load gamma 2.2 LUT via CFG 0x1C (r_gamma_wr) — bit has no INIT_FILE */
void PlIsp_LoadGammaLut(void);
u32 PlIsp_ReadWrStatus(u32 *wr_frame, u32 *wr_page);
/* N18: runtime DDR debug source @ CFG 0x28; N25: [4:3]=Bayer phase */
void PlIsp_SetDbgSrc(u32 src);
u32 PlIsp_GetDbgSrc(void);
void PlIsp_SetBayerPhase(u32 ph);
u32 PlIsp_GetBayerPhase(void);
u32 PlIsp_ReadFrameGeom(u16 *width, u16 *height, u32 *locked);
u32 PlIsp_ReadWrLines(void);

#endif /* PL_ISP_H */
