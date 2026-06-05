/*
 * eth_stream.c -- AXI DMA S2MM + LwIP RAW UDP
 * ref: doc/course_s2/09_ps_net
 */
#include "xparameters.h"
#include "xil_printf.h"
#include "xil_cache.h"
#include "sleep.h"
#include "ov5640_config.h"

#if defined(XPAR_XEMACPS_0_BASEADDR) && defined(XPAR_AXIDMA_0_DEVICE_ID)

#include "xaxidma.h"
#include "lwip/init.h"
#include "lwip/udp.h"
#include "netif/xadapter.h"
#include "lwip/ip_addr.h"
#include "platform.h"
#include "platform_config.h"
#include <string.h>

#define ETH_DST_IP_STR   "192.168.1.69"
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

static u8 RxBuf[FRAME_TOT_SZ + 64U] __attribute__((aligned(64U)));

static void be16_pack(u8 *p, u16 v)
{
	p[0] = (u8)(v >> 8);
	p[1] = (u8)(v & 0xFFU);
}

static int dma_init(void)
{
	XAxiDma_Config *cfg = XAxiDma_LookupConfig(XPAR_AXIDMA_0_DEVICE_ID);
	if (!cfg)
		return XST_FAILURE;
	if (XAxiDma_CfgInitialize(&DmaInst, cfg) != XST_SUCCESS)
		return XST_FAILURE;
	if (XAxiDma_HasSg(&DmaInst))
		xil_printf("[ETH] WARN: DMA SG enabled\r\n");
	XAxiDma_IntrDisable(&DmaInst, XAXIDMA_IRQ_ALL_MASK, XAXIDMA_DEVICE_TO_DMA);
	return XST_SUCCESS;
}

static int dma_recv_frame(void)
{
	u32 tmo;

	Xil_DCacheInvalidateRange((UINTPTR)RxBuf, FRAME_TOT_SZ);
	if (XAxiDma_SimpleTransfer(&DmaInst, (UINTPTR)RxBuf, FRAME_TOT_SZ,
				   XAXIDMA_DEVICE_TO_DMA) != XST_SUCCESS)
		return XST_FAILURE;

	tmo = 50000000UL;
	while (XAxiDma_Busy(&DmaInst, XAXIDMA_DEVICE_TO_DMA)) {
		xemacif_input(&Netif);
		if (--tmo == 0U) {
			xil_printf("[ETH] DMA timeout (no PL frame?)\r\n");
			return XST_FAILURE;
		}
	}
	Xil_DCacheInvalidateRange((UINTPTR)RxBuf, FRAME_TOT_SZ);
	return XST_SUCCESS;
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
		xemacif_input(&Netif);
	}
}

static int net_init(void)
{
	static unsigned char mac[6] = {0x00U, 0x0aU, 0x35U, 0x00U, 0x22U, 0x01U};
	ip4_addr_t ipaddr, netmask, gw;

	xil_printf("[ETH] step: lwip_init...\r\n");
	lwip_init();
	xil_printf("[ETH] step: lwip_init done\r\n");

	IP4_ADDR(&ipaddr, 192, 168, 1, 10);
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 192, 168, 1, 1);

	xil_printf("[ETH] step: xemac_add GEM3...\r\n");
	if (!xemac_add(&Netif, &ipaddr, &netmask, &gw, mac,
		       PLATFORM_EMAC_BASEADDR)) {
		xil_printf("[ETH] xemac_add failed\r\n");
		return -1;
	}
	netif_set_default(&Netif);
	echo_netif = &Netif;
	platform_enable_interrupts();
	netif_set_up(&Netif);
	xil_printf("[ETH] step: netif up\r\n");

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

	xil_printf("[ETH] board 192.168.1.10 -> %s:%u\r\n",
		   ETH_DST_IP_STR, (unsigned)ETH_DST_PORT);
	return 0;
}

int eth_stream_main(void)
{
	xil_printf("[ETH] enter eth_stream_main (%ux%u buf)\r\n",
		   (unsigned)IMG_W, (unsigned)IMG_H);
	xil_printf("[ETH] step: dma_init...\r\n");
	if (dma_init() != XST_SUCCESS) {
		xil_printf("[ETH] DMA init failed\r\n");
		return -1;
	}
	xil_printf("[ETH] step: net_init...\r\n");
	if (net_init() != 0) {
		xil_printf("[ETH] net init failed\r\n");
		return -1;
	}

	xil_printf("[ETH] waiting PL frames via AXI DMA S2MM...\r\n");

	u32 ok = 0U, err = 0U;

	for (;;) {
		if (dma_recv_frame() != XST_SUCCESS) {
			err++;
			if ((err & 0x3FU) == 1U)
				xil_printf("[ETH] dma err=%u (MIPI/ISP pipeline?)\r\n",
					   err);
			usleep(10000);
			xemacif_input(&Netif);
			continue;
		}
		u16 fid, w, h;
		if (parse_header(RxBuf, &fid, &w, &h) != 0) {
			err++;
			xil_printf("[ETH] bad frame header\r\n");
			continue;
		}
		u32 n = (u32)w * (u32)h;
		if (n > FRAME_DATA_SZ)
			n = FRAME_DATA_SZ;
		udp_send_pixels(fid, RxBuf + FRAME_HDR_SZ, n);
		ok++;
		if ((ok & 0xFFU) == 1U)
			xil_printf("[ETH] sent frame %u (%ux%u) err=%u\r\n",
				   (unsigned)ok, (unsigned)w, (unsigned)h, err);
		xemacif_input(&Netif);
	}
}

#else

int eth_stream_main(void)
{
	xil_printf("[ETH] Skip: need GEM3+AXI DMA in BSP\r\n");
	return 0;
}

#endif
