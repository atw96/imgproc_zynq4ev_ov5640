#include "pl_iic_ov5640.h"

#include "xparameters.h"
#include "xil_printf.h"
#include "sleep.h"
#include "xiic_l.h"

#ifndef XPAR_AXI_IIC_0_BASEADDR
#error XPAR_AXI_IIC_0_BASEADDR not defined
#endif

#define IIC_BASEADDR ((UINTPTR)XPAR_AXI_IIC_0_BASEADDR)
#define OV5640_ADDR_7BIT 0x3CU

int PlIic_Init(void)
{
	XIic_WriteReg(IIC_BASEADDR, XIIC_RESETR_OFFSET, XIIC_RESET_MASK);
	usleep(1000);
	XIic_IntrGlobalDisable(IIC_BASEADDR);
	XIic_ClearIisr(IIC_BASEADDR,
		       XIIC_INTR_TX_ERROR_MASK | XIIC_INTR_RX_FULL_MASK |
			       XIIC_INTR_TX_EMPTY_MASK | XIIC_INTR_BNB_MASK |
			       XIIC_INTR_ARB_LOST_MASK);
	if (XIic_WaitBusFree(IIC_BASEADDR) != XST_SUCCESS) {
		xil_printf("PlIic_Init: bus not free after reset\r\n");
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

int Ov5640_WriteReg(u16 reg_addr, u8 data)
{
	u8 buf[3];
	unsigned sent;
	buf[0] = (u8)(reg_addr >> 8);
	buf[1] = (u8)(reg_addr & 0xFFU);
	buf[2] = data;
	sent = XIic_Send(IIC_BASEADDR, OV5640_ADDR_7BIT, buf, 3U, XIIC_STOP);
	if (sent != 3U)
		return XST_FAILURE;
	return XST_SUCCESS;
}

int Ov5640_ReadReg(u16 reg_addr, u8 *data)
{
	u8 addr[2];
	unsigned n;
	if (data == NULL)
		return XST_FAILURE;
	addr[0] = (u8)(reg_addr >> 8);
	addr[1] = (u8)(reg_addr & 0xFFU);
	n = XIic_Send(IIC_BASEADDR, OV5640_ADDR_7BIT, addr, 2U,
		      XIIC_REPEATED_START);
	if (n != 2U)
		return XST_FAILURE;
	n = XIic_Recv(IIC_BASEADDR, OV5640_ADDR_7BIT, data, 1U, XIIC_STOP);
	if (n != 1U)
		return XST_FAILURE;
	return XST_SUCCESS;
}

int Ov5640_Probe(void)
{
	u8 hi, lo;
	int st;
	st = Ov5640_ReadReg(0x300AU, &hi);
	if (st != XST_SUCCESS)
		return st;
	st = Ov5640_ReadReg(0x300BU, &lo);
	if (st != XST_SUCCESS)
		return st;
	xil_printf("OV5640 ID: 0x%02X 0x%02X (expect 0x56 0x40)\r\n", hi, lo);
	if (hi == 0x56U && lo == 0x40U)
		return XST_SUCCESS;
	return XST_FAILURE;
}

static const struct {
	u16 reg;
	u8 val;
} k_ov5640_minimal[] = {
	{0x3103U, 0x11U},
	{0x3008U, 0x82U},
	{0x3008U, 0x02U},
};

int Ov5640_InitMinimal(void)
{
	u32 i;
	int st;
	for (i = 0U; i < sizeof(k_ov5640_minimal) / sizeof(k_ov5640_minimal[0]);
	     i++) {
		st = Ov5640_WriteReg(k_ov5640_minimal[i].reg,
				     k_ov5640_minimal[i].val);
		if (st != XST_SUCCESS)
			return st;
		usleep(5000);
	}
	return XST_SUCCESS;
}
