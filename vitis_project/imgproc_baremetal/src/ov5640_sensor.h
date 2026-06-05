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

#endif
