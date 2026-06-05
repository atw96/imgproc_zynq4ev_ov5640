/*
 * doc/course_s2/09_ps_net/vitis/net_test — TCP echo port 7
 * 10.0.0.10/24 直连 PC，与 WiFi 192.168.x 完全分离；poll 主循环
 */
#include <stdio.h>
#include "xparameters.h"
#include "netif/xadapter.h"
#include "platform.h"
#include "platform_config.h"
#include "xil_printf.h"
#include "lwip/tcp.h"
#include "xil_cache.h"

void print_app_header();
int start_application();
int transfer_data();
void tcp_fasttmr(void);
void tcp_slowtmr(void);
void lwip_init();

static struct netif server_netif;
struct netif *echo_netif;

void print_ip(char *msg, ip_addr_t *ip)
{
	print(msg);
	xil_printf("%d.%d.%d.%d\n\r", ip4_addr1(ip), ip4_addr2(ip),
		   ip4_addr3(ip), ip4_addr4(ip));
}

void print_ip_settings(ip_addr_t *ip, ip_addr_t *mask, ip_addr_t *gw)
{
	print_ip("Board IP: ", ip);
	print_ip("Netmask : ", mask);
	print_ip("Gateway : ", gw);
}

int main(void)
{
	ip_addr_t ipaddr, netmask, gw;
	unsigned char mac_ethernet_address[] = { 0x00, 0x0a, 0x35, 0x00, 0x01, 0x02 };
	u32 loop_cnt = 0U;

	xil_printf("\r\n=== 09_ps_net ps_eth net_test TCP echo :7 ===\r\n");

	echo_netif = &server_netif;
	init_platform();

	IP4_ADDR(&ipaddr, 10, 0, 0, 10);
	IP4_ADDR(&netmask, 255, 255, 255, 0);
	IP4_ADDR(&gw, 10, 0, 0, 1);

	print_app_header();
	lwip_init();

	if (!xemac_add(echo_netif, &ipaddr, &netmask, &gw, mac_ethernet_address,
		       PLATFORM_EMAC_BASEADDR)) {
		xil_printf("Error adding N/W interface\n\r");
		return -1;
	}
	netif_set_default(echo_netif);
	platform_enable_interrupts();
	netif_set_up(echo_netif);
	print_ip_settings(&ipaddr, &netmask, &gw);

	start_application();
	xil_printf("Ready: PC telnet 10.0.0.10 7\r\n");

	while (1) {
		loop_cnt++;
		if ((loop_cnt % 50000U) == 0U)
			tcp_fasttmr();
		if ((loop_cnt % 500000U) == 0U) {
			tcp_slowtmr();
			eth_link_detect(echo_netif);
		}
		xemacif_input(echo_netif);
		transfer_data();
	}
	return 0;
}
