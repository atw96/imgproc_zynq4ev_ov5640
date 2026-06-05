from pathlib import Path
import shutil
base = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc")
src = base / "vivado_proj/imgproc_axu4evb_ov5640.srcs/sources_1/bd/zynq_imgproc_bd/ip/zynq_imgproc_bd_zynq_ultra_ps_e_0_0/psu_init.tcl"
for rel in ["vitis_project/zynq_imgproc_platform/hw/psu_init.tcl", "vitis_project/imgproc_baremetal/_ide/psinit/psu_init.tcl"]:
    dst = base / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
print("fixed psu_init from vivado")
