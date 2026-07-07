#!/usr/bin/env python3
"""
ZynqMP imgproc UDP 帧接收显示器
接收板端发来的 1920x1080 灰度帧并实时显示
用法: python recv_display.py
依赖: pip install opencv-python numpy
"""
import socket
import struct
import numpy as np
import cv2
import time
import threading
from collections import defaultdict

# ---- 配置 ----
BIND_IP      = ""      # 绑定所有接口（单播/广播均可收）
LISTEN_PORT  = 5002   # 与板端 ETH_DST_PORT 一致
IMG_W        = 1920
IMG_H        = 1080
CHUNK_HDR_SZ = 8
CHUNK_DATA   = 1392      # UDP_MTU_DATA(1400) - CHUNK_HDR_SZ(8)

# ---- 帧缓冲 ----
frame_buf   = {}         # {frame_id: {chunk_idx: bytes}}
frame_total = {}         # {frame_id: total_chunks}
last_frame  = None
lock        = threading.Lock()
stats       = {"rx": 0, "ok": 0, "drop": 0, "fps": 0.0}

def recv_loop():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
    sock.bind((BIND_IP, LISTEN_PORT))
    print(f"[RX] listening on UDP {BIND_IP}:{LISTEN_PORT}")

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
                # 清理太旧的帧
                old = [k for k in frame_buf if (fid - k) % 65536 > 10]
                for k in old:
                    del frame_buf[k]
                    frame_total.pop(k, None)
                frame_buf[fid] = {}
                frame_total[fid] = total

            frame_buf[fid][cidx] = payload

            if len(frame_buf[fid]) == frame_total.get(fid, -1):
                # 帧完整，拼接
                chunks = frame_buf.pop(fid)
                frame_total.pop(fid, None)
                raw = b"".join(chunks[i] for i in range(total))
                expected = IMG_W * IMG_H
                if len(raw) >= expected:
                    arr = np.frombuffer(raw[:expected], dtype=np.uint8)
                    arr = arr.reshape((IMG_H, IMG_W))
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
    t = threading.Thread(target=recv_loop, daemon=True)
    t.start()

    cv2.namedWindow("ZynqMP 1920x1080 Gradient", cv2.WINDOW_NORMAL)
    cv2.resizeWindow("ZynqMP 1920x1080 Gradient", 960, 540)

    print("[VIEW] press Q to quit")
    prev_ok = 0
    while True:
        with lock:
            frame = last_frame.copy() if last_frame is not None else None

        if frame is not None:
            # 叠加统计信息
            disp = cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR)
            cv2.putText(disp,
                f"Frame={stats['ok']}  FPS={stats['fps']:.1f}  drop={stats['drop']}",
                (20, 40), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (0, 255, 0), 2)
            cv2.imshow("ZynqMP 1920x1080 Gradient", disp)

            if stats["ok"] != prev_ok:
                prev_ok = stats["ok"]
                print(f"\r[VIEW] ok={stats['ok']}  fps={stats['fps']:.1f}  "
                      f"rx={stats['rx']}  drop={stats['drop']}", end="", flush=True)
        else:
            # 等待第一帧
            blank = np.zeros((540, 960, 3), dtype=np.uint8)
            cv2.putText(blank, f"Waiting UDP {BIND_IP or '0.0.0.0'}:{LISTEN_PORT} from 10.0.0.10...",
                        (60, 270), cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 200, 255), 2)
            cv2.imshow("ZynqMP 1920x1080 Gradient", blank)

        key = cv2.waitKey(30) & 0xFF
        if key in (ord('q'), ord('Q'), 27):
            break

    cv2.destroyAllWindows()
    print(f"\n[VIEW] done. total_ok={stats['ok']} drop={stats['drop']}")


if __name__ == "__main__":
    main()
