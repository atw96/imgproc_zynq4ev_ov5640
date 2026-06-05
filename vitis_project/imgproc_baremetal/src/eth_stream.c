/*
 * eth_stream.c -- AXI DMA S2MM + LwIP RAW UDP
 * ref: doc/course_s2/09_ps_net
 */
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "xil_io.h"
#include "sleep.h"
#include <string.h>
#include "ov5640_config.h"

#if defined(XPAR_XEMACPS_0_BASEADDR) && defined(XPAR_AXIDMA_0_DEVICE_ID)

#include "xaxidma.h"
#include "xaxidma_hw.h"
#include "lwip/init.h"
#include "lwip/udp.h"
#include "netif/xadapter.h"
#include "lwip/ip_addr.h"
#include "lwip/etharp.h"
#include "platform.h"
#include "platform_config.h"
#include "ov5640_sensor.h"
#include "pl_isp.h"
#include <string.h>

/* 板端 UDP 目标：PC 地址（与 README 默认一致，按实际网络修改） */
#define ETH_DST_IP_STR   "192.168.1.100"
#define ETH_PROBE_PORT   5003U
#define ETH_DST_PORT     5002U
#define ETH_SRC_PORT     5001U
#define UDP_MTU_DATA     1400U

#define IMG_W            ((u32)VIDEO_COLUMNS)
#define IMG_H            ((u32)VIDEO_ROWS)
#define FRAME_HDR_SZ     8U
#define FRAME_DATA_SZ    (IMG_W * IMG_H)
#define FRAME_TOT_SZ     (FRAME_HDR_SZ + FRAME_DATA_SZ)

#define CHUNK_HDR_SZ     8U
#define CHUNK_DATA_SZ    (UDP_MTU_DATA - CHUNK_HDR_SZ)

static XAxiDma DmaInst;
static struct netif Netif;
struct netif *echo_netif;
static struct udp_pcb *UdpPcb;
static ip_addr_t DstIp;


static void eth_print_ip(const char *msg, const ip4_addr_t *ip)
{
	xil_printf("%s%d.%d.%d.%d\r\n", msg,
		   ip4_addr1(ip), ip4_addr2(ip), ip4_addr3(ip), ip4_addr4(ip));
}

static u32 eth_link_cnt;

static void eth_poll_tick(void)
{
	/* 09_ps_net main.c: while(1) { xemacif_input(echo_netif); } */
	if (echo_netif)
		xemacif_input(echo_netif);
	/* timer 约 1s 做一次 eth_link_detect；poll 下按帧率折算 */
	if (++eth_link_cnt >= 30U) {
		eth_link_cnt = 0U;
		if (echo_netif)
			eth_link_detect(echo_netif);
	}
}

static void eth_poll_burst(u32 n)
{
	u32 i;
	for (i = 0U; i < n; i++)
		eth_poll_tick();
}

static void eth_arp_probe_pc(void)
{
	ip4_addr_t pc_ip;

	if (!echo_netif)
		return;
	IP4_ADDR(&pc_ip, 192, 168, 1, 100);
	etharp_gratuitous(echo_netif);
	etharp_request(echo_netif, &pc_ip);
	xil_printf("[ETH] ARP: gratuitous + who-has %s\r\n", ETH_DST_IP_STR);
	eth_poll_burst(2000U);
}

static void udp_send_probe(const char *tag)
{
	struct pbuf *p;
	u8 *pld;
	size_t len;

	if (!UdpPcb)
		return;
	len = strlen(tag);
	if (len > 32U)
		len = 32U;
	p = pbuf_alloc(PBUF_TRANSPORT, (u16)len, PBUF_RAM);
	if (!p)
		return;
	pld = (u8 *)p->payload;
	memcpy(pld, tag, len);
	udp_sendto(UdpPcb, p, &DstIp, ETH_PROBE_PORT);
	pbuf_free(p);
	eth_poll_burst(64U);
}

static u8 RxBuf[FRAME_TOT_SZ + 64U] __attribute__((aligned(64U)));

static void be16_pack(u8 *p, u16 v)
{
	p[0] = (u8)(v >> 8);
	p[1] = (u8)(v & 0xFFU);
}

static u32 dma_max_xfer_bytes(void)
{
	u32 w = (u32)XPAR_AXI_DMA_ETH_SG_LENGTH_WIDTH;

	if (w < 8U)
		w = 26U;
	return (1U << w) - 1U;
}

static int dma_init(void)
{
	u32 max_len = dma_max_xfer_bytes();
	XAxiDma_Config *cfg = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);

	if (!cfg)
		return XST_FAILURE;
	if (XAxiDma_CfgInitialize(&DmaInst, cfg) != XST_SUCCESS)
		return XST_FAILURE;
	DmaInst.RxBdRing[0].MaxTransferLen = max_len;
	xil_printf("[ETH] DMA S2MM sg_width=%u max_xfer=%u B\r\n",
		   (unsigned)XPAR_AXI_DMA_ETH_SG_LENGTH_WIDTH, (unsigned)max_len);
	if (FRAME_TOT_SZ > max_len) {
		xil_printf("[ETH] frame %u B > DMA max, need wider c_sg_length_width\r\n",
			   (unsigned)FRAME_TOT_SZ);
		return XST_FAILURE;
	}
	if (XAxiDma_HasSg(&DmaInst))
		xil_printf("[ETH] WARN: DMA SG enabled\r\n");
	XAxiDma_IntrDisable(&DmaInst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
	return XST_SUCCESS;
}

static void dma_reset_s2mm(void)
{
	XAxiDma_Reset(&DmaInst);
	while (!XAxiDma_ResetIsDone(&DmaInst))
		;
	XAxiDma_IntrDisable(&DmaInst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
}

static void dma_log_status(const char *tag)
{
	u32 cr = XAxiDma_ReadReg(DmaInst.RegBase + XAXIDMA_RX_OFFSET,
				  XAXIDMA_CR_OFFSET);
	u32 sr = XAxiDma_ReadReg(DmaInst.RegBase + XAXIDMA_RX_OFFSET,
				  XAXIDMA_SR_OFFSET);
	u32 len = XAxiDma_ReadReg(DmaInst.RegBase + XAXIDMA_RX_OFFSET,
				   0x28U); /* S2MM_LENGTH offset */
	Xil_DCacheInvalidateRange((UINTPTR)RxBuf, 32U);
	xil_printf("[ETH] %s CR=0x%08X SR=0x%08X LEN=0x%08X"
		   " RxBuf[0..3]=0x%02X%02X%02X%02X\r\n",
		   tag, cr, sr, len,
		   RxBuf[0], RxBuf[1], RxBuf[2], RxBuf[3]);
}

/* Read PL AXI-Lite status registers (read-only, safe) */
static void pl_status_dump(void)
{
#ifdef XPAR_M_AXIL_CFG_BASEADDR
	u32 s0 = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + 0x200U);
	u32 s1 = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + 0x204U);
	u32 s2 = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + 0x208U);
	xil_printf("[PL] status[0]=0x%08X (dead_cnt) [1]=0x%08X (eth_frames/buf) [2]=0x%08X (mipi_beat)\r\n",
		   s0, s1, s2);
#endif
}

static int dma_arm_transfer(void)
{
	/* Always reset first to guarantee a clean halted state */
	dma_reset_s2mm();
	Xil_DCacheInvalidateRange((UINTPTR)RxBuf, FRAME_TOT_SZ);
	memset(RxBuf, 0, 32U); /* clear header area so we can detect DMA writes */
	Xil_DCacheFlushRange((UINTPTR)RxBuf, 32U);
	if (XAxiDma_SimpleTransfer(&DmaInst, (UINTPTR)RxBuf, FRAME_TOT_SZ,
				   XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
		dma_log_status("arm fail");
		return XST_FAILURE;
	}
	/* Confirm DMA started (CR.RS should be 1) */
	u32 cr = XAxiDma_ReadReg(DmaInst.RegBase + XAXIDMA_RX_OFFSET,
				  XAXIDMA_CR_OFFSET);
	xil_printf("[ETH] S2MM CR=0x%08X RS=%u MaxLen=%u\r\n",
		   cr, (cr & 1U), (unsigned)DmaInst.RxBdRing[0].MaxTransferLen);
	return XST_SUCCESS;
}

static int dma_wait_done(void)
{
	u32 tmo = 50000000UL;
	u32 hb  = 0U;

	while (XAxiDma_Busy(&DmaInst, XAXIDMA_DEVICE_TO_DMA)) {
		eth_poll_tick();
		if ((++hb % 5000000U) == 0U) {
			xil_printf("[ETH] dma_wait... (link=%u)\r\n",
				   (unsigned)Netif.flags);
			pl_status_dump();
		}
		if (--tmo == 0U) {
			dma_log_status("timeout");
			pl_status_dump();
			dma_reset_s2mm();
			return XST_FAILURE;
		}
	}
	Xil_DCacheInvalidateRange((UINTPTR)RxBuf, FRAME_TOT_SZ);
	return XST_SUCCESS;
}

static int dma_recv_frame(void)
{
	if (dma_arm_transfer() != XST_SUCCESS)
		return XST_FAILURE;
	return dma_wait_done();
}

static int parse_header(const u8 *buf, u16 *frame_id, u16 *w, u16 *h)
{
	if (buf[0] != 0xAAU || buf[1] != 0x55U)
		return -1;
	*frame_id = ((u16)buf[2] << 8) | buf[3];
	*w = ((u16)buf[4] << 8) | buf[5];
	*h = ((u16)buf[6] << 8) | buf[7];
	return 0;
}

static void udp_send_pixels(u16 frame_id, const u8 *pix, u32 data_len)
{
	u32 total_chunks =
		(data_len + (u32)CHUNK_DATA_SZ - 1U) / (u32)CHUNK_DATA_SZ;
	u32 offset = 0U;
	u16 i;

	for (i = 0U; i < (u16)total_chunks; i++) {
		u32 this_len = (offset + (u32)CHUNK_DATA_SZ <= data_len)
				       ? (u32)CHUNK_DATA_SZ
				       : (data_len - offset);
		struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT,
					    CHUNK_HDR_SZ + this_len,
					    PBUF_RAM);
		if (!p) {
			xil_printf("[ETH] pbuf_alloc failed\r\n");
			break;
		}
		u8 *pld = (u8 *)p->payload;
		be16_pack(pld + 0U, frame_id);
		be16_pack(pld + 2U, i);
		be16_pack(pld + 4U, (u16)total_chunks);
		be16_pack(pld + 6U, 0U);
		memcpy(pld + CHUNK_HDR_SZ, pix + offset, this_len);
		udp_sendto(UdpPcb, p, &DstIp, ETH_DST_PORT);
		pbuf_free(p);
		offset += this_len;
		if ((i & 0x3FU) == 0U)
			eth_poll_burst(32U);
		else
			eth_poll_tick();
	}
}

static int net_init(void)
{
	/* doc/course_s2/09_ps_net net_test main.c 默认 MAC */
	static unsigned char mac[6] = {0x00, 0x0a, 0x35, 0x00, 0x01, 0x02};
	ip4_addr_t ipaddr, netmask, gw;

	init_platform();
	lwip_init();

	IP4_ADDR(&ipaddr, 192, 168, 1, 10);
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 192, 168, 1, 1);

	if (!xemac_add(&Netif, &ipaddr, &netmask, &gw, mac,
		       PLATFORM_EMAC_BASEADDR)) {
		xil_printf("[ETH] xemac_add failed\r\n");
		return -1;
	}
	netif_set_default(&Netif);
	echo_netif = &Netif;
	platform_enable_interrupts();
	netif_set_up(&Netif);
	eth_arp_probe_pc();

	eth_print_ip("[ETH] Board IP: ", &ipaddr);
	eth_print_ip("[ETH] Netmask : ", &netmask);
	eth_print_ip("[ETH] Gateway : ", &gw);

	if (!ipaddr_aton(ETH_DST_IP_STR, &DstIp)) {
		xil_printf("[ETH] bad dst ip\r\n");
		return -1;
	}

	UdpPcb = udp_new();
	if (!UdpPcb) {
		xil_printf("[ETH] udp_new failed\r\n");
		return -1;
	}
	udp_bind(UdpPcb, IP_ADDR_ANY, ETH_SRC_PORT);

	xil_printf("[ETH] UDP -> %s:%u probe:%u\r\n",
		   ETH_DST_IP_STR, (unsigned)ETH_DST_PORT,
		   (unsigned)ETH_PROBE_PORT);
	return 0;
}

static void mipi_dump_status(void)
{
#ifdef XPAR_MIPI_CSI2_RX_SUBSYSTEM_0_BASEADDR
	UINTPTR base = (UINTPTR)XPAR_MIPI_CSI2_RX_SUBSYSTEM_0_BASEADDR;
	xil_printf("[ETH] MIPI CSIRXSS @0x%08X ctrl=0x%08X status=0x%08X\r\n",
		   (unsigned)base, (unsigned)Xil_In32(base + 0x00U),
		   (unsigned)Xil_In32(base + 0x04U));
#endif
}

/* =====================================================================
 * PS 梯度测试帧 (DMA 路径不可用时的 fallback)
 * 与 PL test_pat_gen 输出一致: pixel_byte = col >> 3
 * ===================================================================== */
static void ps_fill_gradient_frame(u16 fid)
{
	/* 帧头 (大端) */
	RxBuf[0] = 0xAAU; RxBuf[1] = 0x55U;
	RxBuf[2] = (u8)(fid >> 8); RxBuf[3] = (u8)(fid & 0xFFU);
	RxBuf[4] = (u8)(IMG_W >> 8); RxBuf[5] = (u8)(IMG_W & 0xFFU);
	RxBuf[6] = (u8)(IMG_H >> 8); RxBuf[7] = (u8)(IMG_H & 0xFFU);
	/* 像素：水平梯度，与 test_pat_gen 一致 */
	u8 *pix = RxBuf + FRAME_HDR_SZ;
	for (u32 row = 0U; row < IMG_H; row++) {
		for (u32 col = 0U; col < IMG_W; col++) {
			pix[row * IMG_W + col] = (u8)(col >> 3);
		}
	}
}

int eth_stream_main(void)
{
	xil_printf("[ETH] enter eth_stream_main (%ux%u buf, %u B/frame)\r\n",
		   (unsigned)IMG_W, (unsigned)IMG_H, (unsigned)FRAME_TOT_SZ);

	/* ---- DMA 初始化 ---- */
	xil_printf("[ETH] step: dma_init...\r\n");
	if (dma_init() != XST_SUCCESS) {
		xil_printf("[ETH] DMA init failed\r\n");
		return -1;
	}

	/* ---- 网络初始化 ---- */
	xil_printf("[ETH] step: net_init...\r\n");
	if (net_init() != 0) {
		xil_printf("[ETH] net init failed\r\n");
		return -1;
	}

	/* ---- PL DMA 路径：可 arm 则等 PL test_pat/frame_eth_tx 写入 ---- */
	xil_printf("[ETH] step: arm DMA S2MM...\r\n");
	int ps_mode = (dma_arm_transfer() != XST_SUCCESS);
	if (ps_mode) {
		xil_printf("[ETH] DMA arm failed -> PS gradient fallback\r\n");
	} else {
		xil_printf("[ETH] PL DMA mode (%u B/frame, wait TLAST)\r\n",
			   (unsigned)FRAME_TOT_SZ);
	}

	mipi_dump_status();
	pl_status_dump();

	u32 ok = 0U, err = 0U;
	u16 fid = 0U;
	int dma_armed = !ps_mode; /* DMA 模式下首帧已 arm */

	if (ps_mode)
		xil_printf("[ETH] sending PS gradient frames (1920x1080)...\r\n");
	else
		xil_printf("[ETH] waiting PL frames via AXI DMA S2MM...\r\n");

	{
		u32 p;
		for (p = 0U; p < 20U; p++) {
			udp_send_probe("IMGPROC_PROBE");
			usleep(200000U);
		}
		xil_printf("[ETH] probe x20 done, start stream\r\n");
	}

	for (;;) {
		/* ============ PS 梯度模式（主路径：DMA 不可用时） ============ */
		if (ps_mode) {
			ps_fill_gradient_frame(fid);
			udp_send_pixels(fid, RxBuf + FRAME_HDR_SZ, FRAME_DATA_SZ);
			ok++;
			fid++;
			if ((ok % 30U) == 1U)
				xil_printf("[ETH] sent frame %u (PS grad, 1920x1080) err=%u\r\n",
					   (unsigned)ok, (unsigned)err);
			usleep(100000U); /* 10fps，减轻 USB 网卡压力 */
			if ((ok % 10U) == 1U)
				udp_send_probe("IMGPROC_PROBE");
			eth_poll_burst(128U);
			continue;
		}

		/* ============ PL DMA 模式 ============ */
		int rc;
		if (dma_armed) {
			dma_armed = 0;
			rc = dma_wait_done();
		} else {
			rc = dma_recv_frame();
		}
		if (rc != XST_SUCCESS) {
			err++;
			if ((err & 0x3FU) == 1U)
				xil_printf("[ETH] dma err=%u\r\n", err);
			usleep(10000U);
			eth_poll_tick();
			dma_armed = (dma_arm_transfer() == XST_SUCCESS);
			continue;
		}
		u16 fw, fh;
		if (parse_header(RxBuf, &fid, &fw, &fh) != 0) {
			err++;
			xil_printf("[ETH] bad frame header\r\n");
			dma_armed = (dma_arm_transfer() == XST_SUCCESS);
			continue;
		}
		u32 n = (u32)fw * (u32)fh;
		if (n > FRAME_DATA_SZ)
			n = FRAME_DATA_SZ;
		udp_send_pixels(fid, RxBuf + FRAME_HDR_SZ, n);
		ok++;
		if ((ok & 0xFFU) == 1U)
			xil_printf("[ETH] sent frame %u (%ux%u) err=%u\r\n",
				   (unsigned)ok, (unsigned)fw, (unsigned)fh, err);
		eth_poll_tick();
		dma_armed = (dma_arm_transfer() == XST_SUCCESS);
	}
}

#else

int eth_stream_main(void)
{
	xil_printf("[ETH] Skip: need GEM3+AXI DMA in BSP\r\n");
	return 0;
}

#endif
