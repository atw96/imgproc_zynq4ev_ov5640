#!/usr/bin/env python3
"""
ZynqMP imgproc UDP 帧接收显示器
接收板端发来的 1920x1080 灰度帧并实时显示
用法: python recv_display.py [--port 5010]
依赖: pip install opencv-python numpy
"""
import argparse
import socket
import struct
import subprocess
import sys
import numpy as np
import cv2
import time
import threading

# ---- 配置 ----
BIND_IP      = ""
DEFAULT_PORT = 5010
FALLBACK_PORTS = [5010, 5020, 5100, 5200, 7002]
IMG_W        = 1920
IMG_H        = 1080
CHUNK_HDR_SZ = 8
EXPECTED_BYTES = IMG_W * IMG_H * 4  # RGBX

frame_buf   = {}
frame_total = {}
last_frame  = None
lock        = threading.Lock()
stats       = {"rx": 0, "ok": 0, "drop": 0, "fps": 0.0}
listen_port = DEFAULT_PORT


def diagnose_bind_error(port: int, err: OSError) -> None:
    print(f"[RX] bind UDP {port} failed: {err}", file=sys.stderr)
    if getattr(err, "winerror", None) == 10013:
        print("[RX] WinError 10013: port in use or in excluded range", file=sys.stderr)
    try:
        out = subprocess.check_output(
            f'netstat -ano | findstr ":{port} "',
            shell=True, text=True, errors="replace",
        )
        if out.strip():
            print(f"[RX] netstat:\n{out}", file=sys.stderr)
    except Exception:
        pass
    try:
        excl = subprocess.check_output(
            "netsh interface ipv4 show excludedportrange protocol=udp",
            shell=True, text=True, errors="replace",
        )
        print(f"[RX] UDP excluded ranges:\n{excl}", file=sys.stderr)
    except Exception:
        pass


def try_bind_udp(port: int) -> socket.socket:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
    sock.bind((BIND_IP, port))
    return sock


def open_udp_socket(preferred: int) -> socket.socket:
    ports = [preferred] + [p for p in FALLBACK_PORTS if p != preferred]
    last_err = None
    for port in ports:
        try:
            sock = try_bind_udp(port)
            global listen_port
            listen_port = port
            print(f"[RX] listening on UDP {BIND_IP or '0.0.0.0'}:{port}")
            return sock
        except OSError as e:
            last_err = e
            diagnose_bind_error(port, e)
    raise SystemExit(f"[RX] all ports failed, last error: {last_err}")


def recv_loop(sock: socket.socket):
    t0 = time.time()
    fps_cnt = 0
    while True:
        try:
            data, _ = sock.recvfrom(65535)
        except Exception as e:
            print(f"[RX] recv error: {e}")
            continue
        if len(data) < CHUNK_HDR_SZ:
            continue
        fid, cidx, total, _ = struct.unpack_from(">HHHH", data, 0)
        payload = data[CHUNK_HDR_SZ:]
        stats["rx"] += 1
        with lock:
            if fid not in frame_buf:
                old = [k for k in frame_buf if (fid - k) % 65536 > 10]
                for k in old:
                    del frame_buf[k]
                    frame_total.pop(k, None)
                frame_buf[fid] = {}
                frame_total[fid] = total
            frame_buf[fid][cidx] = payload
            if len(frame_buf[fid]) == frame_total.get(fid, -1):
                chunks = frame_buf.pop(fid)
                frame_total.pop(fid, None)
                raw = b"".join(chunks[i] for i in range(total))
                if len(raw) >= EXPECTED_BYTES:
                    rgba = np.frombuffer(raw[:EXPECTED_BYTES], dtype=np.uint8).reshape(
                        (IMG_H, IMG_W, 4)
                    )
                    arr = rgba[:, :, [2, 1, 0]].copy()  # BGR for OpenCV
                    global last_frame
                    last_frame = arr
                    stats["ok"] += 1
                    fps_cnt += 1
                    now = time.time()
                    if now - t0 >= 1.0:
                        stats["fps"] = fps_cnt / (now - t0)
                        fps_cnt = 0
                        t0 = now
                else:
                    stats["drop"] += 1


def main():
    parser = argparse.ArgumentParser(description="ZynqMP imgproc UDP viewer")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()
    sock = open_udp_socket(args.port)
    threading.Thread(target=recv_loop, args=(sock,), daemon=True).start()
    cv2.namedWindow("ZynqMP 1920x1080 RGB", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("ZynqMP 1920x1080 RGB", 960, 540)
    print("[VIEW] press Q to quit")
    prev_ok = 0
    while True:
        with lock:
            frame = last_frame.copy() if last_frame is not None else None
        if frame is not None:
            disp = frame
            cv2.putText(disp, f"Frame={stats['ok']}  FPS={stats['fps']:.1f}  drop={stats['drop']}",
                        (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 2)
            cv2.imshow("ZynqMP 1920x1080 RGB", disp)
            if stats["ok"] != prev_ok:
                prev_ok = stats["ok"]
                print(f"\r[VIEW] ok={stats['ok']}  fps={stats['fps']:.1f}  rx={stats['rx']}  drop={stats['drop']}",
                      end="", flush=True)
        else:
            blank = np.zeros((540, 960, 3), dtype=np.uint8)
            cv2.putText(blank, f"Waiting UDP {BIND_IP or '0.0.0.0'}:{listen_port} from 10.0.0.10...",
                        (60, 270), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 200, 255), 2)
            cv2.imshow("ZynqMP 1920x1080 RGB", blank)
        key = cv2.waitKey(30) & 0xFF
        if key in (ord('q'), ord('Q'), 27):
            break
    cv2.destroyAllWindows()
    print(f"\n[VIEW] done. total_ok={stats['ok']} drop={stats['drop']}")


if __name__ == "__main__":
    main()
