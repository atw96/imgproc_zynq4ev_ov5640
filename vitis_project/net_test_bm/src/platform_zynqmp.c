/*
 * platform_zynqmp.c — poll 模式（BSP export 无 xttcps 头文件）
 * eth_link_detect 周期由 eth_stream.c 主循环调用
 */
#if defined(__arm__) || defined(__aarch64__)

#include "xil_printf.h"
#include "platform.h"

#if defined(PLATFORM_ZYNQMP) || defined(PLATFORM_VERSAL)

volatile int TcpFastTmrFlag = 0;
volatile int TcpSlowTmrFlag = 0;

#if LWIP_DHCP == 1
volatile int dhcp_timoutcntr = 24;
#endif

void platform_setup_timer(void) { }
void platform_setup_interrupts(void) { }
void platform_enable_interrupts(void) { }

void init_platform(void)
{
	xil_printf("[PLAT] poll mode (09_ps_net eth in main loop)\r\n");
}

void cleanup_platform(void)
{
}

#endif
#endif
