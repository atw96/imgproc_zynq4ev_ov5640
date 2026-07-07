# UDP 图像接收器使用说明

此目录包含接收板端 `eth_stream.c` UDP 分片图像流的工具。

文件：

- `udp_img_viewer.py`：主接收与显示脚本（依赖 `numpy` + `opencv-python`）。
- `start_udp_receiver.ps1`：Windows 启动脚本（临时防火墙规则 + Python）。
- `run_full_flow.ps1`：JTAG 上板 + 启动接收器一键流程。
- `requirements.txt`：Python 依赖。

**默认 UDP 端口：5002**（避开 Windows 上 `nidmsrv.exe` 常占用的 5000）。

## 快速开始

1. 安装依赖：

```powershell
python -m pip install -r tools/requirements.txt
```

2. 仅接收图像：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_udp_receiver.ps1
```

或：

```bash
python tools/udp_img_viewer.py --bind 0.0.0.0 --port 5002 --width 1920 --height 1080
```

3. 上板 + 接收（Vivado 已 Program bit 时加 `-ElfOnly`）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_full_flow.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_full_flow.ps1 -ElfOnly
```

## 网络

- 板端目标 IP：`<pc_ip>`（`eth_stream.c` 中 `ETH_DST_IP_STR`）
- 板端目标端口：**`<port>`**
- 板子 IP 一般为 `<board_ip>`，可用 `ping <board_ip>` 确认

## 常见问题

- `WinError 10048`：端口被占用，换 `--port` 或改板端 `ETH_DST_PORT`。
- `WinError 10013`：用 `--bind 0.0.0.0` 或以管理员运行 `start_udp_receiver.ps1`。
