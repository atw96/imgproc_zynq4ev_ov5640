# imgproc_mpsoc — Zynq UltraScale+ MPSoC 图像处理工程

## 工程名称

**imgproc_axu4evb_ov5640** — 基于 ALINX AXU4EVB 开发板的 OV5640 MIPI CSI-2 实时图像处理系统

## 功能描述

本工程在 Xilinx Zynq UltraScale+ MPSoC (XCZU4EV) 平台上实现了一套完整的实时图像处理流水线，涵盖从 MIPI 摄像头采集、ISP 预处理、高级图像增强到 HDMI 显示和以太网帧传输的全链路功能。

### 核心功能

- **MIPI CSI-2 图像采集**：通过 OV5640 摄像头模组（AV5641）的 2-lane MIPI CSI-2 接口采集 RAW10 图像数据
- **ISP 预处理流水线**：坏点校正 → 黑电平补偿 → 白平衡增益 → 去马赛克（Demosaic） → Gamma 校正
- **高级图像增强**：
  - 11×11 局部细节增强（Local Detail Enhancement）
  - 5×5 双边滤波（Bilateral Filter）
  - CLAHE 自适应直方图均衡化（Contrast Limited Adaptive Histogram Equalization）
- **DDR3 帧缓冲**：通过 AXI4 HP 接口实现 PS DDR 的乒乓缓冲，支持帧率匹配
- **HDMI 显示输出**：1080p60 灰度图像通过 ADV7511 HDMI 发送器输出，像素时钟 148.5 MHz
- **以太网帧流传输**：通过 AXI DMA S2MM + LwIP RAW API 将处理后的帧数据以 UDP 分片方式发送至 PC 端

### 系统架构

```
OV5640 MIPI CSI-2 → MIPI RX Subsystem → sensor_if → img_preprocessor
    → line_buffer_ctrl → local_detail_enhance_11x11 → bilateral_filter
    → clahe_engine → ddr3_pixel_buf (AXI4 HP1) → zynq_display_ctrl (AXI4 HP0) → HDMI
                   → frame_eth_tx (AXI Stream) → AXI DMA → PS DDR → LwIP UDP → PC
```

## 环境要求

| 项目 | 要求 |
|------|------|
| FPGA 器件 | XCZU4EV-SFVC784-2-I (ALINX ACU4EV 核心板) |
| 开发板 | ALINX AXU4EVB-P 底板 |
| 摄像头模组 | ALINX AV5641 (OV5640, MIPI CSI-2 2-lane) |
| Vivado | 2020.1 |
| Vitis | 2020.1 |
| 操作系统 | Windows 10/11（Vitis 工具链要求） |
| 以太网 PHY | RTL8211FD-CG (PS GEM3, RGMII) |
| HDMI 发送器 | ADV7511 |

## 编译步骤

### 第一步：Vivado 工程构建

1. 打开 Vivado 2020.1
2. 在 Tcl Console 中执行：
   ```tcl
   cd <工程路径>/vivado
   source create_project_ov5640.tcl
   ```
   或使用命令行：
   ```bash
   vivado -mode batch -source vivado/create_project_ov5640.tcl
   ```
3. 脚本将自动完成以下操作：
   - 创建 Vivado 工程（项目目录：`vivado_proj/`）
   - 添加所有 RTL 源文件
   - 添加约束文件（XDC）
   - 创建 Block Design（PS + MIPI RX + I2C + GPIO + DMA + SmartConnect）
   - 生成 BD Wrapper
   - 设置顶层模块为 `imgproc_top_ov5640`
4. 在 Vivado GUI 中执行综合和实现：
   - Run Synthesis → Run Implementation → Generate Bitstream
5. 导出硬件（含 Bitstream）：
   - File → Export → Export Hardware → Include Bitstream
   - 导出的 XSA 文件复制到 `vitis/` 目录，命名为 `imgproc_top_ov5640.xsa`

### 第二步：Vitis 工程构建

1. 确保已执行 Vivado 导出硬件步骤，`vitis/imgproc_top_ov5640.xsa` 文件存在
2. 在已加载 Vitis 环境的命令行中执行：
   ```bash
   cd <工程路径>/vitis
   xsct create_vitis_workspace.tcl
   ```
   或双击 `run_xsct_create.bat`（需设置 `XILINX_VITIS` 环境变量）
3. 脚本将自动完成以下操作：
   - 创建 Platform 工程（`zynq_imgproc_platform/`）
   - 配置 Standalone BSP（含 lwIP RAW API）
   - 创建裸机应用（`imgproc_baremetal/`）
   - 复制源代码并编译
4. 在 Vitis IDE 中打开工作区验证：
   - 确认 BSP 中 lwIP 库已启用（RAW API 模式）
   - 确认 AXI DMA 和 IIC 驱动与硬件匹配
   - 如有需要，在 BSP Settings 中手动添加 lwIP

### 第三步：板卡部署

1. 连接硬件：
   - AV5641 摄像头模组接到 FPC J23 接口
   - HDMI 输出接到显示器
   - 以太网口接到 PC（PC IP 设置为 192.168.1.100）
   - 串口连接（UART0, MIO42/43, 115200-8-N-1）
2. 在 Vitis 中配置 Run Configuration，下载 Bitstream 和 ELF
3. 串口终端将显示初始化信息，HDMI 显示处理后的图像

## 目录结构

```
imgproc_mpsoc/
├── vivado/                              # Vivado 工程源文件
│   ├── create_project_ov5640.tcl        # 主自动化脚本（创建工程 + 添加源码 + BD）
│   ├── create_bd_ov5640.tcl             # Block Design 创建脚本（PS + MIPI + 外设）
│   ├── imgproc_axu4evb_ov5640.xdc       # 引脚约束与时序约束
│   └── sources_1/                       # RTL 源码
│       ├── rtl_top/
│       │   └── imgproc_top_ov5640.v     # 顶层模块（BD Wrapper + ISP 流水线互连）
│       ├── project/src/
│       │   ├── bilateral_filter.v       # 5×5 双边滤波器
│       │   ├── clahe_engine.v           # CLAHE 自适应直方图均衡化引擎
│       │   ├── ddr3_pixel_buf.v         # DDR 乒乓帧缓冲控制器（AXI4 HP1）
│       │   ├── frame_eth_tx.v           # 以太网帧打包 + AXI-Stream 输出
│       │   ├── img_preprocessor.v       # ISP 预处理流水线
│       │   ├── k_lut_rom.v             # CLAHE 映射查找表 ROM
│       │   ├── line_buffer_ctrl.v       # 11 行行缓冲控制器
│       │   ├── local_detail_enhance_11x11.v  # 11×11 局部细节增强
│       │   ├── sensor_if.v             # 传感器接口（支持 DVP/MIPI 模式）
│       │   ├── vga_timing_gen.v        # VGA 时序发生器
│       │   └── zynq_display_ctrl.v     # 显示控制器（AXI4 HP0 帧写入 + VGA 时序）
│       └── common/
│           ├── axil_cfg_reg.v          # AXI4-Lite 配置寄存器模块
│           ├── shift_reg.v            # 移位寄存器
│           └── ram/
│               ├── fifo_async.v        # 异步 FIFO
│               ├── fifo_sync.v         # 同步 FIFO
│               ├── ram_lutram.v        # LUT RAM（分布式 RAM）
│               ├── ram_sdp_bram.v      # 简单双端口 BRAM
│               ├── ram_sp_bram.v       # 单端口 BRAM
│               └── ram_tdp_bram.v      # 真双端口 BRAM
├── vitis/                               # Vitis 工程源文件
│   ├── create_vitis_workspace.tcl       # XSCT 自动化脚本（创建 Platform + App）
│   ├── run_xsct_create.bat             # Windows 批处理（自动定位 Vitis 并调用 XSCT）
│   ├── imgproc_top_ov5640.xsa          # Vivado 硬件导出文件
│   └── .regen_backup/
│       └── imgproc_baremetal_src/       # 裸机应用源码备份
│           ├── main.c                  # 主入口（I2C 初始化 + OV5640 配置 + 以太网流）
│           ├── eth_stream.c            # AXI DMA 帧接收 + LwIP UDP 分片发送
│           ├── eth_stream.h            # 以太网流接口声明
│           ├── pl_iic_ov5640.c         # PL AXI IIC 驱动 + OV5640 寄存器读写
│           ├── pl_iic_ov5640.h         # IIC/OV5640 接口声明
│           ├── lscript.ld              # 链接脚本（ARM v8, DDR + OCM）
│           ├── I2C_README.txt          # I2C 使用说明
│           └── README.txt              # 应用说明
└── doc/                                 # 参考文档
    ├── ACU4EV核心板原理图.pdf           # 核心板原理图
    ├── AXU4EVB-P开发板原理图.pdf        # 底板原理图
    ├── ADV7511.pdf                      # ADV7511 数据手册
    ├── ADV7511_Hardware_Users_Guide.pdf # ADV7511 硬件用户指南
    ├── ADV7511_Programming_Guide.pdf    # ADV7511 编程指南
    ├── RTL8211FD-CG.pdf                # 以太网 PHY 数据手册
    ├── course_s1_*.pdf                  # FPGA 教程
    ├── course_s2_*.pdf                  # Vitis 应用教程
    ├── course_s3_*.pdf                  # Linux 基础教程
    ├── course_s4_*.pdf                  # Linux 驱动教程
    └── course_s5_*.pdf                  # Linux 应用程序开发
```

## Block Design 架构

BD（Block Design）由 `create_bd_ov5640.tcl` 自动创建，包含以下 IP 核：

| IP 核 | 功能 | 地址映射 |
|-------|------|----------|
| zynq_ultra_ps_e_0 | PS 端配置（UART0, ENET3, PL时钟等） | — |
| mipi_csi2_rx_subsystem_0 | MIPI CSI-2 2-lane 接收（RAW10, 2pix/clk） | 0xA0030000 |
| axi_iic_0 | OV5640 I2C 寄存器配置（400 kHz） | 0xA0010000 |
| axi_gpio_0 | OV5640 控制（reset_n[0], pwdn[1]） | 0xA0020000 |
| axi_dma_eth | AXI DMA S2MM（以太网帧写入 PS DDR） | 0xA0040000 |
| axi_sc_cfg | SmartConnect 1→5（PS HPM0 → 配置总线） | — |
| axi_sc_hp0 | SmartConnect 1→1（display_ctrl → HP0） | — |
| axi_sc_hp1 | SmartConnect 1→1（ddr3_pixel_buf → HP1） | — |
| axi_sc_hp2 | SmartConnect 1→1（AXI DMA → HP2） | — |
| clk_wiz_0 | MMCM: 150 MHz → 148.5 MHz（HDMI pclk） | — |
| clk_wiz_mipi_ref | MMCM: 150 MHz → 200 MHz（MIPI DPHY 参考） | — |
| rst_ps8_0_150m | PL 时钟域复位 | — |
| rst_pclk_0 | 像素时钟域复位（MMCM locked） | — |
| xlslice_rst/pwdn | GPIO 位拆分 | — |

### 地址映射

| 外设 | 基地址 | 大小 |
|------|--------|------|
| imgproc_top AXI-Lite 配置 | 0xA0000000 | 4 KB |
| AXI IIC | 0xA0010000 | 4 KB |
| AXI GPIO | 0xA0020000 | 4 KB |
| MIPI CSI-2 RX 控制 | 0xA0030000 | 8 KB |
| AXI DMA ETH 控制 | 0xA0040000 | 64 KB |
| HP0 DDR (display_ctrl) | 0x00000000 | 2 GB |
| HP1 DDR (ddr3_pixel_buf) | 0x00000000 | 2 GB |
| HP2 DDR (AXI DMA) | 0x00000000 | 2 GB |

## AXI4-Lite 配置寄存器映射

| 偏移 | 名称 | 位域 | 功能 |
|------|------|------|------|
| 0x000 | r_fb_addr_a | [31:0] | 帧缓冲 A 地址 |
| 0x004 | r_fb_addr_b | [31:0] | 帧缓冲 B 地址 |
| 0x008 | r_ctrl | [0] cfg_start, [2:1] res_sel, [7:4] frame_skip | 控制寄存器 |
| 0x00C | r_black_level | [12:0] | 黑电平值 |
| 0x010 | r_wb_gain_r | [11:0] | 红通道白平衡增益 |
| 0x014 | r_wb_gain_g | [11:0] | 绿通道白平衡增益 |
| 0x018 | r_wb_gain_b | [11:0] | 蓝通道白平衡增益 |
| 0x01C | r_gamma_wr | [20:13] addr, [12:0] data | Gamma LUT 写入 |
| 0x020 | r_ddr3_base | [31:0] | DDR3 乒乓缓冲基地址 |
| 0x024 | r_sy_lut | [22:13] addr, [12:0] data | 细节增强 LUT 写入 |
| 0x200 | status[0] | [31:0] | 坏点计数 |
| 0x204 | status[1] | [0] | 当前缓冲选择 |

## 以太网帧传输协议

- 板卡 IP: 192.168.1.10, 目标 PC IP: 192.168.1.100
- 目标端口: 5000, 源端口: 5001
- 帧格式: 8 字节帧头 (0xAA55 + frame_id + width + height) + 像素数据
- UDP 分片: 8 字节分片头 (frame_id + chunk_idx + total_chunks + reserved) + 1392 字节数据
- MTU 数据: 1400 字节/包

## 注意事项

1. **SD 卡冲突**：PS SD1（MIO39-51）与 UART0（MIO42-43）存在 MIO 复用冲突，BD 中 SD1 已禁用，但硬件 SD 仍可通过 FSBL/U-Boot 使用
2. **HDMI 时序**：像素时钟 148.5 MHz 由 MMCM 从 PS PL_CLK0 (150 MHz) 生成，Bank 66 LVCMOS33 的 HDIOLOGIC 不支持 148.5 MHz IOB 寄存，输出 FF 保留在 Fabric
3. **MIPI DPHY 参考**：MIPI DPHY 200 MHz 参考时钟由独立 MMCM（clk_wiz_mipi_ref）生成，不与 HDMI MMCM 共用
4. **Vitis BSP**：首次创建后需确认 lwIP 库已启用（RAW API 模式），如未自动启用请在 BSP Settings 中手动添加
5. **OV5640 初始化**：当前仅实现最小初始化序列（软件复位 + 时钟配置），完整传感器配置需补充寄存器写入列表
6. **XSA 文件**：`vitis/imgproc_top_ov5640.xsa` 为 Vivado 导出的硬件描述文件，修改 BD 后需重新导出并替换此文件
