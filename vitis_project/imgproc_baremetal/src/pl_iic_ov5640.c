#include "pl_iic_ov5640.h"

#include "xparameters.h"
#include "xil_printf.h"
#include "sleep.h"
#include "xiic_l.h"
#include "xgpio_l.h"

#ifndef XPAR_AXI_IIC_0_BASEADDR
#error XPAR_AXI_IIC_0_BASEADDR not defined
#endif
#ifndef XPAR_AXI_GPIO_0_BASEADDR
#error XPAR_AXI_GPIO_0_BASEADDR not defined
#endif

#define IIC_BASEADDR ((UINTPTR)XPAR_AXI_IIC_0_BASEADDR)
#define GPIO_BASEADDR ((UINTPTR)XPAR_AXI_GPIO_0_BASEADDR)
#define OV5640_ADDR_7BIT 0x3CU
/* axi_gpio_0: bit0=reset_n(?????), bit1=pwdn->AE10(CAM_GPIO) */
#define OV5640_BIT_RESET_N 0U
#define OV5640_BIT_CAM_GPIO 1U

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

static void ov5640_gpio_write(u32 value)
{
	XGpio_WriteReg(GPIO_BASEADDR, XGPIO_TRI_OFFSET, 0x0U);
	XGpio_WriteReg(GPIO_BASEADDR, XGPIO_DATA_OFFSET, value & 0x3U);
}

int Ov5640_PowerOn(void)
{
	/* bit1=AE10 CAM_GPIO（官方复位脚）；bit0=reset_n 未出封装 */
	const u32 released =
		(1U << OV5640_BIT_RESET_N) | (1U << OV5640_BIT_CAM_GPIO);
	ov5640_gpio_write(1U << OV5640_BIT_RESET_N);
	sleep(1);
	ov5640_gpio_write(released);
	sleep(1);
	xil_printf("OV5640 GPIO: CAM_GPIO reset done (1s low / 1s high) DATA=0x%X\r\n",
		   (unsigned)(XGpio_ReadReg(GPIO_BASEADDR, XGPIO_DATA_OFFSET) & 0x3U));
	return XST_SUCCESS;
}

/* A/B: CAM_GPIO 保持低电平（与官方最终态相反），排查接线/极性 */
int Ov5640_PowerOn_AltPolarity(void)
{
	const u32 held_low = (1U << OV5640_BIT_RESET_N);
	ov5640_gpio_write(held_low | (1U << OV5640_BIT_CAM_GPIO));
	sleep(1);
	ov5640_gpio_write(held_low);
	sleep(2);
	xil_printf("OV5640 GPIO: ALT CAM_GPIO held LOW DATA=0x%X\r\n",
		   (unsigned)(XGpio_ReadReg(GPIO_BASEADDR, XGPIO_DATA_OFFSET) & 0x3U));
	return XST_SUCCESS;
}

static void iic_dump_status(const char *tag)
{
	u32 isr = XIic_ReadReg(IIC_BASEADDR, XIIC_IISR_OFFSET);
	u32 sr = XIic_ReadReg(IIC_BASEADDR, XIIC_SR_REG_OFFSET);
	xil_printf("%s IIC ISR=0x%02X SR=0x%02X (BNB=%u TXerr=%u)\r\n", tag,
		   (unsigned)isr, (unsigned)sr,
		   (unsigned)((isr & XIIC_INTR_BNB_MASK) ? 1U : 0U),
		   (unsigned)((isr & XIIC_INTR_TX_ERROR_MASK) ? 1U : 0U));
}

void Ov5640_I2cBusScan(void)
{
	u8 dummy = 0U;
	u32 addr;
	unsigned sent;
	int found = 0;

	xil_printf("--- I2C bus scan (7-bit addr) ---\r\n");
	if (XIic_WaitBusFree(IIC_BASEADDR) != XST_SUCCESS)
		xil_printf("WARN: bus not free before scan\r\n");
	for (addr = 0x08U; addr <= 0x77U; addr++) {
		XIic_ClearIisr(IIC_BASEADDR, XIIC_INTR_TX_ERROR_MASK);
		sent = XIic_Send(IIC_BASEADDR, addr, &dummy, 1U, XIIC_STOP);
		if (sent == 1U) {
			xil_printf("  ACK at 0x%02X\r\n", (unsigned)addr);
			found++;
		}
		usleep(200);
	}
	if (found == 0)
		xil_printf("  (no device ACK on SCL/SDA)\r\n");
	xil_printf("--- scan done ---\r\n");
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
	if (st != XST_SUCCESS) {
		xil_printf("OV5640 I2C read 0x300A failed (no ACK?)\r\n");
		iic_dump_status("after 0x300A");
		Ov5640_I2cBusScan();
		return st;
	}
	st = Ov5640_ReadReg(0x300BU, &lo);
	if (st != XST_SUCCESS) {
		xil_printf("OV5640 I2C read 0x300B failed\r\n");
		return st;
	}
	xil_printf("OV5640 ID: 0x%02X 0x%02X (expect 0x56 0x40)\r\n", hi, lo);
	if (hi == 0x56U && lo == 0x40U)
		return XST_SUCCESS;
	xil_printf("OV5640 ID mismatch\r\n");
	return XST_FAILURE;
}


