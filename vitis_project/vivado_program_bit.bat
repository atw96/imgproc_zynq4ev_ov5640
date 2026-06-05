@echo off

setlocal

set "SCRIPT_DIR=%~dp0"

cd /d "%SCRIPT_DIR%"

call "%SCRIPT_DIR%_setup_xilinx_env.bat"

if errorlevel 1 exit /b 1

call "%SCRIPT_DIR%_kill_hw_server.bat"

ping 127.0.0.1 -n 3 >nul

echo [vivado] Program Device (bit + PS init)...

vivado -mode batch -nojournal -nolog -source "%SCRIPT_DIR%vivado_program_bit.tcl"

if errorlevel 1 (
  echo.
  echo ===== Vivado Program: FAIL =====
  echo 成功标志: End of startup status: HIGH
  echo 若 LOW: 断电重上电, 重插 JTAG, 在 Vivado GUI 再试 Program Device
  exit /b 1
)
echo ===== Vivado Program: PASS =====

exit /b 0

