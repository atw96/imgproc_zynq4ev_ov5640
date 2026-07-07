#ifndef PL_ISP_H
#define PL_ISP_H

#include "xstatus.h"
#include "xil_types.h"

int PlIsp_Init(void);
int PlIsp_EnableTestPattern(int enable);
int PlIsp_UseMipiSource(int enable_mipi);
void PlIsp_DumpStatus(void);
u32 PlIsp_ReadDeadPixelCnt(void);

#endif /* PL_ISP_H */
