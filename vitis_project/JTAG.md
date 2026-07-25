# JTAG 烧录说明（AXU4EV + imgproc_baremetal）

## 参考工程（勿混用）

| 路径 | 用途 |
|------|------|
| `doc/factory_vivado/board_test` | 工厂 DEMO，**仅对照 DDR / psu_init 流程** |
| `doc/.../psu_init.tcl` (~894KB) | 含完整 DDR 初始化；**无 PS GEM3**，不能整文件替换本工程 |
| 本工程 `vitis_project/.../psu_init.tcl` (~659KB) | 含 **GEM3/ENET3**（与 `files/create_bd_ov5640.tcl` 一致） |

`apply_alinx_ddr` 曾失败导致 psu_init 未完整重新生成。若 XSCT `psu_init` 报错或卡住，先运行：

```bat
vivado_proj\regen_psu_init_and_sync.bat
```

## 推荐流程（Vivado 能连 JTAG 时）

### A. 你已在 Vivado 里 Program Device（DONE=HIGH）

1. **关闭** Vivado Hardware Manager（释放 JTAG）
2. 不要运行会 `taskkill hw_server` 的脚本
3. 执行：

```bat
cd vitis_project
deploy.bat program-elf
```

内部使用 `program_post_vivado.tcl`：`stop A53` → `psu_init` → `dow` → `con`（与 2026_5_28 手动 XSCT 一致）。

### B. 全自动（batch Vivado + XSCT）

```bat
cd vitis_project
deploy.bat program-auto
```

### C. 仅 XSCT（无 Vivado GUI）

关闭 Vivado 后：

```bat
deploy.bat program
```

使用 `program_jtag.tcl`（无 `rst-system`，先 `psu_init` 再 `fpga`）。

## 禁止

- **不要**用 `factory` 的 `psu_init.tcl` 覆盖本工程（会丢掉 GEM3）
- **不要**反复 `rst -system` + 多轮 `psu_init`（易 `Channel closed` / 卡 `0xFFCA5000`）
- **不要**在 Vivado Program 后立刻 `_kill_hw_server` 再 XSCT

## Serial console

COM port at 115200 8N1, expected boot banner:

```
=== imgproc baremetal: AXI IIC + OV5640 ===
[ETH] board <board_ip> -> <pc_ip>:<pc_udp_port>
```

The actual COM port number, board/PC IPs, and UDP port are configured in `eth_stream.c` and `tools/README_udp.md`; use repo-relative placeholders rather than hard-coded local values.
