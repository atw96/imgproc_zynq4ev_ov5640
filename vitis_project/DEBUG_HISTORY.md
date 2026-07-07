# imgproc_mpsoc — Debug History & Current Status

**Platform:** ALINX AXU4EVB (ZU4EV) + OV5640 MIPI  
**Toolchain:** Vivado / Vitis 2020.1  
**Last updated:** 2026-07-07  

---

## Objective

Rebuild the PL bitstream and validate the ISP / MIPI pipeline end-to-end:

- **Bit A:** synthetic test pattern (`ISP_USE_TEST_RAW=1`) through the full ISP chain, Ethernet streaming to PC  
- **Bit B:** real OV5640 MIPI input (`ISP_USE_TEST_RAW=0`)

Target ISP chain (serial, single output fan-out):

```
Sensor → Bayer demosaic → WB → Gamma → YCbCr → Wiener 11×11 → CLAHE → HDMI + ETH
```

---

## Debug Timeline

### Phase 1 — Stale PL netlist (registers read `0xDEADC0DE`)

| Symptom | Root cause | Fix |
|---------|------------|-----|
| `0xA0000208+` returned `0xDEADC0DE` | Synthesis DCP older than RTL; deployed bitstream still had `NUM_RD_REGS=2` | Full `reset_run synth_1` + `impl_1`; verify synth DCP timestamp is newer than RTL before deploy |

### Phase 2 — Silent FPGA programming failures

| Symptom | Root cause | Fix |
|---------|------------|-----|
| JTAG burn appeared to succeed but PL unchanged | `program_jtag.tcl` swallowed errors | Explicit `fpga OK` logging; `exit 1` on failure |

### Phase 3 — Wrong bitstream copied into firmware workspace

| Symptom | Root cause | Fix |
|---------|------------|-----|
| Bit hash mismatch after `deploy.bat build` | Vitis `sysproj build` overwrote `hw/*.bit` with older XSA bit (same size, different content) | `deploy.bat build` now re-copies bit from `impl_1`; `sync_hw_from_vivado.tcl` adds size/hash checks |

### Phase 4 — DMA RxBuf all zeros (no Ethernet frames)

| Symptom | Root cause | Fix |
|---------|------------|-----|
| PL `eth_frames` incremented but PS `RxBuf` was zero; continuous `bad frame header` | `ETH_AXIS_S2MM_tkeep` left unconnected in RTL | Tie `eth_axis_tkeep = 1'b1` in top-level wrapper |

**Result after tkeep fix (Bit A):** UART showed `[ETH] sent frame 1 / 257 / 513 (1920×1080)`.

### Phase 5 — PS register write hang

| Symptom | Root cause | Fix |
|---------|------------|-----|
| Writing `0xA0000008` hung PS | Empty AXI write in `pl_isp.c` | Source selection moved to RTL generics; firmware no longer writes that register |

### Phase 6 — CLAHE MAP defect

| Symptom | Root cause | Fix |
|---------|------------|-----|
| CLAHE output corrupt / stall | MAP phase lacked tile BRAM replay | `clahe_engine` stores tiles in BRAM during COLLECT, replays during MAP |

**Workaround for Bit A:** `ETH_USE_CLAHE=0` — Ethernet taps bilateral output instead of CLAHE (HDMI still uses CLAHE).

### Phase 7 — RTL parameters & dual-bit build

| Change | Detail |
|--------|--------|
| Top-level generics | `ISP_USE_TEST_RAW`, `ETH_USE_CLAHE` promoted to module parameters |
| Bit A build script | `fix_dma_length_and_build.tcl` → `ISP_USE_TEST_RAW=1`, `ETH_USE_CLAHE=0` |
| Bit B build script | `build_bit_mipi.tcl` → `ISP_USE_TEST_RAW=0`, `ETH_USE_CLAHE=1` |

### Phase 8 — Board verification

| Bit | UART evidence | Status |
|-----|---------------|--------|
| **A (test_raw)** | `0x208` valid, `fifo_ovf=0`, `[ETH] sent frame N` | **Pass** (with ~50% frame-header errors) |
| **B (MIPI)** | `mipi_beat = 0x6F489A80` | **MIPI ingress pass**; later `dma_wait`, `eth_frames=0` |

### Phase 9 — PC image viewer (open)

| Symptom | Root cause |
|---------|------------|
| No image on local PC | Board not actively streaming at test time (0 UDP packets in 10 s on port 5002) |
| `recv_display.py` showed nothing | Script ran in headless / remote SSH session — `cv2.imshow` needs local Windows desktop |
| Port `<port>` bind conflict | Stale background `python.exe` (Session 0) held port `<port>` without displaying a window |
| Intermittent success | Historical logs show `sent frame` on UART, but `err ≈ ok` due to `bad frame header` (~50% drop) |

**PC network:** host PC NIC configured as `<pc_ip>/24`; board target `<board_ip>`; UDP port `<port>`.

---

## Current Status (as of 2026-07-07)

### Working

- Bit A bitstream rebuild with fresh synth/impl  
- JTAG programming with explicit success/fail reporting  
- Deploy pipeline copies correct `impl_1` bit after firmware build  
- PL DMA S2MM receives non-zero frame data (`tkeep` fix)  
- UART confirms Ethernet frame transmission (`sent frame N`) under Bit A  
- MIPI pixel beat counter non-zero under Bit B (`mipi_beat > 0`)  
- CLAHE tile BRAM replay implemented in RTL  
- Debug handoff doc and project skill updated  

### Partially working

- **Ethernet stream:** frames are sent from board, but ~50% fail header parse (`bad frame header`); effective UDP frame rate is low  
- **ETH vs HDMI path:** Ethernet currently bypasses CLAHE (`ETH_USE_CLAHE=0`); HDMI uses CLAHE — outputs are not identical  
- **PC viewer:** not verified live; last UDP listen test received **0 packets** (board likely not running / not on Bit A stream at that moment)  

### Not yet done

- Stable PC reception of full 1920×1080 frames via `recv_display.py`  
- Bit B MIPI → ISP → ETH end-to-end with sustained `sent frame`  
- RTL change: single CLAHE output fan-out to both HDMI and ETH (remove bilateral bypass)  
- Fix frame sync / SOF alignment to eliminate `bad frame header`  
- Optional: remove bilateral stage to match intended ISP chain  

### Artifact note

| Artifact | Content |
|----------|---------|
| `DEBUG_HANDOFF.md` | Session handoff (desensitized for public repo) |

---

The pipeline is **serial**, not two parallel ISPs. The perceived "split" comes from **output muxing**:

```
img_preprocessor (Bayer/WB/Gamma/YCbCr)
    → line_buffer → 11×11 Wiener → bilateral → FIFO → CLAHE
                                                          ├─→ HDMI (ddr3_pixel_buf → display)
                                                          └─→ ETH  (mux: clahe_Y or bilat_Y)
```

Current Bit A compiles ETH to **bilateral** (`ETH_USE_CLAHE=0`), not CLAHE.

---

## Recommended Next Steps

1. **Re-burn Bit A** (`fix_dma_length_and_build.tcl` → sync → build → program)  
2. **Confirm UART** shows continuous `[ETH] sent frame N` (not only `bad frame header`)  
3. **On local Windows desktop** (not remote SSH): configure host PC NIC for the board subnet, then run `recv_display.py`  
4. **Quick UDP check:** `recv_display.py` should report packets within 10 s while board is streaming  
5. **RTL:** set `ETH_USE_CLAHE=1`, remove bilateral bypass mux; resynthesize  
6. **Debug frame header:** align `clahe_sof` / `frame_eth_tx` SOF with DMA TLAST boundaries  

---

## Key Artifacts

| Artifact | Purpose |
|----------|---------|
| `serial_tkeep.log` | Bit A post-tkeep fix: `sent frame 1/257/513` |
| `serial_mipi2.log` | Bit B: `mipi_beat=0x6F489A80` |
| `serial_tail.log` | Recent: continuous `bad frame header` only |
| `DEBUG_HANDOFF.md` | Session handoff (needs UTF-8 cleanup) |
| `imgproc-zynq-debug` skill | Build/burn/BSP checklist |

---

## Summary

The project progressed from a completely broken state (stale netlist, silent JTAG failures, zero DMA data) to **board-side Ethernet transmission confirmed on UART**. The remaining gap is **PC-side reception and display** — blocked by timing (board not streaming during PC test), display environment (OpenCV needs local desktop), and a **~50% frame-header error rate** that throttles usable UDP throughput. MIPI ingress is verified; MIPI-to-ETH streaming is not yet stable.
