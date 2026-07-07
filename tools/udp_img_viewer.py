#!/usr/bin/env python3
"""接收板端 UDP 灰度帧 (eth_stream.c) 并显示。默认监听 0.0.0.0:5002"""
import argparse
import socket
import struct
import sys

try:
    import numpy as np
    import cv2
except ImportError:
    print("需要: pip install numpy opencv-python")
    sys.exit(1)

HDR_MAGIC = (0xAA, 0x55)
CHUNK_HDR = 8


def parse_frame_header(buf):
    if len(buf) < 8 or buf[0] != HDR_MAGIC[0] or buf[1] != HDR_MAGIC[1]:
        return None
    fid = struct.unpack(">H", buf[2:4])[0]
    w = struct.unpack(">H", buf[4:6])[0]
    h = struct.unpack(">H", buf[6:8])[0]
    return fid, w, h


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bind", default="0.0.0.0", help="监听地址")
    ap.add_argument("--port", type=int, default=5002, help="UDP 端口")
    ap.add_argument("--out", default="", help="保存最新帧为 PNG")
    ap.add_argument("--width", type=int, default=1920, help="图像宽度（像素）")
    ap.add_argument("--height", type=int, default=1080, help="图像高度（像素）")
    args = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    # 增大接收缓冲，减小丢包风险
    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 4 * 1024 * 1024)
    except Exception:
        pass
    sock.bind((args.bind, args.port))
    sock.settimeout(5.0)
    print(f"监听 UDP {args.bind}:{args.port}，等待板子 192.168.1.10 发流…")
    print("板端目标 IP 须为 192.168.1.69（eth_stream.c ETH_DST_IP_STR）")
    print("按 q 退出窗口")

    chunks = {}
    frame_id = None
    total_chunks = 0
    w, h = args.width, args.height
    # 统计
    frames_ok = 0
    frames_dropped = 0
    last_print = 0

    while True:
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            print(f"超时：未收到数据，请 ping 192.168.1.10 并检查防火墙 UDP {args.port}")
            continue

        if len(data) < CHUNK_HDR:
            continue

        fid = struct.unpack(">H", data[0:2])[0]
        cidx = struct.unpack(">H", data[2:4])[0]
        nchk = struct.unpack(">H", data[4:6])[0]
        payload = data[CHUNK_HDR:]

        if frame_id is None or fid != frame_id:
            chunks.clear()
            frame_id = fid
            total_chunks = nchk

        chunks[cidx] = payload

        if total_chunks == 0 or len(chunks) < total_chunks:
            continue

        # 板端 udp_send_pixels 只发灰度 payload（无 0xAA55 帧头）
        # 检查是否有缺失 chunk
        missing = [i for i in range(total_chunks) if i not in chunks]
        if missing:
            frames_dropped += 1
            chunks.clear()
            continue

        pixels = b"".join(chunks[i] for i in range(total_chunks))
        if len(pixels) < w * h:
            frames_dropped += 1
            chunks.clear()
            continue

        img = np.frombuffer(pixels[: w * h], dtype=np.uint8).reshape((h, w))
        if args.out:
            cv2.imwrite(args.out, img)
        cv2.imshow("imgproc_udp", img)
        frames_ok += 1
        # 每 10 秒打印统计
        import time
        now = int(time.time())
        if now - last_print >= 10:
            print(f"统计: 成功帧={frames_ok} 丢帧={frames_dropped}")
            last_print = now
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break
        chunks.clear()

    cv2.destroyAllWindows()
    sock.close()


if __name__ == "__main__":
    main()
