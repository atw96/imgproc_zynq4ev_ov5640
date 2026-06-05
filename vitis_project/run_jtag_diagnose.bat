@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo ===== JTAG / DAP diagnose =====
echo 1. Close Vivado Hardware Manager first.
echo 2. If previous psu_init hung, power-cycle the board before running this.
echo.

call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1

where xsct >nul 2>&1
if errorlevel 1 (
  echo ERROR: xsct not found
  exit /b 1
)

del "%SCRIPT_DIR%jtag_dap_probe.log" 2>nul
xsct "%SCRIPT_DIR%jtag_dap_probe.tcl" > "%SCRIPT_DIR%jtag_dap_probe.log" 2>&1
set "XSCT_RC=%ERRORLEVEL%"
type "%SCRIPT_DIR%jtag_dap_probe.log"

findstr /C:"OK DAP probe" "%SCRIPT_DIR%jtag_dap_probe.log" >nul
if errorlevel 1 (
  echo.
  echo ===== RESULT: FAIL (DAP/JTAG access unstable) =====
  echo Check USB cable, power-cycle board, close Vivado/hw_server/xsct.
  exit /b 1
)

echo.
echo ===== RESULT: PASS (DAP basic reads OK) =====
echo Next: if psu_init still fails at FD080030, patch DDR init from factory:
echo   powershell -ExecutionPolicy Bypass -File patch_psu_ddr_from_factory.ps1
exit /b 0

