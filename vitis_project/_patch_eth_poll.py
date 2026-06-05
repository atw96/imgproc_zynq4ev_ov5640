path = r"imgproc_baremetal/src/eth_stream.c"
with open(path, "r", encoding="utf-8", errors="replace") as f:
    s = f.read()
if "#include \"lwip/timeouts.h\"" not in s:
    s = s.replace('#include "lwip/ip_addr.h"', '#include "lwip/ip_addr.h"\n#include "lwip/timeouts.h"')
if "static void eth_poll_tick(void)" not in s:
    block = """
static u32 eth_poll_cnt;

static void eth_poll_tick(void)
{
\txemacif_input(&Netif);
\tif (++eth_poll_cnt >= 50000U) {
\t\teth_poll_cnt = 0U;
\t\tsys_check_timeouts();
\t}
}

"""
    s = s.replace("static u8 RxBuf[FRAME_TOT_SZ + 64U]", block + "static u8 RxBuf[FRAME_TOT_SZ + 64U]")
s = s.replace("\t\txemacif_input(&Netif);", "\t\teth_poll_tick();")
if "eth_link_detect(&Netif)" not in s:
    s = s.replace('\txil_printf("[ETH] step: netif up\\r\\n");', '\txil_printf("[ETH] step: netif up\\r\\n");\n\teth_link_detect(&Netif);')
with open(path, "w", encoding="utf-8", newline="\n") as f:
    f.write(s)
print("eth ok")
