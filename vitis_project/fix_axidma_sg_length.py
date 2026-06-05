#!/usr/bin/env python3
"""Sync BSP xparameters with Vivado axi_dma_eth c_sg_length_width (BD/hwh)."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HWH = ROOT / (
    "vivado_proj/imgproc_axu4evb_ov5640.srcs/sources_1/bd/"
    "zynq_imgproc_bd/hw_handoff/zynq_imgproc_bd.hwh"
)
BD = ROOT / (
    "vivado_proj/imgproc_axu4evb_ov5640.srcs/sources_1/bd/"
    "zynq_imgproc_bd/zynq_imgproc_bd.bd"
)


def read_width_from_hw() -> int:
    if HWH.is_file():
        m = re.search(
            r'PARAMETER NAME="c_sg_length_width" VALUE="(\d+)"',
            HWH.read_text(encoding="utf-8", errors="replace"),
        )
        if m:
            return int(m.group(1))
    if BD.is_file():
        m = re.search(
            r'"c_sg_length_width"\s*:\s*\{\s*"value"\s*:\s*"(\d+)"',
            BD.read_text(encoding="utf-8", errors="replace"),
        )
        if m:
            return int(m.group(1))
    return 26


def patch_file(path: Path, width: int) -> bool:
    text = path.read_text(encoding="utf-8", errors="replace")
    new = text
    pairs = [
        (r"(#define\s+XPAR_AXI_DMA_ETH_SG_LENGTH_WIDTH\s+)\d+", rf"\g<1>{width}"),
        (r"(#define\s+XPAR_AXIDMA_0_c_sg_length_width\s+)\d+", rf"\g<1>{width}"),
    ]
    for pat, repl in pairs:
        new, _n = re.subn(pat, repl, new, count=1)
    if new == text:
        return False
    path.write_text(new, encoding="utf-8", newline="\n")
    return True


def main() -> int:
    width = read_width_from_hw()
    if width < 21:
        print(
            f"WARN: c_sg_length_width={width} < 21; "
            "1920x1080 frame needs >=21 bits"
        )
    vitis = Path(__file__).resolve().parent
    changed = 0
    for f in sorted(vitis.rglob("xparameters.h")):
        if patch_file(f, width):
            print(f"patched {f.relative_to(ROOT)} -> sg_length_width={width}")
            changed += 1
    if changed == 0:
        print("no xparameters.h changes (already up to date?)")
    else:
        print(f"OK: {changed} file(s), max_xfer={(1 << width) - 1} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main())
