from pathlib import Path

# main.c - early PlIsp
main = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/src/main.c")
m = main.read_text(encoding="utf-8")
if "pl_isp.h" not in m:
    m = m.replace('#include "eth_stream.h"', '#include "eth_stream.h"\n#include "pl_isp.h"')
if "PlIsp_EnableTestPattern" not in m:
    old = "\tusleep(500000);\r\n\t/* Ov5640_SensorInit"
    new = "\tusleep(500000);\r\n\tPlIsp_Init();\r\n\tPlIsp_EnableTestPattern(1);\r\n\tPlIsp_DumpStatus();\r\n\t/* Ov5640_SensorInit"
    if old not in m:
        old = "\tusleep(500000);\n\t/* Ov5640_SensorInit"
        new = "\tusleep(500000);\n\tPlIsp_Init();\n\tPlIsp_EnableTestPattern(1);\n\tPlIsp_DumpStatus();\n\t/* Ov5640_SensorInit"
    m = m.replace(old, new)
    main.write_text(m, encoding="utf-8")
    print("main.c updated")
else:
    print("main.c skip")

# eth_stream.c
eth = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/src/eth_stream.c")
e = eth.read_text(encoding="utf-8")

# heartbeat in dma_wait_done
if "dma_wait heartbeat" not in e:
    old = """\twhile (XAxiDma_Busy(&DmaInst, XAXIDMA_DEVICE_TO_DMA)) {
\t\teth_poll_tick();
\t\tif (--tmo == 0U) {"""
    new = """\tu32 hb = 0U;
\twhile (XAxiDma_Busy(&DmaInst, XAXIDMA_DEVICE_TO_DMA)) {
\t\teth_poll_tick();
\t\tif ((++hb % 5000000U) == 0U)
\t\t\txil_printf("[ETH] dma_wait... (PL test_pat? link=%u)\\r\\n",
\t\t\t\t   (unsigned)Netif.flags);
\t\tif (--tmo == 0U) {"""
    e = e.replace(old, new)

# skip ov5640 in phase1 + more prints
old_block = """\t/* Phase1: PL test pattern bypass ISP; set 0 for live MIPI */
\tPlIsp_EnableTestPattern(1);
\tPlIsp_DumpStatus();

\t/* \u5b98\u65b9 24_an5641\uff1a\u5148 arm VDMA/DMA\uff0c\u518d sensor_init \u5f00 MIPI */
\txil_printf("[ETH] step: arm DMA S2MM (before sensor)...\\r\\n");
\tif (dma_arm_transfer() != XST_SUCCESS) {
\t\txil_printf("[ETH] DMA arm failed\\r\\n");
\t\treturn -1;
\t}
\txil_printf("[ETH] step: ov5640 sensor_init (start MIPI)...\\r\\n");
\tif (Ov5640_SensorInit() != XST_SUCCESS) {
\t\txil_printf("[ETH] Ov5640_SensorInit failed\\r\\n");
\t\treturn -1;
\t}
\txil_printf("OK: OV5640 init done.\\r\\n");
\tmipi_dump_status();"""

new_block = """\t/* Phase1: test pattern already enabled in main(); skip MIPI sensor */
\txil_printf("[ETH] step: pl_isp (test_pattern=1, skip MIPI)...\\r\\n");
\tPlIsp_DumpStatus();

\txil_printf("[ETH] step: arm DMA S2MM...\\r\\n");
\tif (dma_arm_transfer() != XST_SUCCESS) {
\t\txil_printf("[ETH] DMA arm failed\\r\\n");
\t\tPlIsp_DumpStatus();
\t\treturn -1;
\t}
\txil_printf("[ETH] Phase1: skip Ov5640_SensorInit (test pattern)\\r\\n");
\tmipi_dump_status();"""

if "Phase1: skip Ov5640" not in e:
    if old_block in e:
        e = e.replace(old_block, new_block)
    else:
        print("eth_stream block not found - manual check")
eth.write_text(e, encoding="utf-8")
print("eth_stream.c updated")

# pl_isp.c - print before write
pl = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/imgproc_baremetal/src/pl_isp.c")
p = pl.read_text(encoding="utf-8")
if "before write" not in p:
    p = p.replace(
        "static void pl_write_ctrl(u32 ctrl)\n{\n\tXil_Out32",
        "static void pl_write_ctrl(u32 ctrl)\n{\n\t/* device memory */\n\tXil_Out32",
    )
    p = p.replace(
        "int PlIsp_EnableTestPattern(int enable)\n{\n\tu32 ctrl = PL_CTRL_RES_1080P;",
        "int PlIsp_EnableTestPattern(int enable)\n{\n\txil_printf(\"[PL] enable test_pattern=%d...\\r\\n\", enable ? 1 : 0);\n\tu32 ctrl = PL_CTRL_RES_1080P;",
    )
    pl.write_text(p, encoding="utf-8")
    print("pl_isp.c updated")
