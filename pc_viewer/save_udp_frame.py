#!/usr/bin/env python3
"""Headless UDP frame saver for imgproc (1920x1080 RGBX -> RGB PNG)."""
import argparse
import socket
import struct
import sys
import time

import numpy as np

try:
    import cv2
except ImportError:
    cv2 = None

PORT = 5010
IMG_W, IMG_H = 1920, 1080
CHUNK_HDR = 8
EXPECTED = IMG_W * IMG_H * 4  # RGBX from PL


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=PORT)
    ap.add_argument("--out", required=True, help="output PNG path")
    ap.add_argument("--timeout", type=float, default=60.0)
    ap.add_argument("--frames", type=int, default=1, help="save N-th complete frame")
    args = ap.parse_args()

    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 8 * 1024 * 1024)
    sock.bind(("", args.port))
    sock.settimeout(1.0)
    print(f"[save] listen UDP :{args.port} timeout={args.timeout}s -> {args.out}")

    t0 = time.time()
    frames = {}
    ok = 0
    rx = 0
    while time.time() - t0 < args.timeout:
        try:
            data, addr = sock.recvfrom(65535)
        except socket.timeout:
            continue
        if len(data) < CHUNK_HDR:
            continue
        rx += 1
        fid, cidx, total, _ = struct.unpack_from(">HHHH", data, 0)
        payload = data[CHUNK_HDR:]
        if fid not in frames:
            frames[fid] = {}
        frames[fid][cidx] = payload
        if len(frames[fid]) != total:
            continue
        chunks = frames.pop(fid)
        raw = b"".join(chunks[i] for i in range(total))
        if len(raw) < EXPECTED:
            print(f"[save] short frame fid={fid} bytes={len(raw)}")
            continue
        ok += 1
        rgba = np.frombuffer(raw[:EXPECTED], dtype=np.uint8).reshape((IMG_H, IMG_W, 4))
        # Memory order R,G,B,0 → OpenCV BGR
        bgr = rgba[:, :, [2, 1, 0]].copy()
        mn, mx = int(bgr.min()), int(bgr.max())
        nz = int(np.count_nonzero(bgr))
        print(f"[save] FRAME ok={ok} fid={fid} min={mn} max={mx} nz={nz} RGB from {addr[0]}")
        if ok >= args.frames:
            if cv2 is not None:
                cv2.imwrite(args.out, bgr)
            else:
                rgb = rgba[:, :, :3]
                with open(args.out.replace(".png", ".ppm"), "wb") as f:
                    f.write(f"P6\n{IMG_W} {IMG_H}\n255\n".encode("ascii"))
                    f.write(rgb.tobytes())
                print("[save] no cv2, wrote PPM instead")
                return 0
            print(f"[save] wrote {args.out}")
            return 0
    print(f"[save] FAIL rx={rx} frames_ok={ok}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
