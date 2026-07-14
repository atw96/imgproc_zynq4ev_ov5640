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

/* Motorcomm 直连：广播更稳（免 ARP 时序）；单播作辅助 */
#define ETH_DST_IP_STR   "10.0.0.255"
#define ETH_PROBE_PORT   5003U
#define ETH_DST_PORT     5010U   /* PC listen; avoid lktsrv.exe on 5002 */
#define ETH_SRC_PORT     5001U
#define UDP_MTU_DATA     1400U

#define IMG_W            ((u32)VIDEO_COLUMNS)
#define IMG_H            ((u32)VIDEO_ROWS)
/* 12B header = 3 full 32-bit AXIS beats (TKEEP=F); bytes[0..9] same as before */
#define FRAME_HDR_SZ     12U
#define FRAME_DATA_SZ    (IMG_W * IMG_H * 4U)  /* RGBX: R,G,B,0 per pixel */
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
	IP4_ADDR(&pc_ip, 10, 0, 0, 100);
	etharp_gratuitous(echo_netif);
	etharp_request(echo_netif, &pc_ip);
	xil_printf("[ETH] ARP: gratuitous + who-has 10.0.0.100\r\n");
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
	UINTPTR base = (UINTPTR)XPAR_M_AXIL_CFG_BASEADDR;
	u32 dead = Xil_In32(base + 0x200U);
	u32 ethb = Xil_In32(base + 0x204U);
	u32 mbeat = Xil_In32(base + 0x208U);
	u32 mpix = Xil_In32(base + 0x20CU);
	u32 raw = Xil_In32(base + 0x210U);
	u32 clahe = Xil_In32(base + 0x214U);
	xil_printf("[PL] dead=0x%08X eth=0x%08X mipi_beat=%u mipi_pix=%u raw=%u clahe=%u\r\n",
		   dead, ethb, mbeat, mpix, raw, clahe);
#endif
}

/* 重 arm S2MM；do_reset=0 保持 PL AXIS 连续流，避免每帧 reset 打断帧边界 */
static int dma_arm_transfer_ex(int do_reset)
{
	if (do_reset)
		dma_reset_s2mm();
	Xil_DCacheInvalidateRange((UINTPTR)RxBuf, FRAME_TOT_SZ);
	memset(RxBuf, 0, 32U);
	Xil_DCacheFlushRange((UINTPTR)RxBuf, 32U);
	if (XAxiDma_SimpleTransfer(&DmaInst, (UINTPTR)RxBuf, FRAME_TOT_SZ,
				   XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS) {
		dma_log_status("arm fail");
		return XST_FAILURE;
	}
	return XST_SUCCESS;
}

static int dma_arm_transfer(void)
{
	static int logged;
	int st = dma_arm_transfer_ex(1);
	if (st == XST_SUCCESS && !logged) {
		u32 cr = XAxiDma_ReadReg(DmaInst.RegBase + XAXIDMA_RX_OFFSET,
					  XAXIDMA_CR_OFFSET);
		xil_printf("[ETH] S2MM CR=0x%08X RS=%u MaxLen=%u\r\n",
			   cr, (cr & 1U),
			   (unsigned)DmaInst.RxBdRing[0].MaxTransferLen);
		logged = 1;
	}
	return st;
}

static int dma_rearm_transfer(void)
{
	return dma_arm_transfer_ex(0);
}

static int pl_pipeline_idle(void)
{
#ifdef XPAR_M_AXIL_CFG_BASEADDR
	u32 raw = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + 0x210U);
	u32 ethb = Xil_In32((UINTPTR)XPAR_M_AXIL_CFG_BASEADDR + 0x204U);
	return (raw == 0U) && ((ethb & 0xFFFFU) == 0U);
#else
	return 0;
#endif
}

static int dma_wait_done(void)
{
	/* ~2–3s-ish wall time; was 50M and hung for minutes with no TLAST */
	u32 tmo = 8000000UL;
	u32 hb  = 0U;

	while (XAxiDma_Busy(&DmaInst, XAXIDMA_DEVICE_TO_DMA)) {
		eth_poll_tick();
		if ((++hb % 1000000U) == 0U) {
			xil_printf("[ETH] dma_wait... (link=%u)\r\n",
				   (unsigned)Netif.flags);
			dma_log_status("wait");
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
	if (dma_arm_transfer_ex(1) != XST_SUCCESS)
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

/* DMA 应在 gap 内对齐到帧头；完整帧要求 AA55 在 offset 0 */
static int find_frame_offset(const u8 *buf, u32 scan_len, u16 *frame_id,
			     u16 *w, u16 *h)
{
	(void)scan_len;
	if (parse_header(buf, frame_id, w, h) != 0)
		return -1;
	/* 正常路径：W/H 与固件一致 */
	if (*w == (u16)IMG_W && *h == (u16)IMG_H)
		return 0;
	/*
	 * 兼容旧 bit：第 2 个 AXIS 字宽高打包曾综合错（见 07 00 00 00），
	 * 但 AA55 + format=1 且后续为 RGBX 载荷时仍可出图。
	 */
	if (buf[8] == 1U) {
		*w = (u16)IMG_W;
		*h = (u16)IMG_H;
		return 0;
	}
	return -1;
}

static void dump_frame_pixels(const u8 *pix, u32 n)
{
	u32 i, nz = 0U;
	u8 pmin = 255U, pmax = 0U;

	for (i = 0U; i < n && i < 4096U; i++) {
		if (pix[i] != 0U)
			nz++;
		if (pix[i] < pmin)
			pmin = pix[i];
		if (pix[i] > pmax)
			pmax = pix[i];
	}
	xil_printf("[ETH] pix sample[0..3]=%02X %02X %02X %02X"
		   " min=%u max=%u nz4k=%u\r\n",
		   pix[0], pix[1], pix[2], pix[3],
		   (unsigned)pmin, (unsigned)pmax, (unsigned)nz);
}

static void udp_send_pixels(u16 frame_id, const u8 *pix, u32 data_len)
{
	u32 total_chunks =
		(data_len + (u32)CHUNK_DATA_SZ - 1U) / (u32)CHUNK_DATA_SZ;
	u32 offset = 0U;
	u16 i;
	static int err_logged;

	for (i = 0U; i < (u16)total_chunks; i++) {
		u32 this_len = (offset + (u32)CHUNK_DATA_SZ <= data_len)
				       ? (u32)CHUNK_DATA_SZ
				       : (data_len - offset);
		struct pbuf *p = pbuf_alloc(PBUF_TRANSPORT,
					    CHUNK_HDR_SZ + this_len,
					    PBUF_RAM);
		err_t er;

		if (!p) {
			xil_printf("[ETH] pbuf_alloc failed @chunk %u\r\n",
				   (unsigned)i);
			break;
		}
		u8 *pld = (u8 *)p->payload;
		be16_pack(pld + 0U, frame_id);
		be16_pack(pld + 2U, i);
		be16_pack(pld + 4U, (u16)total_chunks);
		be16_pack(pld + 6U, 0U);
		memcpy(pld + CHUNK_HDR_SZ, pix + offset, this_len);
		/* 同一 pbuf 只能 send 一次：lwIP 会就地加 UDP/IP 头 */
		er = udp_sendto(UdpPcb, p, &DstIp, ETH_DST_PORT);
		if (er != ERR_OK && err_logged < 8) {
			xil_printf("[ETH] udp_sendto err=%d chunk=%u\r\n",
				   (int)er, (unsigned)i);
			err_logged++;
		}
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

	/* 10.0.0.0/24 直连，与 WiFi 192.168.x 无关 */
	IP4_ADDR(&ipaddr, 10, 0, 0, 10);
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 10, 0, 0, 1);

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
#if IP_SOF_BROADCAST
	ip_set_option(UdpPcb, SOF_BROADCAST);
#endif
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
	u32 row, col;
	u8 *pix;
	u8 v;

	RxBuf[0] = 0xAAU; RxBuf[1] = 0x55U;
	RxBuf[2] = (u8)(fid >> 8); RxBuf[3] = (u8)(fid & 0xFFU);
	RxBuf[4] = (u8)(IMG_W >> 8); RxBuf[5] = (u8)(IMG_W & 0xFFU);
	RxBuf[6] = (u8)(IMG_H >> 8); RxBuf[7] = (u8)(IMG_H & 0xFFU);
	RxBuf[8] = 1U; /* format RGBX */
	RxBuf[9] = 0U;
	pix = RxBuf + FRAME_HDR_SZ;
	for (row = 0U; row < IMG_H; row++) {
		for (col = 0U; col < IMG_W; col++) {
			v = (u8)(col >> 3);
			pix[0] = v;
			pix[1] = v;
			pix[2] = v;
			pix[3] = 0U;
			pix += 4U;
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

	/* PL 长时间无像素则切 PS 梯度，先验证 ETH/PC 收包链路 */
	if (!ps_mode) {
		u32 wait;
		for (wait = 0U; wait < 40U; wait++) {
			if (!pl_pipeline_idle())
				break;
			usleep(50000U);
			eth_poll_tick();
		}
		if (pl_pipeline_idle()) {
			xil_printf("[ETH] PL idle 2s (raw/eth=0) -> PS gradient fallback\r\n");
			ps_mode = 1;
		}
	}

	{
		u32 p;
		for (p = 0U; p < 20U; p++) {
			udp_send_probe("IMGPROC_PROBE");
			usleep(200000U);
		}
		xil_printf("[ETH] probe x20 done, start stream\r\n");
	}

	/*
	 * 首笔 DMA 几乎必在帧中途 arm：收到的是半帧到 TLAST，缓冲无 AA55。
	 * PL 随后进入 ~20ms gap；此处立刻 rearm，下一帧应从 AA55 开始。
	 */
	if (!ps_mode && dma_armed) {
		xil_printf("[ETH] discard mid-frame sync (arm in gap)...\r\n");
		(void)dma_wait_done();
		usleep(1000U);
		dma_armed = (dma_arm_transfer_ex(0) == XST_SUCCESS);
		pl_status_dump();
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
			if ((ok & 0x3FU) == 0U)
				eth_arp_probe_pc();
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
			if (err >= 2U && pl_pipeline_idle()) {
				xil_printf("[ETH] DMA stall -> PS gradient fallback\r\n");
				ps_mode = 1;
				continue;
			}
			usleep(1000U);
			eth_poll_tick();
			dma_armed = (dma_arm_transfer_ex(0) == XST_SUCCESS);
			continue;
		}
		u16 fw, fh, hdr_fid;
		int off = find_frame_offset(RxBuf, FRAME_TOT_SZ, &hdr_fid, &fw, &fh);

		if (off < 0) {
			err++;
			if ((err & 0x3FU) == 1U) {
				u16 tw, th, tfid;
				int ph = parse_header(RxBuf, &tfid, &tw, &th);
				xil_printf("[ETH] bad frame header"
					   " RxBuf=%02X%02X%02X%02X"
					   " %02X%02X%02X%02X %02X%02X%02X%02X"
					   " parse=%d fid=%u w=%u h=%u\r\n",
					   RxBuf[0], RxBuf[1], RxBuf[2], RxBuf[3],
					   RxBuf[4], RxBuf[5], RxBuf[6], RxBuf[7],
					   RxBuf[8], RxBuf[9], RxBuf[10], RxBuf[11],
					   ph, (unsigned)tfid, (unsigned)tw, (unsigned)th);
				pl_status_dump();
			}
			/* TLAST 后 PL 在 gap：立刻 rearm，勿睡满 20ms 错过 AA55 */
			usleep(1000U);
			eth_poll_tick();
			dma_armed = (dma_arm_transfer_ex(0) == XST_SUCCESS);
			continue;
		}
		/* 仅接受帧头对齐的完整帧（off!=0 时尾部像素不足一帧） */
		if (off != 0) {
			err++;
			if ((err & 0x3FU) == 1U)
				xil_printf("[ETH] mid-buf AA55 off=%d -> rearm gap\r\n",
					   off);
			usleep(1000U);
			dma_armed = (dma_arm_transfer_ex(0) == XST_SUCCESS);
			continue;
		}
		fid = hdr_fid;
		/* RGBX payload is W*H*4; header W/H are pixel dims */
		u32 n = FRAME_DATA_SZ;
		{
			const u8 *pix = RxBuf + FRAME_HDR_SZ;
			if ((ok & 0xFFU) == 0U)
				dump_frame_pixels(pix, n);
			udp_send_pixels(fid, pix, n);
		}
		ok++;
		if ((ok & 0xFFU) == 1U)
			xil_printf("[ETH] sent frame %u (%ux%u off=%d) err=%u\r\n",
				   (unsigned)ok, (unsigned)fw, (unsigned)fh, off,
				   (unsigned)err);
		/* 周期性重 ARP，消除 PC 晚于板上电导致单播 MAC 过期 */
		if ((ok & 0x3FU) == 0U)
			eth_arp_probe_pc();
		eth_poll_tick();
		/* 成功帧后也在 gap 内 rearm（TLAST 刚到） */
		usleep(1000U);
		dma_armed = (dma_rearm_transfer() == XST_SUCCESS);
	}
}

#else

int eth_stream_main(void)
{
	xil_printf("[ETH] Skip: need GEM3+AXI DMA in BSP\r\n");
	return 0;
}

#endif
