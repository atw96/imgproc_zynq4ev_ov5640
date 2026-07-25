#!/usr/bin/env python3
"""Bind host PC NIC <pc_ip>:<pc_udp_port>, assemble RGBX frames, measure H-wrap shifts."""
from __future__ import annotations

import argparse
import socket
import struct
import time
from pathlib import Path

import cv2
import numpy as np

EXPECTED = 1920 * 1080 * 4
IDEAL = (np.arange(1920) // 8).astype(np.float64)


def measure_shift(rgbx: np.ndarray) -> tuple[int, float]:
    mid = rgbx[:, :, 0].astype(np.float64)[540]
    best = (-1.0, 0)
    for sh in range(0, 1920, 1):
        c = float(np.corrcoef(np.roll(mid, -sh), IDEAL)[0, 1])
        if c > best[0]:
            best = (c, sh)
    return best[1], best[0]


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--bind", default="<pc_ip>")
    ap.add_argument("--port", type=int, default=5010)
    ap.add_argument("--frames", type=int, default=12)
    ap.add_argument("--timeout", type=float, default=120.0)
    ap.add_argument("--out", default="pc_viewer/frame_pat_rgb_geomfix_auto_f1.png")
    ap.add_argument("--tag", default="auto")
    ap.add_argument("--max-median", type=float, default=8.0)
    ap.add_argument("--max-std", type=float, default=2.0)
    args = ap.parse_args()

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 32 * 1024 * 1024)
    s.bind((args.bind, args.port))
    s.settimeout(1.0)
    print(f"[n8] listen {args.bind}:{args.port} tag={args.tag}", flush=True)

    t0 = time.time()
    n = 0
    frames: dict[int, dict[int, bytes]] = {}
    shifts: list[int] = []
    corrs: list[float] = []
    incomplete = 0

    while time.time() - t0 < args.timeout and len(shifts) < args.frames:
        try:
            data, addr = s.recvfrom(65535)
        except socket.timeout:
            continue
        n += 1
        if n <= 3:
            print(f"[n8] pkt {n} {addr} {len(data)}", flush=True)
        if len(data) < 8:
            continue
        fid, cidx, total, _ = struct.unpack_from(">HHHH", data, 0)
        frames.setdefault(fid, {})[cidx] = data[8:]
        # Drop stale incomplete frames to limit memory / mixing
        if len(frames) > 8:
            for old in sorted(frames.keys())[:-4]:
                del frames[old]
        if len(frames[fid]) != total:
            continue
        chunks = frames.pop(fid)
        if any(i not in chunks for i in range(total)):
            incomplete += 1
            continue
        raw = b"".join(chunks[i] for i in range(total))
        # RGBX expected; Y8 fallback if short
        if len(raw) >= EXPECTED:
            rgbx = np.frombuffer(raw[:EXPECTED], dtype=np.uint8).reshape((1080, 1920, 4))
            plane = rgbx[:, :, 0]
        elif len(raw) >= 1920 * 1080:
            plane = np.frombuffer(raw[: 1920 * 1080], dtype=np.uint8).reshape((1080, 1920))
            rgbx = None
        else:
            continue
        mid = plane.astype(np.float64)[540]
        best = (-1.0, 0)
        for sh in range(0, 1920, 1):
            c = float(np.corrcoef(np.roll(mid, -sh), IDEAL)[0, 1])
            if c > best[0]:
                best = (c, sh)
        sh, corr = best[1], best[0]
        shifts.append(sh)
        corrs.append(corr)
        print(
            f"[n8] FRAME ok={len(shifts)} fid={fid} shift={sh} corr={corr:.4f}",
            flush=True,
        )
        if len(shifts) == 1:
            out = Path(args.out)
            out.parent.mkdir(parents=True, exist_ok=True)
            if rgbx is not None:
                bgr = rgbx[:, :, [2, 1, 0]].copy()
            else:
                bgr = cv2.cvtColor(plane, cv2.COLOR_GRAY2BGR)
            cv2.imwrite(str(out), bgr)
            print(f"[n8] wrote {out}", flush=True)

    print(
        f"[n8] pkts={n} frames={len(shifts)} incomplete={incomplete} shifts={shifts}",
        flush=True,
    )
    if not shifts:
        print("[n8] RESULT=FAIL reason=NO_FRAMES", flush=True)
        return 2

    std = float(np.std(shifts))
    med = float(np.median(shifts))
    # treat wrap-near-0 as small: map shift to signed minimal roll
    signed = [sh if sh <= 960 else sh - 1920 for sh in shifts]
    med_abs = float(np.median(np.abs(np.asarray(signed, dtype=np.float64))))
    std_s = float(np.std(signed))
    print(
        f"[n8] std={std:.3f} median={med:.1f} signed_std={std_s:.3f} "
        f"median_|signed|={med_abs:.1f} corr_med={float(np.median(corrs)):.4f}",
        flush=True,
    )
    ok = (std_s <= args.max_std) and (med_abs <= args.max_median)
    print(
        f"[n8] RESULT={'PASS' if ok else 'FAIL'} "
        f"(need signed_std<={args.max_std} and median_|signed|<={args.max_median})",
        flush=True,
    )
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
