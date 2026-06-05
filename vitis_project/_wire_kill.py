from pathlib import Path
root = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project")

pa = root / "program_auto.bat"
s = pa.read_text(encoding="utf-8")
ins = 'call "%SCRIPT_DIR%_kill_jtag_all.bat"\r\nif errorlevel 1 exit /b 1\r\n\r\n'
if "_kill_jtag_all.bat" not in s:
    s = s.replace(
        'call "%SCRIPT_DIR%_setup_xilinx_env.bat"\r\nif errorlevel 1 exit /b 1\r\n\r\n',
        'call "%SCRIPT_DIR%_setup_xilinx_env.bat"\r\nif errorlevel 1 exit /b 1\r\n' + ins,
        1,
    )
    pa.write_text(s, encoding="utf-8")
    print("program_auto.bat updated")

db = root / "deploy.bat"
s = db.read_text(encoding="utf-8")
s = s.replace("_kill_hw_server.bat", "_kill_jtag_all.bat")
if ":do_jtag_elf\r\ncall" not in s:
    s = s.replace(
        ":do_jtag_elf\r\nREM",
        ':do_jtag_elf\r\ncall "%SCRIPT_DIR%_kill_jtag_all.bat"\r\nREM',
        1,
    )
db.write_text(s, encoding="utf-8")
print("deploy.bat updated")

for name in ("run_jtag_flow.bat", "run_jtag_diagnose.bat"):
    p = root / name
    t = p.read_text(encoding="utf-8")
    if "_kill_jtag_all.bat" in t:
        continue
    t = t.replace(
        'call "%SCRIPT_DIR%_setup_xilinx_env.bat"\r\nif errorlevel 1 exit /b 1\r\n\r\n',
        'call "%SCRIPT_DIR%_setup_xilinx_env.bat"\r\nif errorlevel 1 exit /b 1\r\ncall "%SCRIPT_DIR%_kill_jtag_all.bat"\r\n\r\n',
        1,
    )
    p.write_text(t, encoding="utf-8")
    print(name, "updated")
