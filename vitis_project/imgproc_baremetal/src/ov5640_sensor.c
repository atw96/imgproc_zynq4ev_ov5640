/*
 * 源自 doc/course_s2/24_an5641_mipi_hdmi/.../ov5640.c
 * I2C 底层：本工程 PL axi_iic_0（pl_iic_ov5640.c），非官方 PS XIicPs
 */
#include "ov5640_sensor.h"
#include "ov5640_config.h"
#include "pl_iic_ov5640.h"
#include "sleep.h"
#include "xil_printf.h"
#include "xstatus.h"

struct reginfo sensor_init_data[] =
{	
		//[7]=0 Software reset; [6]=1 Software power down; Default=0x02
		{0x3008, 0x42},
		//[1]=1 System input clock from PLL; Default read = 0x11
		{0x3103, 0x03},
		//[3:0]=0000 MD2P,MD2N,MCP,MCN input; Default=0x00
		{0x3017, 0x00},
		//[7:2]=000000 MD1P,MD1N, D3:0 input; Default=0x00
		{0x3018, 0x00},
		//[6:4]=001 PLL charge pump, [3:0]=1000 MIPI 8-bit mode
		{0x3034, 0x18},
		//PLL1 configuration
		//[7:4]=0001 System clock divider /1, [3:0]=0001 Scale divider for MIPI /1
		{0x3035, 0x11},
		//[7:0]=56 PLL multiplier
		{0x3036, 0x38},
		//[4]=1 PLL root divider /2, [3:0]=1 PLL pre-divider /1
		{0x3037, 0x11},
		//[5:4]=00 PCLK root divider /1, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
		{0x3108, 0x01},
		//PLL2 configuration
		//[5:4]=01 PRE_DIV_SP /1.5, [2]=1 R_DIV_SP /1, [1:0]=00 DIV12_SP /1
		{0x303D, 0x10},
		//[4:0]=11001 PLL2 multiplier DIV_CNT5B = 25
		{0x303B, 0x19},

		{0x3630, 0x2e},
		{0x3631, 0x0e},
		{0x3632, 0xe2},
		{0x3633, 0x23},
		{0x3621, 0xe0},
		{0x3704, 0xa0},
		{0x3703, 0x5a},
		{0x3715, 0x78},
		{0x3717, 0x01},
		{0x370b, 0x60},
		{0x3705, 0x1a},
		{0x3905, 0x02},
		{0x3906, 0x10},
		{0x3901, 0x0a},
		{0x3731, 0x02},
		//VCM debug mode
		{0x3600, 0x37},
		{0x3601, 0x33},
		//System control register changing not recommended
		{0x302d, 0x60},
		//??
		{0x3620, 0x52},
		{0x371b, 0x20},
		//?? DVP
		{0x471c, 0x50},

		{0x3a13, 0x43},
		{0x3a18, 0x00},
		{0x3a19, 0xf8},
		{0x3635, 0x13},
		{0x3636, 0x06},
		{0x3634, 0x44},
		{0x3622, 0x01},
		{0x3c01, 0x34},
		{0x3c04, 0x28},
		{0x3c05, 0x98},
		{0x3c06, 0x00},
		{0x3c07, 0x08},
		{0x3c08, 0x00},
		{0x3c09, 0x1c},
		{0x3c0a, 0x9c},
		{0x3c0b, 0x40},

		//[7]=1 color bar enable, [3:2]=00 eight color bar
		{0x503d, 0x00},
		//[2]=1 ISP vflip, [1]=1 sensor vflip
		{0x3820, 0x46},

		//[7:5]=001 Two lane mode, [4]=0 MIPI HS TX no power down, [3]=0 MIPI LP RX no power down, [2]=1 MIPI enable, [1:0]=10 Debug mode; Default=0x58
		{0x300e, 0x45},
		//[5]=0 Clock free running, [4]=1 Send line short packet, [3]=0 Use lane1 as default, [2]=1 MIPI bus LP11 when no packet; Default=0x04
		{0x4800, 0x14},
		{0x302e, 0x08},
		//[7:4]=0x3 YUV422, [3:0]=0x0 YUYV
		//{0x4300, 0x30},
		//[7:4]=0x6 RGB565, [3:0]=0x0 {b[4:0],g[5:3],g[2:0],r[4:0]}
		{0x4300, 0x6f},
		{0x501f, 0x01},

		{0x4713, 0x03},
		{0x4407, 0x04},
		{0x440e, 0x00},
		{0x460b, 0x35},
		//[1]=0 DVP PCLK divider manual control by 0x3824[4:0]
		{0x460c, 0x20},
		//[4:0]=1 SCALE_DIV=INT(3824[4:0]/2)
		{0x3824, 0x01},
		//[7]=1 LENC correction enabled, [5]=1 RAW gamma enabled, [2]=1 Black pixel cancellation enabled, [1]=1 White pixel cancellation enabled, [0]=1 Color interpolation enabled
		{0x5000, 0x07},
		//[7]=0 Special digital effects, [5]=0 scaling, [2]=0 UV average disabled, [1]=1 Color matrix enabled, [0]=1 Auto white balance enabled
		{0x5001, 0x03},

		{SEQUENCE_END, 0x00}
};


struct reginfo cfg_702p_60fps[] =
{
		//1280 x 720 binned, RAW10, MIPISCLK=280M, SCLK=56Mz, PCLK=56M
		//PLL1 configuration
		//[7:4]=0010 System clock divider /2, [3:0]=0001 Scale divider for MIPI /1
		{0x3035, 0x21},
		//[7:0]=70 PLL multiplier
		{0x3036, 0x46},
		//[4]=0 PLL root divider /1, [3:0]=5 PLL pre-divider /1.5
		{0x3037, 0x05},
		//[5:4]=01 PCLK root divider /2, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
		{0x3108, 0x11},

		//[6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
		{0x3034, 0x1A},

		//[3:0]=0 X address start high byte
		{0x3800, (0 >> 8) & 0x0F},
		//[7:0]=0 X address start low byte
		{0x3801, 0 & 0xFF},
		//[2:0]=0 Y address start high byte
		{0x3802, (8 >> 8) & 0x07},
		//[7:0]=0 Y address start low byte
		{0x3803, 8 & 0xFF},

		//[3:0] X address end high byte
		{0x3804, (2619 >> 8) & 0x0F},
		//[7:0] X address end low byte
		{0x3805, 2619 & 0xFF},
		//[2:0] Y address end high byte
		{0x3806, (1947 >> 8) & 0x07},
		//[7:0] Y address end low byte
		{0x3807, 1947 & 0xFF},

		//[3:0]=0 timing hoffset high byte
		{0x3810, (0 >> 8) & 0x0F},
		//[7:0]=0 timing hoffset low byte
		{0x3811, 0 & 0xFF},
		//[2:0]=0 timing voffset high byte
		{0x3812, (0 >> 8) & 0x07},
		//[7:0]=0 timing voffset low byte
		{0x3813, 0 & 0xFF},

		//[3:0] Output horizontal width high byte
		{0x3808, (1280 >> 8) & 0x0F},
		//[7:0] Output horizontal width low byte
		{0x3809, 1280 & 0xFF},
		//[2:0] Output vertical height high byte
		{0x380a, (720 >> 8) & 0x7F},
		//[7:0] Output vertical height low byte
		{0x380b, 720 & 0xFF},

		//HTS line exposure time in # of pixels
		{0x380c, (1896 >> 8) & 0x1F},
		{0x380d, 1896 & 0xFF},
		//VTS frame exposure time in # lines
		{0x380e, (984 >> 8) & 0xFF},
		{0x380f, 984 & 0xFF},

		//[7:4]=0x3 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
		{0x3814, 0x31},
		//[7:4]=0x3 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
		{0x3815, 0x31},

		//[2]=0 ISP mirror, [1]=0 sensor mirror, [0]=1 horizontal binning
		{0x3821, 0x01},

		//little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
		{0x4837, 36}, // 1/56M*2

		//Undocumented anti-green settings
		{0x3618, 0x00}, // Removes vertical lines appearing under bright light
		{0x3612, 0x59},
		{0x3708, 0x64},
		{0x3709, 0x52},
		{0x370c, 0x03},

		//[7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
		{0x4300, 0x00},
		//[2:0]=0x3 Format select ISP RAW (DPC)
		{0x501f, 0x03},
		{SEQUENCE_END, 0x00}
};



struct reginfo cfg_1080p_30fps[] =
{//1920 x 1080 @ 30fps, RAW10, MIPISCLK=420, SCLK=84MHz, PCLK=84M
		//PLL1 configuration
		//[7:4]=0010 System clock divider /2, [3:0]=0001 Scale divider for MIPI /1
		{0x3035, 0x21}, // 30fps setting
		//[7:0]=105 PLL multiplier
		{0x3036, 0x69},
		//[4]=0 PLL root divider /1, [3:0]=5 PLL pre-divider /1.5
		{0x3037, 0x05},
		//[5:4]=01 PCLK root divider /2, [3:2]=00 SCLK2x root divider /1, [1:0]=01 SCLK root divider /2
		{0x3108, 0x11},

		//[6:4]=001 PLL charge pump, [3:0]=1010 MIPI 10-bit mode
		{0x3034, 0x1A},

		/* N12 S3: Bayer phase via BAYER_X_OFF / BAYER_Y_OFF */
		{0x3800, ((336 + BAYER_X_OFF) >> 8) & 0x0F},
		{0x3801, (336 + BAYER_X_OFF) & 0xFF},
		{0x3802, ((426 + BAYER_Y_OFF) >> 8) & 0x07},
		{0x3803, (426 + BAYER_Y_OFF) & 0xFF},

		{0x3804, ((2287 + BAYER_X_OFF) >> 8) & 0x0F},
		{0x3805, (2287 + BAYER_X_OFF) & 0xFF},
		{0x3806, ((1529 + BAYER_Y_OFF) >> 8) & 0x07},
		{0x3807, (1529 + BAYER_Y_OFF) & 0xFF},

		//[3:0]=0 timing hoffset high byte
		{0x3810, (16 >> 8) & 0x0F},
		//[7:0]=0 timing hoffset low byte
		{0x3811, 16 & 0xFF},
		//[2:0]=0 timing voffset high byte
		{0x3812, (12 >> 8) & 0x07},
		//[7:0]=0 timing voffset low byte
		{0x3813, 12 & 0xFF},

		//[3:0] Output horizontal width high byte
		{0x3808, (1920 >> 8) & 0x0F},
		//[7:0] Output horizontal width low byte
		{0x3809, 1920 & 0xFF},
		//[2:0] Output vertical height high byte
		{0x380a, (1080 >> 8) & 0x7F},
		//[7:0] Output vertical height low byte
		{0x380b, 1080 & 0xFF},

		//HTS line exposure time in # of pixels Tline=HTS/sclk
		{0x380c, (2500 >> 8) & 0x1F},
		{0x380d, 2500 & 0xFF},
		//VTS frame exposure time in # lines
		{0x380e, (1120 >> 8) & 0xFF},
		{0x380f, 1120 & 0xFF},

		//[7:4]=0x1 horizontal odd subsample increment, [3:0]=0x1 horizontal even subsample increment
		{0x3814, 0x11},
		//[7:4]=0x1 vertical odd subsample increment, [3:0]=0x1 vertical even subsample increment
		{0x3815, 0x11},

		//[2]=0 ISP mirror, [1]=0 sensor mirror, [0]=0 no horizontal binning
		{0x3821, 0x00},

		//little MIPI shit: global timing unit, period of PCLK in ns * 2(depends on # of lanes)
		{0x4837, 24}, // 1/84M*2

		//Undocumented anti-green settings
		{0x3618, 0x00}, // Removes vertical lines appearing under bright light
		{0x3612, 0x59},
		{0x3708, 0x64},
		{0x3709, 0x52},
		{0x370c, 0x03},

		//[7:4]=0x0 Formatter RAW, [3:0]=0x0 BGBG/GRGR
		{0x4300, 0x00},
		//[2:0]=0x3 Format select ISP RAW (DPC)
		{0x501f, 0x03},

		{SEQUENCE_END, 0x00}
};


struct reginfo cfg_advanced_awb[] =
{
		// Enable Advanced AWB
		{0x3406 ,0x00},
		{0x5192 ,0x04},
		{0x5191 ,0xf8},
		{0x518d ,0x26},
		{0x518f ,0x42},
		{0x518e ,0x2b},
		{0x5190 ,0x42},
		{0x518b ,0xd0},
		{0x518c ,0xbd},
		{0x5187 ,0x18},
		{0x5188 ,0x18},
		{0x5189 ,0x56},
		{0x518a ,0x5c},
		{0x5186 ,0x1c},
		{0x5181 ,0x50},
		{0x5184 ,0x20},
		{0x5182 ,0x11},
		{0x5183 ,0x00},
		{0x5001 ,0x03},

		{SEQUENCE_END, 0x00}
};

static int ov5640_write(u16 addr, u8 data)
{
	return Ov5640_WriteReg(addr, data);
}

static int ov5640_read(u16 addr, u8 *read_buf)
{
	return Ov5640_ReadReg(addr, read_buf);
}

static void sensor_write_array(struct reginfo *regarray)
{
	int i = 0;

	while (regarray[i].reg != SEQUENCE_END) {
		if (ov5640_write(regarray[i].reg, regarray[i].val) != XST_SUCCESS)
			xil_printf("OV5640 write fail reg=0x%04X\r\n", regarray[i].reg);
		i++;
	}
}

int Ov5640_SensorInit(void)
{
	u8 sensor_id[2];
	int st;

	st = ov5640_read(0x300AU, &sensor_id[0]);
	if (st != XST_SUCCESS) {
		xil_printf("OV5640 read 0x300A failed\r\n");
		return XST_FAILURE;
	}
	st = ov5640_read(0x300BU, &sensor_id[1]);
	if (st != XST_SUCCESS) {
		xil_printf("OV5640 read 0x300B failed\r\n");
		return XST_FAILURE;
	}

	if (sensor_id[0] != 0x56U || sensor_id[1] != 0x40U) {
		xil_printf("Not ov5640 id, %x %x\r\n", sensor_id[0], sensor_id[1]);
		return XST_FAILURE;
	}
	xil_printf("Got ov5640 id, %x %x\r\n", sensor_id[0], sensor_id[1]);

	ov5640_write(0x3103U, 0x11U);
	ov5640_write(0x3008U, 0x82U);
	usleep(1000000);

	sensor_write_array(sensor_init_data);
	usleep(1000000);
	ov5640_write(0x3008U, 0x42U);
#if P1080 == 1
	sensor_write_array(cfg_1080p_30fps);
#else
	sensor_write_array(cfg_702p_60fps);
#endif
	sensor_write_array(cfg_advanced_awb);
	ov5640_write(0x3008U, 0x02U);

	/* N16: dump timing window / output size / HTS / binning for stride debug */
	{
		u8 b[16];
		u16 x0, x1, y0, y1, ow, oh, hts, vts;
		u32 i;

		for (i = 0U; i < 16U; i++) {
			if (ov5640_read((u16)(0x3800U + i), &b[i]) != XST_SUCCESS)
				b[i] = 0xFFU;
		}
		x0 = (u16)(((u16)(b[0] & 0x0FU) << 8) | b[1]);
		y0 = (u16)(((u16)(b[2] & 0x07U) << 8) | b[3]);
		x1 = (u16)(((u16)(b[4] & 0x0FU) << 8) | b[5]);
		y1 = (u16)(((u16)(b[6] & 0x07U) << 8) | b[7]);
		ow = (u16)(((u16)(b[8] & 0x0FU) << 8) | b[9]);
		oh = (u16)(((u16)(b[10] & 0x7FU) << 8) | b[11]);
		hts = (u16)(((u16)(b[12] & 0x1FU) << 8) | b[13]);
		vts = (u16)(((u16)b[14] << 8) | b[15]);
		xil_printf("OV5640 win x=%u..%u (W=%u) y=%u..%u (H=%u)\r\n",
			   (unsigned)x0, (unsigned)x1,
			   (unsigned)(x1 - x0 + 1U),
			   (unsigned)y0, (unsigned)y1,
			   (unsigned)(y1 - y0 + 1U));
		xil_printf("OV5640 out=%ux%u HTS=%u VTS=%u\r\n",
			   (unsigned)ow, (unsigned)oh,
			   (unsigned)hts, (unsigned)vts);
		if (ov5640_read(0x3814U, &b[0]) == XST_SUCCESS &&
		    ov5640_read(0x3815U, &b[1]) == XST_SUCCESS)
			xil_printf("OV5640 bin 3814=0x%02X 3815=0x%02X "
				   "BAYER_OFF x=%d y=%d\r\n",
				   b[0], b[1],
				   (int)BAYER_X_OFF, (int)BAYER_Y_OFF);
	}

	xil_printf("OV5640 sensor_init done (ALINX 24_an5641 table)\r\n");
	return XST_SUCCESS;
}

int Ov5640_SetAutoExposure(int enable)
{
	u8 v = 0U;

	if (ov5640_read(0x3503U, &v) != XST_SUCCESS)
		return XST_FAILURE;
	if (enable)
		v &= (u8)~0x07U; /* AEC/AGC/VTS auto */
	else
		v |= 0x07U; /* manual AEC+AGC+VTS */
	if (ov5640_write(0x3503U, v) != XST_SUCCESS)
		return XST_FAILURE;
	xil_printf("[OV5640] AEC/AGC %s (3503=0x%02X)\r\n",
		   enable ? "auto" : "manual", v);
	return XST_SUCCESS;
}

int Ov5640_SetManualExposure(u32 exposure_lines, u16 gain_q4_4)
{
	/* exposure_lines in whole lines; sensor wants 1/16-line units.
	 * N22: exposure must stay below VTS; extend VTS when needed (was
	 * writing 2000 with VTS=1120 → darker than AEC). */
	u32 exp16;
	u32 vts;
	u8 g_hi, g_lo;
	u8 vts_hi = 0U, vts_lo = 0U;

	if (Ov5640_SetAutoExposure(0) != XST_SUCCESS)
		return XST_FAILURE;
	if (exposure_lines < 1U)
		exposure_lines = 1U;
	if (exposure_lines > 0xFFFFU)
		exposure_lines = 0xFFFFU;

	if (ov5640_read(0x380EU, &vts_hi) != XST_SUCCESS ||
	    ov5640_read(0x380FU, &vts_lo) != XST_SUCCESS)
		return XST_FAILURE;
	vts = ((u32)vts_hi << 8) | (u32)vts_lo;
	if (vts < 8U)
		vts = 1120U;
	if (exposure_lines + 4U >= vts) {
		vts = exposure_lines + 20U;
		if (vts > 0xFFFFU)
			vts = 0xFFFFU;
		if (ov5640_write(0x380EU, (u8)((vts >> 8) & 0xFFU)) != XST_SUCCESS ||
		    ov5640_write(0x380FU, (u8)(vts & 0xFFU)) != XST_SUCCESS)
			return XST_FAILURE;
	}

	exp16 = exposure_lines << 4; /* *16 */
	if (exp16 > 0xFFFFFU)
		exp16 = 0xFFFFFU;
	if (gain_q4_4 < 0x10U)
		gain_q4_4 = 0x10U; /* 1.0x */
	if (gain_q4_4 > 0x3FFU)
		gain_q4_4 = 0x3FFU;

	ov5640_write(0x3500U, (u8)((exp16 >> 16) & 0x0FU));
	ov5640_write(0x3501U, (u8)((exp16 >> 8) & 0xFFU));
	ov5640_write(0x3502U, (u8)(exp16 & 0xFFU));
	g_hi = (u8)((gain_q4_4 >> 8) & 0x03U);
	g_lo = (u8)(gain_q4_4 & 0xFFU);
	ov5640_write(0x350AU, g_hi);
	ov5640_write(0x350BU, g_lo);
	xil_printf("[OV5640] manual exp_lines=%u gain=0x%03X VTS=%u\r\n",
		   (unsigned)exposure_lines, (unsigned)gain_q4_4,
		   (unsigned)vts);
	return XST_SUCCESS;
}

int Ov5640_SetTestPattern(int enable)
{
	u8 v = enable ? 0x80U : 0x00U; /* ALINX: color bar */

	if (ov5640_write(0x503DU, v) != XST_SUCCESS)
		return XST_FAILURE;
	xil_printf("[OV5640] test_pattern 503D=0x%02X\r\n", v);
	return XST_SUCCESS;
}

int Ov5640_DumpTiming(void)
{
	u8 b[16];
	u16 w, h, hts, vts, xs, xe, ys, ye;

	if (ov5640_read(0x3800U, &b[0]) != XST_SUCCESS)
		return XST_FAILURE;
	(void)ov5640_read(0x3801U, &b[1]);
	(void)ov5640_read(0x3802U, &b[2]);
	(void)ov5640_read(0x3803U, &b[3]);
	(void)ov5640_read(0x3804U, &b[4]);
	(void)ov5640_read(0x3805U, &b[5]);
	(void)ov5640_read(0x3806U, &b[6]);
	(void)ov5640_read(0x3807U, &b[7]);
	(void)ov5640_read(0x3808U, &b[8]);
	(void)ov5640_read(0x3809U, &b[9]);
	(void)ov5640_read(0x380AU, &b[10]);
	(void)ov5640_read(0x380BU, &b[11]);
	(void)ov5640_read(0x380CU, &b[12]);
	(void)ov5640_read(0x380DU, &b[13]);
	(void)ov5640_read(0x380EU, &b[14]);
	(void)ov5640_read(0x380FU, &b[15]);
	xs = (u16)(((u16)(b[0] & 0x0FU) << 8) | b[1]);
	ys = (u16)(((u16)(b[2] & 0x07U) << 8) | b[3]);
	xe = (u16)(((u16)(b[4] & 0x0FU) << 8) | b[5]);
	ye = (u16)(((u16)(b[6] & 0x07U) << 8) | b[7]);
	w = (u16)(((u16)(b[8] & 0x0FU) << 8) | b[9]);
	h = (u16)(((u16)(b[10] & 0x7FU) << 8) | b[11]);
	hts = (u16)(((u16)(b[12] & 0x1FU) << 8) | b[13]);
	vts = (u16)(((u16)b[14] << 8) | b[15]);
	xil_printf("[OV5640] win x=%u..%u y=%u..%u out=%ux%u HTS=%u VTS=%u\r\n",
		   (unsigned)xs, (unsigned)xe, (unsigned)ys, (unsigned)ye,
		   (unsigned)w, (unsigned)h, (unsigned)hts, (unsigned)vts);
	return XST_SUCCESS;
}

int Ov5640_SetOutputSize(u16 width, u16 height)
{
	if (width < 16U || height < 16U)
		return XST_FAILURE;
	if (ov5640_write(0x3808U, (u8)((width >> 8) & 0x0FU)) != XST_SUCCESS ||
	    ov5640_write(0x3809U, (u8)(width & 0xFFU)) != XST_SUCCESS ||
	    ov5640_write(0x380AU, (u8)((height >> 8) & 0x7FU)) != XST_SUCCESS ||
	    ov5640_write(0x380BU, (u8)(height & 0xFFU)) != XST_SUCCESS)
		return XST_FAILURE;
	xil_printf("[OV5640] set out=%ux%u\r\n",
		   (unsigned)width, (unsigned)height);
	return Ov5640_DumpTiming();
}

