#!/usr/bin/env python3
"""Preflight checks for imgproc_mpsoc JTAG / BSP / build environment."""
from __future__ import annotations

import json
import re
import socket
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VITIS = ROOT / "vitis_project"
HW_PORT = 10245
VITIS_CANDIDATES = [
    Path(r"D:\Xilinx\Vitis\2020.1"),
    Path(r"C:\Xilinx\Vitis\2020.1"),
]
FRAME_BYTES = 1920 * 1080 + 8


def _port_in_use(port: int) -> bool:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        try:
            s.bind(("127.0.0.1", port))
            return False
        except OSError:
            return True


def _read_sg_width_from_hw() -> int | None:
    hwh = ROOT / (
        "vivado_proj/imgproc_axu4evb_ov5640.srcs/sources_1/bd/"
        "zynq_imgproc_bd/hw_handoff/zynq_imgproc_bd.hwh"
    )
    if hwh.is_file():
        m = re.search(
            r'PARAMETER NAME="c_sg_length_width" VALUE="(\d+)"',
            hwh.read_text(encoding="utf-8", errors="replace"),
        )
        if m:
            return int(m.group(1))
    return None


def _read_bsp_sg_width() -> int | None:
    xp = (
        VITIS
        / "zynq_imgproc_platform/export/zynq_imgproc_platform/sw/"
        "zynq_imgproc_platform/standalone_psu_cortexa53_0/bspinclude/include/xparameters.h"
    )
    if not xp.is_file():
        return None
    m = re.search(
        r"#define\s+XPAR_AXI_DMA_ETH_SG_LENGTH_WIDTH\s+(\d+)",
        xp.read_text(encoding="utf-8", errors="replace"),
    )
    return int(m.group(1)) if m else None


def _proc_running(name: str) -> bool:
    try:
        out = subprocess.check_output(
            ["tasklist", "/FI", f"IMAGENAME eq {name}", "/NH"],
            text=True,
            errors="replace",
        )
        return name.lower() in out.lower()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def run_checks() -> dict:
    checks: list[dict] = []
    ok = True

    def add(name: str, passed: bool, detail: str, fix: str = "") -> None:
        nonlocal ok
        if not passed:
            ok = False
        checks.append({"name": name, "ok": passed, "detail": detail, "fix": fix})

    vitis_root = None
    for p in VITIS_CANDIDATES:
        if (p / "settings64.bat").is_file():
            vitis_root = p
            break
    add(
        "vitis_2020.1",
        vitis_root is not None,
        str(vitis_root) if vitis_root else "Vitis 2020.1 not found",
        "Install Vitis 2020.1 or set XILINX_VITIS",
    )

    bit = VITIS / "zynq_imgproc_platform/hw/imgproc_top_ov5640.bit"
    add(
        "bitstream",
        bit.is_file(),
        f"{bit} ({bit.stat().st_size if bit.is_file() else 0} B)",
        "vivado_proj run_impl or deploy.bat sync",
    )

    elf = VITIS / "imgproc_baremetal/Debug/imgproc_baremetal.elf"
    add(
        "firmware_elf",
        elf.is_file(),
        str(elf),
        "vitis_project/deploy.bat build",
    )

    psu = VITIS / "zynq_imgproc_platform/hw/psu_init.tcl"
    psu_ok = False
    psu_detail = "missing"
    if psu.is_file():
        txt = psu.read_text(encoding="utf-8", errors="replace")
        sz = psu.stat().st_size
        has_phy = "0x00F022FF" in txt
        has_gem3 = "GEM3" in txt
        no_stale = "0x00F016CF" not in txt
        sz_ok = sz > 600_000
        psu_ok = has_phy and has_gem3 and no_stale and sz_ok
        psu_detail = (
            f"size={sz} phy={has_phy} gem3={has_gem3} "
            f"no_stale_phy={no_stale}"
        )
    add(
        "psu_init",
        psu_ok,
        psu_detail,
        "py -3 vitis_project/fix_psu_init.py --fix",
    )

    hw_w = _read_sg_width_from_hw()
    bsp_w = _read_bsp_sg_width()
    sg_ok = hw_w is not None and bsp_w is not None and hw_w == bsp_w and hw_w >= 21
    add(
        "axidma_sg_length_width",
        sg_ok,
        f"vivado={hw_w} bsp={bsp_w} (need >=21, match HW)",
        "py -3 vitis_project/fix_axidma_sg_length.py then deploy.bat build",
    )

    if hw_w and (1 << hw_w) - 1 < FRAME_BYTES:
        add(
            "dma_frame_size",
            False,
            f"max_xfer={(1 << hw_w) - 1} < frame={FRAME_BYTES}",
            "vivado_proj/scripts/fix_dma_length_and_build.tcl",
        )

    port_busy = _port_in_use(HW_PORT)
    add(
        f"hw_server_port_{HW_PORT}",
        not port_busy,
        "free" if not port_busy else f"port {HW_PORT} in use (stale hw_server?)",
        "vitis_project/_kill_jtag_all.bat",
    )

    for proc in ("xsct.exe", "hw_server.exe"):
        if _proc_running(proc):
            add(
                f"jtag_proc_{proc}",
                False,
                f"{proc} still running",
                "vitis_project/_kill_jtag_all.bat before burn",
            )

    return {"ok": ok, "checks": checks, "hw_port": HW_PORT, "root": str(ROOT)}


def _auto_fix() -> list[str]:
    logs: list[str] = []
    for proc in ("xsct.exe", "hw_server.exe", "cs_server.exe"):
        if _proc_running(proc):
            bat = VITIS / "_kill_jtag_all.bat"
            if bat.is_file():
                subprocess.run(
                    ["cmd", "/c", str(bat)],
                    capture_output=True,
                    text=True,
                    errors="replace",
                )
                logs.append(f"killed stale JTAG ({proc})")
            break
    for script in ("fix_psu_init.py", "fix_axidma_sg_length.py"):
        path = VITIS / script
        if not path.is_file():
            continue
        args = [sys.executable, str(path)]
        if script == "fix_psu_init.py":
            args.append("--fix")
        proc = subprocess.run(args, capture_output=True, text=True, errors="replace")
        out = ((proc.stdout or "") + (proc.stderr or "")).strip()
        if out:
            logs.append(out)
    # Second pass if stale PHY still present after sync overwrote Vitis copy
    psu = VITIS / "zynq_imgproc_platform/hw/psu_init.tcl"
    if psu.is_file():
        txt = psu.read_text(encoding="utf-8", errors="replace")
        if "0x00F016CF" in txt or "0x00F022FF" not in txt:
            proc = subprocess.run(
                [sys.executable, str(VITIS / "fix_psu_init.py"), "--fix"],
                capture_output=True,
                text=True,
                errors="replace",
            )
            out = ((proc.stdout or "") + (proc.stderr or "")).strip()
            if out:
                logs.append(f"psu_init retry: {out}")
    return logs


def main() -> int:
    if "--fix" in sys.argv:
        for line in _auto_fix():
            print(line)
    result = run_checks()
    if "--json" in sys.argv:
        print(json.dumps(result, indent=2, ensure_ascii=False))
    else:
        print("=== imgproc_mpsoc preflight ===")
        for c in result["checks"]:
            mark = "OK" if c["ok"] else "FAIL"
            print(f"[{mark}] {c['name']}: {c['detail']}")
            if not c["ok"] and c["fix"]:
                print(f"       fix: {c['fix']}")
        print("===", "PASS" if result["ok"] else "FAIL", "===")
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())


