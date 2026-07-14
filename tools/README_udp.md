# UDP Image Receiver Usage

This directory contains tools for receiving the UDP-fragmented image stream from the board-side `eth_stream.c`.

Files:

- `udp_img_viewer.py` — Main receiver + display script (requires `numpy` + `opencv-python`).
- `start_udp_receiver.ps1` — Windows launcher (adds temporary firewall rule + Python).
- `run_full_flow.ps1` — One-click JTAG program + receiver start.
- `requirements.txt` — Python dependencies.

**Default UDP port: `<port>`** (chosen to avoid common conflicts on Windows).

## Quick start

1. Install dependencies:

```powershell
python -m pip install -r tools/requirements.txt
```

2. Receive only:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/start_udp_receiver.ps1
```

Or:

```bash
python tools/udp_img_viewer.py --bind 0.0.0.0 --port <port> --width 1920 --height 1080
```

3. Program board + receive (add `-ElfOnly` if Vivado already programmed bit):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_full_flow.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_full_flow.ps1 -ElfOnly
```

## Network

- Board target IP: `<pc_ip>` (defined as `ETH_DST_IP_STR` in `eth_stream.c`)
- Board target port: **<port>**
- Board IP is typically `<board_ip>`, confirm with `ping <board_ip>`

## Troubleshooting

- `WinError 10048`: Port in use — change `--port` or update `ETH_DST_PORT` in firmware.
- `WinError 10013`: Use `--bind 0.0.0.0` or run `start_udp_receiver.ps1` as Administrator.
