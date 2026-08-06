#ifndef OV5640_SENSOR_H
#define OV5640_SENSOR_H

#include "xil_types.h"
#include "xstatus.h"

struct reginfo {
	u16 reg;
	u8 val;
};

#define SEQUENCE_INIT     0x00
#define SEQUENCE_NORMAL   0x01
#define SEQUENCE_PROPERTY 0xFFFD
#define SEQUENCE_WAIT_MS  0xFFFE
#define SEQUENCE_END      0xFFFF

/* 完整初始化（寄存器表来自 doc/course_s2/24_an5641_mipi_hdmi/.../ov5640.c） */
int Ov5640_SensorInit(void);
/* N18: manual exposure/gain (AEC/AGC off). exposure in lines*16 units; gain Q4.4 */
int Ov5640_SetManualExposure(u32 exposure_lines, u16 gain_q4_4);
int Ov5640_SetAutoExposure(int enable);
/* N22: 0x503D color bar — enable=1 → 0x80 (vertical bars if path OK) */
int Ov5640_SetTestPattern(int enable);
/* N22b: dump/set DVPHO output size (0x3808/09); shear debug */
int Ov5640_DumpTiming(void);
int Ov5640_SetOutputSize(u16 width, u16 height);

#endif
