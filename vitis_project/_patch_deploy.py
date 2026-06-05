from pathlib import Path
p = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/deploy.bat")
s = p.read_text(encoding="utf-8")
old = 'call xsct "%SCRIPT_DIR%program_post_vivado.tcl"\r\nif not exist'
new = 'call xsct "%SCRIPT_DIR%program_post_vivado.tcl"\r\nif errorlevel 1 (\r\n  echo ===== RESULT: FAIL (xsct errorlevel) =====\r\n  exit /b 1\r\n)\r\nif not exist'
if old in s and "xsct errorlevel" not in s:
    p.write_text(s.replace(old, new), encoding="utf-8")
    print("deploy.bat fixed")
else:
    print("skip", "already" if "xsct errorlevel" in s else "pattern")
