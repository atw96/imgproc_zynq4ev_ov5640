# JTAG Programming Guide (AXU4EV + imgproc_baremetal)

## Reference projects (do not cross-mix)

| Path | Purpose |
|------|---------|
| `doc/factory_vivado/board_test` | Factory demo — DDR / psu_init reference **only** |
| `doc/.../psu_init.tcl` (~894KB) | Full DDR init; **no PS GEM3** — do not replace this project's file |
| This project `vitis_project/.../psu_init.tcl` (~659KB) | Includes **GEM3/ENET3** (matches `files/create_bd_ov5640.tcl`) |

`apply_alinx_ddr` once failed and left psu_init partially regenerated. If XSCT `psu_init` errors or hangs, run:

```bat
vivado_proj\regen_psu_init_and_sync.bat
```

## Recommended flows

### A. Vivado already programmed device (DONE=HIGH)

1. **Close** Vivado Hardware Manager (releases JTAG).
2. Do NOT run scripts that `taskkill hw_server`.
3. Execute:

```bat
cd vitis_project
deploy.bat program-elf
```

Internally uses `program_post_vivado.tcl`: `stop A53` → `psu_init` → `dow` → `con`.

### B. Fully automatic (batch Vivado + XSCT)

```bat
cd vitis_project
deploy.bat program-auto
```

### C. XSCT only (no Vivado GUI)

Close Vivado, then:

```bat
deploy.bat program
```

Uses `program_jtag.tcl` (no `rst-system`; `psu_init` before `fpga`).

## Prohibited

- **Do not** overwrite this project's `psu_init.tcl` with the factory version (loses GEM3).
- **Do not** repeatedly `rst -system` + multiple `psu_init` rounds (prone to `Channel closed` / hang at `0xFFCA5000`).
- **Do not** `_kill_hw_server` immediately after Vivado Program then switch to XSCT.

## Serial port

`<COMx>`, 115200. Expected output:

```
=== imgproc baremetal: AXI IIC + OV5640 ===
[ETH] board <board_ip> -> <pc_ip>:<port>
```
