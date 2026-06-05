from pathlib import Path
p = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/program_auto.bat")
s = p.read_text(encoding="utf-8")
ins = 'call "%SCRIPT_DIR%check_psu_init.bat"\r\nif errorlevel 1 exit /b 1\r\n'
if "check_psu_init.bat" not in s:
    s = s.replace(
        'echo [2/2] XSCT post-vivado (do NOT kill hw_server here)...\r\n',
        'call "%SCRIPT_DIR%check_psu_init.bat"\r\nif errorlevel 1 exit /b 1\r\necho [2/2] XSCT post-vivado (do NOT kill hw_server here)...\r\n',
    )
    p.write_text(s, encoding="utf-8")
    print("program_auto updated")
