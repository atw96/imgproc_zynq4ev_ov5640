# imgproc_zynq4ev_ov5640 — Zynq UltraScale+ MPSoC image processing (OV5640 MIPI)

## Overview

**imgproc_axu4evb_ov5640** is a real-time imaging pipeline for the **ALINX AXU4EVB** carrier with **ACU4EV** module (XCZU4EV) and **ALINX AV5641** camera (OV5640, **2-lane MIPI CSI-2**). This repository snapshot contains a **Vivado 2020.1** project and a **Vitis 2020.1** workspace (platform + bare-metal app).

> **Repository cleanup notes:**
> - **Generated caches removed:** All Vivado `.Xil/`, `.sim/`, `.cache/` and Vitis `.metadata/`, `Debug/`, `Release/` directories have been purged.
> - **Temporary scripts removed:** Test/diagnostic scripts, temporary patches, and redundant build scripts have been cleaned up.
> - **Focus:** Ethernet + RTL demonstration (OV5640 MIPI input → ISP → DMA to PS → UDP frame streaming).
> - **Minimal size:** Repository now contains only essential sources, Tcl config, and IP metadata for reproducible builds.

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

This repository is **minimal and cache-free**. After cleanup:
- **No generated Vivado build outputs** (`imgproc_*.cache/`, `imgproc_*.sim/`, `.Xil/`, `.runs/` are excluded from Git).
- **No Vitis build outputs** (`Debug/`, `Release/`, `.metadata/`, `.sdk/` are excluded from Git).
- **No temporary scripts** (test/diagnostic/patch scripts have been removed).
- **Only essential sources** tracked: Tcl BD config, RTL sources, BSP/platform descriptors, and application code.

Typical checked-in structure:

```
imgproc_zynq4ev_ov5640/
├── LICENSE
├── README.md
├── doc/                           # Documentation (optional history)
├── files/                         # RTL and constraint sources
│   ├── sources_1/
│   │   ├── rtl_top/              # Top-level RTL
│   │   ├── project/src/          # ISP & display pipeline RTL
│   │   └── common/               # Utility modules (FIFO, BRAM, AXI helpers)
│   └── imgproc_axu4evb_ov5640.xdc  # Pin & timing constraints
├── vivado_proj/
│   ├── imgproc_zynq4ev_ov5640.xpr        # ✓ Vivado project file (OPEN THIS)
│   └── imgproc_axu4evb_ov5640.srcs/
│       ├── constrs_1/               # Constraints
│       └── sources_1/
│           ├── bd/zynq_imgproc_bd/  # Block Design (generates IP wrappers on-demand)
│           └── imports/
├── vitis_project/
│   ├── zynq_imgproc_platform/       # Exported platform + BSP
│   │   ├── hw/                      # HW metadata (device tree source templates)
│   │   └── sysroot/psu_cortexa53_0/standalone_psu_cortexa53_0/
│   │       └── bsp/                 # BSP libs & xparameters.h
│   ├── imgproc_baremetal/           # Bare-metal application
│   │   └── src/
│   │       ├── main.c               # Entry point, sensor init, UDP stream
│   │       ├── eth_stream.c         # AXI DMA + LwIP UDP UDP framing
│   │       ├── pl_iic_ov5640.c      # OV5640 I2C initialization
│   │       └── …
│   └── imgproc_baremetal_system/    # System project wrapper
├── pc_viewer/
│   ├── udp_test.py                  # PC-side UDP receiver (captures frames)
│   └── recv_display.py              # Display received frames (PIL/OpenCV)
├── tools/
│   ├── udp_img_viewer.py            # Standalone frame viewer
│   ├── run_full_flow.ps1            # Vivado → Vitis build flow (PowerShell)
│   └── start_udp_receiver.ps1       # Launch PC receiver daemon
└── boot_images/                     # (If present) Pre-built FSBL/PMU/Bitstream/ELF images
```

**Note on Git tracking:** The Vivado/Vitis projects are in Git, but their **generated output directories** (`.runs/`, `.cache/`, `Debug/`, etc.) are rebuilt automatically when you open the projects in Vivado/Vitis — they are **not** tracked and can be safely deleted to save space.

## Vivado flow

1. **Launch Vivado 2020.1.**
2. **Open the project:**
   ```
   vivado_proj/imgproc_zynq4ev_ov5640.xpr
   ```
3. **Verify / regenerate design** (if needed):
   - If Block Design was modified, open it: **File → Recent → Block Diagrams** or navigate to `vivado_proj/imgproc_zynq4ev_ov5640.srcs/sources_1/bd/zynq_imgproc_bd/zynq_imgproc_bd.bd`.
   - Right-click → **Validate Design**, then **Generate Block Design** if you changed connectivity.
   - The BD automatically generates IP wrappers under `vivado_proj/imgproc_zynq4ev_ov5640.ip_user_files/bd/…` (these can be deleted after build without harm — they regenerate on next HDL elaboration).
4. **Synthesize & place/route:**
   - **Flow → Run Synthesis** (uses RTL in `vivado_proj/imgproc_zynq4ev_ov5640.srcs/sources_1/…`).
   - **Flow → Run Implementation**.
   - **Flow → Generate Bitstream**.
5. **Export hardware:**
   - **File → Export → Export Hardware**.
   - Enable **Include Bitstream**.
   - Save the `.xsa` to a known location (e.g., `vivado_proj/` or a dedicated export folder).
   - The Vitis workspace will point to this `.xsa` to regenerate the platform and BSP.

**Top-level RTL:** `imgproc_top_ov5640.v` (in `files/sources_1/rtl_top/` or linked via Vivado sources). This module instantiates:
- Zynq UltraScale+ PS (via BD wrapper).
- ISP pipeline RTL modules (defect pixel, preprocessor, enhancement, DMA controllers).
- AXI4-Lite configuration register block.

**Timing:** See `imgproc_axu4evb_ov5640.xdc` for HDMI pclk (148.5 MHz) and MIPI reference clock constraints.

## Vitis flow

1. **Ensure hardware export (`.xsa`)** is up-to-date.
   - If you modified the Vivado design, re-export the `.xsa` and place it in a known path (e.g., `vivado_proj/`).
   
2. **Open Vitis 2020.1** and select workspace **`vitis_project/`.**
   - (Or copy `zynq_imgproc_platform/` and `imgproc_baremetal/` into your own Vitis workspace.)
   
3. **Update platform from new `.xsa`** (if you made changes):
   - In Vitis, right-click **`zynq_imgproc_platform`** → **Update Hardware Specification** → select your new `.xsa`.
   - The BSP will auto-regenerate, updating `xparameters.h` and device tree fragments.
   
4. **Verify BSP configuration:**
   - Expand **`zynq_imgproc_platform`** → **Board Support Package** → **zynq_imgproc_platform_bsp** → right-click → **Board Support Package Settings**.
   - Confirm **lwIP** and **AXI DMA** are enabled if you use the `eth_stream.c` path (or adjust preprocessor conditions in `eth_stream.c` if your BSP differs).
   
5. **Build the application:**
   - Right-click **`imgproc_baremetal`** → **Build Project**.
   - Output ELF: `imgproc_baremetal/Debug/imgproc_baremetal.elf` (or `Release/…` if configured).
   
6. **Run configuration & download to board:**
   - Create a **Run Configuration** targeting your Zynq board (JTAG or network connection).
   - Vitis will download: bitstream → PMU firmware → FSBL → application.
   - Monitor **UART0** (typically 115200 8N1) for startup messages.

### Application entry point (`main.c`)

- Initializes board peripherals: **AXI IIC** (camera control), **OV5640 minimal register setup**, **PS clocking**.
- Calls `eth_stream_main()` — implements **AXI DMA S2MM** capture path:
  - Configures **DMA** to receive frames from PL `frame_eth_tx` AXIS stream.
  - Formats frames into **8-byte header + 1920×1080 luma** per DMA descriptor.
  - Sends **UDP packets** to host PC (default `192.168.1.100:5000`).
- Falls back gracefully if **lwIP** or **DMA** not available (prints diagnostic messages).

### BSP & conditional compilation

`eth_stream.c` is wrapped in:
```c
#if defined(XPAR_XEMACPS_0_BASEADDR) && defined(XPAR_AXIDMA_0_DEVICE_ID)
  // lwIP + DMA UDP streaming enabled
#else
  // Fallback: skip streaming, run test patterns only
#endif
```

If UDP streaming is skipped at compile time, it typically means:
- **PS Ethernet** is not mapped in `xparameters.h`, or
- **AXI DMA** is not in the Block Design.

**Action:** Regenerate the BSP after enabling these IP cores in Vivado + exporting the new `.xsa`.

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
4. **Power-on sequence**: Zynq boots from **FSBL → PMU firmware → application**. Monitor UART0 for boot messages; if hung, check JTAG link and FSBL build.
5. Download **bitstream** and **ELF** from Vitis.

## Troubleshooting

### MIPI DPHY lock timeout or CSI-2 errors
- **Symptom:** UART shows `DPHY not locked` or sensor probe fails.
- **Check:** 
  - Ensure CSI-2 TX differential pairs are routed correctly on your carrier board.
  - Verify MIPI **reference clock** (200 MHz typical) is routed and termination is correct.
  - Check OV5640 **power rails** and **reset signal** via IIC init.
  - Try `Ov5640_StandbyMode(0)` to wake the sensor if it entered low-power mode.

### Ethernet link not negotiating (no UDP traffic)
- **Symptom:** UART shows "link down" or `lwIP_init()` fails; no packets reach PC.
- **Check:**
  - Verify **RTL8211FD PHY** is initialized correctly — check your **BD clocking** and **PS Ethernet MDIO/MDC** are routed.
  - Confirm **IP subnet** in `eth_stream.c` (default `192.168.1.10` for board, `.100` for PC).
  - Run `ping 192.168.1.10` from your PC; if timeout, check `arp -a` for ARP cache and try manual entry.
  - On Windows, use **Wireshark** to capture UDP on port 5000 to confirm packet arrival; if seen, issue is likely on frame-reception parsing.

### Bitstream download fails via JTAG
- **Symptom:** Vitis or `xsct` reports JTAG timeout or device not found.
- **Check:**
  - Verify **USB JTAG adapter** is plugged in and recognized by OS.
  - Check **hardware debugger connection** in Vitis (**Window → Show View → Target Connections**).
  - If using external JTAG server, confirm it is **running and listening** on the correct port (default **3121**).

### Application crashes or hangs after boot
- **Symptom:** ELF loads but UART prints stop, or application hangs at a known line.
- **Check:**
  - Look for **unhandled exception vectors** — check xparameters mapping of interrupts vs. application ISRs.
  - Confirm **DDR memory** initialization in FSBL and BSP are correct (wrong `ps7_init.tcl` or `psu_init.c` can cause crashes).
  - Add `xil_printf()` statements before suspected hang to narrow scope.

### DMA not capturing frames (black screen)
- **Symptom:** Bitstream and app load fine, but UDP packets are empty or misaligned.
- **Check:**
  - Verify **AXI DMA** is correctly connected to **`frame_eth_tx`** AXIS stream in BD.
  - Confirm DMA **S2MM** (slave) channel is correctly initialized — inspect `eth_stream.c` for `XAxiDma_SimpleTransfer()` calls.
  - Monitor DMA status registers for **errors** (XST_DMA_ERROR) via `xil_printf()`.
  - If frames are shifted or corrupted, check **AXI bus width** and **endianness** alignment.

## Design notes (constraints / timing)

1. **MIO / SD vs UART**: If SD and UART share MIOs on your board, the BD may disable SD in favor of UART; FSBL/boot flow may still use SD depending on your image — reconcile with **your** PS configuration.
2. **HDMI / pclk 148.5 MHz**: Bank 66 **LVCMOS33** IO logic has limits; this design keeps key HDMI outputs **registered in fabric** rather than forced **IOB** packing — see comments in `imgproc_axu4evb_ov5640.xdc`.
3. **MIPI DPHY 200 MHz ref**: Provided via BD clocking (see BD / IP XDC); do not duplicate conflicting `CLOCK_BUFFER_TYPE` hacks from older Vivado releases.
4. **OV5640 init**: `Ov5640_InitMinimal()` is intentionally small; extend register tables for production tuning (sensor is capable of higher frame rates and color modes with proper tuning).
5. **ISP pipeline throughput**: The design captures continuous frames at ~30 fps (1920×1080). Bottlenecks may arise if Ethernet bandwidth is saturated or if PL frame rate exceeds DMA output rate — add buffering as needed.
6. **Hardware export**: After any BD or PL-top change, re-export **`.xsa`**, refresh the Vitis **platform**, and rebuild the **BSP** and application.

## Building from command line (optional)

### Vivado (standalone)
```bash
vivado -mode batch -source <build_script>.tcl -nojournal -nolog
```
Example scripts in `vivado_proj/` (or `files/`; check for `create_project_ov5640.tcl` or `create_bd_ov5640.tcl`).

### Vitis (XSCT shell)
```tcl
# Open existing workspace
xsct
workspace /path/to/vitis_project
platform create -name zynq_imgproc_platform -hw /path/to/imgproc_top_ov5640.xsa -proc psu_cortexa53_0 -os standalone
app create -name imgproc_baremetal -platform zynq_imgproc_platform -template {Bare Metal Application}
app build -name imgproc_baremetal
```

(Adjust paths and names to match your setup.)

## License

See `LICENSE` in the repository root.
