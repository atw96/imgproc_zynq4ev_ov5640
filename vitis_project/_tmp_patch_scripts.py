from pathlib import Path

p = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/program_auto.bat")
s = p.read_text(encoding="utf-8")
old = """echo [1/2] Vivado Program Device...
vivado -mode batch -source "%SCRIPT_DIR%vivado_program_bit.tcl" -notrace -nojournal -nolog
if not exist "%SCRIPT_DIR%.program_bit.ok" (
  echo ===== FAIL: bit =====
  exit /b 1
)
del "%SCRIPT_DIR%.program_bit.ok" 2>nul
echo [1/2] bit OK

echo.
echo [2/2] XSCT program_post_vivado.tcl ...
ping 127.0.0.1 -n 2 >nul
xsct "%SCRIPT_DIR%program_post_vivado.tcl\""""
new = """echo [1/2] Vivado Program Device...
vivado -mode batch -source "%SCRIPT_DIR%vivado_program_bit.tcl" -notrace -nojournal -nolog
if errorlevel 1 (
  echo ===== FAIL: vivado exit error =====
  exit /b 1
)
if not exist "%SCRIPT_DIR%.program_bit.ok" (
  echo ===== FAIL: bit =====
  exit /b 1
)
del "%SCRIPT_DIR%.program_bit.ok" 2>nul
echo [1/2] bit OK  DONE=HIGH

echo.
echo [2/2] XSCT program_post_vivado.tcl (psu_init may take 30s-6min)...
echo If psu_init hung last time, power-cycle board 10s first
ping 127.0.0.1 -n 3 >nul
xsct "%SCRIPT_DIR%program_post_vivado.tcl\""""
if old in s:
    p.write_text(s.replace(old, new), encoding="utf-8")
    print("program_auto.bat updated")
else:
    print("program_auto.bat skip")

pj = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/program_jtag.tcl")
t = pj.read_text(encoding="utf-8")
t = t.replace(
    "proc step {msg} { puts $msg; flush stdout }",
    """proc step {msg} {
    puts [format {%s %s} [clock format [clock seconds] -format {%H:%M:%S}] $msg]
    flush stdout
}""",
)
t = t.replace(
    'step "INFO: psu_init..."',
    'step "INFO: psu_init... (factory DDR, wait up to 6min)"',
)
pj.write_text(t, encoding="utf-8")
print("program_jtag.tcl updated")

pp = Path(r"d:/Project/Vivado/zynq4ev/imgproc_mpsoc/vitis_project/program_post_vivado.tcl")
u = pp.read_text(encoding="utf-8")
u = u.replace(
    "log_step {psu_init...}",
    "log_step {psu_init... (factory DDR, wait up to 6min; power-cycle if hung)}",
)
pp.write_text(u, encoding="utf-8")
print("program_post_vivado.tcl updated")
