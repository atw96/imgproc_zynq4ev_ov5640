# imgproc_mpsoc ISP — Debug Session Handoff

> **Date:** 2026-07-06 18:10
> **Project root:** `<repo_root>`
> **Platform:** ALINX AXU4EVB (ZU4EV) + OV5640 MIPI
> **Toolchain:** Vivado / Vitis 2020.1

---

## 1. Bitstream variants

| Bit | Build script | Generics | Notes |
|-----|-------------|----------|-------|
| `impl_1/imgproc_top_ov5640.bit` | `fix_dma_length_and_build.tcl` | `ISP_USE_TEST_RAW=1` `ETH_USE_CLAHE=0` | **Bit A**: test pattern through 11x11 + bilateral to ETH; CLAHE feeds DDR/HDMI. |
| `impl_1/imgproc_top_ov5640_mipi.bit` | `build_bit_mipi.tcl` | `ISP_USE_TEST_RAW=0` `ETH_USE_CLAHE=1` | **Bit B**: live MIPI sensor input, full ISP. |

**Note:** If impl synth DCP is older than RTL, run `reset_run synth_1` + `reset_run impl_1`.

After `deploy.bat build`, the bit is copied **from** `impl_1/*.bit` (the `sysproj build` step may otherwise overwrite `hw/*.bit` with the XSA's embedded bit).

---

## 2. Vivado build / notes

```bat
cd vivado_proj
vivado.bat -mode batch -source scripts\fix_dma_length_and_build.tcl
```

- `ETH_AXIS_S2MM_tkeep` tied to `1'b1` (otherwise DMA received all zeros).
- CLAHE `clahe_engine` MAP phase now replays tiles from BRAM (fixed stall).

---

## 3. Vitis flow

```bat
cd vitis_project
py -3 preflight_debug.py --fix
deploy.bat sync
deploy.bat build    :: re-copies impl bit after build
deploy.bat program  :: checks for fpga OK
```

- `program_jtag.tcl` exits with code 1 on `fpga` failure (not silently `catch`-ed).
- `program_jtag_norst.tcl` is **deprecated** — `burn_silent.bat` may report false success.
- `program_fpga_only.tcl` programs PL only; verify with register `0xA0000208` (should not be `0xDEADC0DE`).
- **Do not write `0xA0000008` from PS** — source selection moved to RTL `ISP_USE_TEST_RAW` generic.

---

## 4. Status register map (`NUM_RD_REGS=7`)

| Offset | Field |
|--------|-------|
| 0x200 | dead_cnt |
| 0x204 | eth_tx_frame_cnt + buf_sel |
| 0x208 | mipi_beat |
| 0x20C | mipi_pix |
| 0x210 | raw_pixel_cnt |
| 0x214 | clahe_pixel_cnt |
| 0x218 | fifo_ovf |

`0x208+` returning `0xDEADC0DE` means the PL has fewer `NUM_RD_REGS` than expected — check `hw/*.bit` is up-to-date.

---

## 5. UART log (115200 8N1)

```
[PL] ISP res=1080p (RTL defaults: test_raw+clahe_eth)
[PL] st ... raw=... mipi_beat=... clahe=... fifo_ovf=0
[PL] status[1]=0x.... (eth_frames/buf as 16b each)
[ETH] PL DMA mode (2073608 B/frame, wait TLAST)
[ETH] sent frame 1 (1920x1080)
```

2026-07-06 18:08 finding: with `tkeep` unconnected, PL reported `eth_frames=8` but PS saw `RxBuf=0` + `bad frame header`; after tieing `tkeep=1`, frames flow.

---

## 6. PC side

```powershell
.\setup_ps_eth.ps1   # Configure host NIC IP and static ARP entry for the board
cd ..\pc_viewer
py -3 recv_display.py --port <pc_udp_port>
```

Windows `WinError 10013`: run `netstat -ano | findstr :<pc_udp_port>`; UDP reserved range via `netsh interface ipv4 show excludedportrange protocol=udp`.

**2026-07-08 — Link verified:** board broadcasts to `<pc_subnet_broadcast>` with PS gradient fallback; packet monitor showed UDP frames on the host. PL DMA must be re-synthesized first (`pat_raw_ready=1`).

---

## 7. References

- `doc/course_s2/24_an5641_mipi_hdmi` — OV5640 reference design
- `doc/course_s2/09_ps_net` — PS Ethernet reference
- `imgproc-zynq-debug` skill (local agent workflow)
