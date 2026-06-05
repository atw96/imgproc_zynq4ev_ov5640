from pathlib import Path
import time

base = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc")

# 1. RTL test_pat_en
rtl = base / "files/sources_1/rtl_top/imgproc_top_ov5640.v"
found = False
for line in rtl.read_text(encoding="utf-8").splitlines():
    if "test_pat_en" in line and "1'b1" in line:
        print("RTL test_pat_en => HARDWIRED 1 (good):", line.strip())
        found = True
if not found:
    for line in rtl.read_text(encoding="utf-8").splitlines():
        if "test_pat_en" in line and "wire" in line:
            print("RTL test_pat_en => still from register:", line.strip())

# 2. main.c PlIsp usage
mc = base / "vitis_project/imgproc_baremetal/src/main.c"
mc_t = mc.read_text(encoding="utf-8")
has_init  = "PlIsp_Init" in mc_t
has_enable = "PlIsp_Enable" in mc_t
print("main.c calls PlIsp_Init:", has_init)
print("main.c calls PlIsp_Enable:", has_enable)

# 3. ELF
elf = base / "vitis_project/imgproc_baremetal/Debug/imgproc_baremetal.elf"
if elf.exists():
    mt = time.strftime("%Y-%m-%d %H:%M", time.localtime(elf.stat().st_mtime))
    print("ELF OK:", elf.stat().st_size, "bytes, modified", mt)
else:
    print("ELF: MISSING")

# 4. Bitstreams
for label, rel in [
    ("vitis hw bit", "vitis_project/zynq_imgproc_platform/hw/imgproc_top_ov5640.bit"),
    ("vivado impl1 bit", "vivado_proj/imgproc_axu4evb_ov5640.runs/impl_1/imgproc_top_ov5640.bit"),
]:
    p = base / rel
    if p.exists():
        mt = time.strftime("%Y-%m-%d %H:%M", time.localtime(p.stat().st_mtime))
        print(label, "OK:", p.stat().st_size, "bytes, modified", mt)
    else:
        print(label, "MISSING")
