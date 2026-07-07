#ifndef PL_IIC_OV5640_H
#define PL_IIC_OV5640_H

#include "xstatus.h"
#include "xil_types.h"

#ifdef __cplusplus
extern "C" {
#endif

int PlIic_Init(void);
int Ov5640_PowerOn(void);
void Ov5640_I2cBusScan(void);
int Ov5640_WriteReg(u16 reg_addr, u8 data);
int Ov5640_ReadReg(u16 reg_addr, u8 *data);
int Ov5640_Probe(void);

#ifdef __cplusplus
}
#endif

#endif
