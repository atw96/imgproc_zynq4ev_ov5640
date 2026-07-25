#!/usr/bin/env python3
"""Row/col mean + FFT stripe period estimate for imgproc PNG frames."""
import argparse
import sys

import cv2
import numpy as np


def analyze(path: str) -> None:
    im = cv2.imread(path)
    if im is None:
        raise SystemExit(f"cannot read {path}")
    gray = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY).astype(np.float64)
    h, w = gray.shape
    row = gray.mean(axis=1)
    col = gray.mean(axis=0)
    rf = np.abs(np.fft.rfft(row - row.mean()))
    cf = np.abs(np.fft.rfft(col - col.mean()))
    rpeak = int(np.argmax(rf[1:])) + 1
    cpeak = int(np.argmax(cf[1:])) + 1
    print(f"file={path} shape={h}x{w}")
    print(f"row_std={row.std():.4f} col_std={col.std():.4f}")
    print(f"row_fft_peak_bin={rpeak} period_est={h / rpeak if rpeak else None:.2f}")
    print(f"col_fft_peak_bin={cpeak} period_est={w / cpeak if cpeak else None:.2f}")
    if cpeak and abs((w / cpeak) - 32.0) < 2.0:
        print("HINT: col period near 32 -> CLAHE tile suspect")
    # H phase vs ramp (Bit A horizontal gradient sanity)
    ideal = (np.arange(w) // 8).astype(np.float64)
    best = ( -1.0, 0)
    for s in range(0, w, 2):
        corr = float(np.corrcoef(np.roll(gray[h // 2], -s), ideal)[0, 1])
        if corr > best[0]:
            best = (corr, s)
    print(f"best_roll_vs_ramp corr={best[0]:.4f} shift={best[1]}")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("png")
    args = ap.parse_args()
    analyze(args.png)
    return 0


if __name__ == "__main__":
    sys.exit(main())
