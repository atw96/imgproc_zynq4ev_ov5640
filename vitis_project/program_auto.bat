@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo ===== program_auto =====
echo [0] kill hung xsct only (keep hw_server if Vivado just ran)
call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1
taskkill /F /IM xsct.exe /T >nul 2>&1
ping 127.0.0.1 -n 2 >nul

set "VIVADO_ROOT="
if defined XILINX_VIVADO if exist "%XILINX_VIVADO%\settings64.bat" set "VIVADO_ROOT=%XILINX_VIVADO%"
if "%VIVADO_ROOT%"=="" if exist "D:\Xilinx\Vivado\2020.1\settings64.bat" set "VIVADO_ROOT=D:\Xilinx\Vivado\2020.1"
if "%VIVADO_ROOT%"=="" (echo ERROR: Vivado not found & exit /b 1)
call "%VIVADO_ROOT%\settings64.bat"
where vivado >nul 2>&1 || (echo ERROR: vivado not in PATH & exit /b 1)
where xsct >nul 2>&1 || (echo ERROR: xsct not in PATH & exit /b 1)
if not exist "%SCRIPT_DIR%imgproc_baremetal\Debug\imgproc_baremetal.elf" (
  echo ERROR: run deploy.bat build first & exit /b 1
)

del "%SCRIPT_DIR%.program_bit.ok" 2>nul
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul

echo [1/2] Vivado Program Device...
call vivado -mode batch -source "%SCRIPT_DIR%vivado_program_bit.tcl" -notrace -nojournal -nolog
if errorlevel 1 (echo FAIL vivado & exit /b 1)
if not exist "%SCRIPT_DIR%.program_bit.ok" (echo FAIL no bit ok & exit /b 1)
del "%SCRIPT_DIR%.program_bit.ok" 2>nul
echo [1/2] bit OK DONE=HIGH

echo.
echo [2/2] XSCT post-vivado (do NOT kill hw_server here)...
ping 127.0.0.1 -n 3 >nul
call xsct "%SCRIPT_DIR%program_post_vivado.tcl"
if not exist "%SCRIPT_DIR%.program_jtag.ok" (
  echo ===== FAIL step2 =====
  exit /b 1
)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo ===== PASS =====
exit /b 0
