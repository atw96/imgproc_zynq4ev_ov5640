# imgproc_zynq4ev_ov5640 — Zynq UltraScale+ MPSoC image processing (OV5640 MIPI)

## Overview

**imgproc_axu4evb_ov5640** is a real-time imaging pipeline for the **ALINX AXU4EVB** carrier with **ACU4EV** module (XCZU4EV) and **ALINX AV5641** camera (OV5640, **2-lane MIPI CSI-2**). This repository snapshot contains a **Vivado 2020.1** project and a **Vitis 2020.1** workspace (platform + bare-metal app).

## Features

- **MIPI CSI-2 capture**: RAW10 from OV5640 via MIPI CSI-2 RX Subsystem.
- **ISP preprocessing**: defective-pixel handling, black level, white balance, demosaic, gamma (see `img_preprocessor.v`).
- **Enhancement**: 11×11 local detail enhancement, 5×5 bilateral filter, CLAHE.
- **PS DDR buffering**: AXI HP masters for display path and line-buffer path (ping-pong style usage in `ddr3_pixel_buf` / `zynq_display_ctrl` — module names retain “ddr3” legacy naming).
- **HDMI display**: 1080p60 grayscale via **ADV7511** (148.5 MHz pixel clock from BD MMCM).
- **Ethernet frame streaming**: PL `frame_eth_tx` produces an AXI-Stream byte stream → **AXI DMA S2MM** → PS DDR; optional **LwIP RAW/UDP** path in `eth_stream.c` (requires matching BSP symbols).

### Data path (high level)

```
OV5640 MIPI CSI-2 → MIPI RX Subsystem → sensor_if → img_preprocessor
    → line_buffer_ctrl → local_detail_enhance_11x11 → bilateral_filter
    → clahe_engine → ddr3_pixel_buf (AXI HP1) → zynq_display_ctrl (AXI HP0) → HDMI
                  → frame_eth_tx (AXIS) → AXI DMA → PS DDR → (LwIP UDP) → PC
```

## Requirements

| Item | Notes |
|------|--------|
| Silicon | XCZU4EV-SFVC784-2-I (ALINX ACU4EV SOM) |
| Board | ALINX AXU4EVB-P (or compatible) |
| Camera | ALINX AV5641 (OV5640, MIPI CSI-2 2-lane) |
| Tools | **Vivado 2020.1**, **Vitis 2020.1** |
| Host OS | Windows or Linux (tool-supported) |
| Ethernet | PS GEM3 + **RTL8211FD** RGMII (typical on this board) |
| HDMI | **ADV7511** parallel RGB |

## Repository layout

This tree is intentionally minimal: generated IP output and large binaries may live under `vivado_project/` and `vitis_project/`.

```
imgproc_zynq4ev_ov5640/
├── LICENSE
├── README.md
├── vivado_project/
│   ├── imgproc_zynq4ev_ov5640.xpr          # Open this in Vivado
│   └── imgproc_zynq4ev_ov5640.srcs/
│       ├── constrs_1/imports/files/
│       │   └── imgproc_axu4evb_ov5640.xdc  # Pin + timing constraints (PL)
│       └── sources_1/
│           ├── bd/zynq_imgproc_bd/         # Block Design + generated wrapper
│           └── imports/sources_1/
│               ├── rtl_top/
│               │   └── imgproc_top_ov5640.v
│               ├── project/src/            # ISP / display / DMA tap RTL
│               └── common/                 # axil_cfg_reg, FIFO/BRAM helpers, …
└── vitis_project/
    ├── sdx_export_metadata/export.json     # Vitis metadata (paths may be stale)
    ├── zynq_imgproc_platform/              # Exported platform + BSP + FSBL/PMU
    ├── imgproc_baremetal/                  # Bare-metal application
    │   └── src/                            # main.c, eth_stream.c, pl_iic_ov5640.c, …
    └── imgproc_baremetal_system/           # Optional system project wrapper
```

> **Note:** Older docs referred to a separate `vivado/` folder with `create_project_ov5640.tcl` and a `vitis/` folder with XSCT scripts. **Those paths are not present in this repository.** Recreate or migrate flows using the checked-in Vivado project and Vitis workspace above.

## Vivado flow

1. Launch **Vivado 2020.1**.
2. Open `vivado_project/imgproc_zynq4ev_ov5640.xpr`.
3. If you changed the Block Design, **Validate Design** → **Generate Block Design** as needed, then **Generate Bitstream**.
4. **File → Export → Export Hardware** (include bitstream when required). Save the **`.xsa`** where your Vitis workspace can reference it (this repo may not track `.xsa` in Git).

Top-level PL RTL is **`imgproc_top_ov5640`** (`rtl_top/imgproc_top_ov5640.v`), instantiating the BD wrapper and the ISP pipeline.

## Vitis flow

1. Ensure the **hardware export (`.xsa`)** matches the Vivado build you intend to run.
2. Open **Vitis 2020.1** and use workspace directory `vitis_project/` (or copy the platform/app into your own workspace).
3. Typical contents:
   - **Platform:** `zynq_imgproc_platform` (BSP under `psu_cortexa53_0/standalone_psu_cortexa53_0/bsp/…`)
   - **Application:** `imgproc_baremetal` — sources in `vitis_project/imgproc_baremetal/src/`
4. **BSP:** enable **lwIP** with **RAW API** if you use `eth_stream.c`. After BD or address map changes, **re-generate the BSP** so `xparameters.h` stays consistent.
5. Build the application, create a **Run configuration** targeting your board, and download **bitstream + ELF**.

### Application entry (`main.c`)

- Initializes PL **AXI IIC**, probes OV5640, runs **minimal register init**, then calls `eth_stream_main()` (DMA + UDP path is conditional on BSP defines — see below).

## Block Design (reference)

The BD is **`zynq_imgproc_bd`** (sources under `vivado_project/.../bd/zynq_imgproc_bd/`). Typical programmable logic peripherals (addresses from the exported BSP in this tree):

| Instance / role | Function | Base address (example BSP) |
|-----------------|----------|----------------------------|
| `zynq_ultra_ps_e_0` | PS, clocks, GEM3, UART, etc. | — |
| `mipi_csi2_rx_subsystem_0` | MIPI CSI-2 RX (RAW10) | `0xA0030000` |
| `axi_iic_0` | OV5640 I2C | `0xA0010000` |
| `axi_gpio_0` | Sensor GPIO (e.g. pwdn) | `0xA0020000` |
| `axi_dma_eth` / `axi_dma_0` | AXI DMA **S2MM** for Ethernet frame sink | `0xA0040000` |
| `M_AXIL_CFG` → `imgproc_top` | AXI4-Lite ISP / display config | `0xA0000000` |
| SmartConnect / HP slaves | HP0 (display), HP1 (line buffer), HP2 (DMA) | DDR linear map from PS |

Exact names may vary slightly per BD revision; always cross-check **`xparameters.h`** in your BSP after export.

## AXI4-Lite register map (`imgproc_top` / `axil_cfg_reg`)

| Offset | Name | Fields | Description |
|--------|------|--------|----------------|
| `0x000` | `r_fb_addr_a` | `[31:0]` | Frame buffer A base (DDR) |
| `0x004` | `r_fb_addr_b` | `[31:0]` | Frame buffer B base |
| `0x008` | `r_ctrl` | `[0]` start, `[2:1]` `res_sel`, `[7:4]` `frame_skip` | Control |
| `0x00C` | `r_black_level` | `[12:0]` | Black level |
| `0x010`–`0x018` | `r_wb_gain_*` | `[11:0]` | R/G/B white balance gains |
| `0x01C` | `r_gamma_wr` | `[20:13]` addr, `[12:0]` data | Gamma LUT write |
| `0x020` | `r_ddr3_base` | `[31:0]` | Line-buffer DDR base |
| `0x024` | `r_sy_lut` | `[22:13]` addr, `[12:0]` data | Detail-enhancement LUT write |
| `0x200` | `status[0]` | `[31:0]` | Dead-pixel count (design-dependent packing) |
| `0x204` | `status[1]` | `[0]` | Buffer select / status bit |

## Ethernet / UDP framing (application)

Defaults in `eth_stream.c` (adjust to your network):

- Board / host IPs: **`192.168.1.10`** → **`192.168.1.100`**
- UDP ports: destination **5000**, source **5001**
- PL frame: **8-byte header** (`0xAA 0x55`, frame id, width, height) + **1920×1080** bytes luma
- UDP payload: **8-byte chunk header** + up to **1392** bytes data; **1400** bytes max application data per UDP packet

### BSP / preprocessor guard

`eth_stream.c` is wrapped in `#if defined(XPAR_XEMACPS_3_BASEADDR) && defined(XPAR_AXIDMA_0_DEVICE_ID)`. Some BSPs map **PS Ethernet 3** as **`XPAR_XEMACPS_0_*`** (single GEM instance index). If UDP streaming is skipped at compile time, align the **preprocessor condition** with your **`xparameters.h`** (or regenerate BSP after enabling GEM3 + lwIP + DMA).

## Board bring-up checklist

1. **Camera FPC**: seat AV5641 on the board FPC connector per your carrier manual (historical docs cite **J23** — verify against **your** schematic revision).
2. **HDMI** to a monitor; **Ethernet** to PC with compatible subnet.
3. **UART**: typical PS UART0 for logs (baud **115200 8N1** — confirm MIO mapping in your BD).
4. Download **bitstream** and **ELF** from Vitis.

## Design notes (constraints / timing)

1. **MIO / SD vs UART**: If SD and UART share MIOs on your board, the BD may disable SD in favor of UART; FSBL/boot flow may still use SD depending on your image — reconcile with **your** PS configuration.
2. **HDMI / pclk 148.5 MHz**: Bank 66 **LVCMOS33** IO logic has limits; this design keeps key HDMI outputs **registered in fabric** rather than forced **IOB** packing — see comments in `imgproc_axu4evb_ov5640.xdc`.
3. **MIPI DPHY 200 MHz ref**: Provided via BD clocking (see BD / IP XDC); do not duplicate conflicting `CLOCK_BUFFER_TYPE` hacks from older Vivado releases.
4. **OV5640 init**: `Ov5640_InitMinimal()` is intentionally small; extend register tables for production tuning.
5. **Hardware export**: After any BD or PL-top change, re-export **`.xsa`**, refresh the Vitis **platform**, and rebuild the **BSP** and application.

## License

See `LICENSE` in the repository root.
