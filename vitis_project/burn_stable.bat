@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
echo ===== burn_stable: 单次 XSCT (psu_init -^> fpga -^> dow) =====
echo 请先: 板子完整掉电10秒上电; 关 Vivado HW Manager
call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1
echo [1] kill hung xsct/hw_server...
taskkill /F /IM xsct.exe /T >nul 2>&1
taskkill /F /IM hw_server.exe /T >nul 2>&1
taskkill /F /IM cs_server.exe /T >nul 2>&1
ping 127.0.0.1 -n 3 >nul
echo [2] fix+verify psu_init from Vivado...
python "%SCRIPT_DIR%fix_psu_init.py"
call "%SCRIPT_DIR%check_psu_init.bat"
if errorlevel 1 exit /b 1
echo [3] DAP probe...
call "%SCRIPT_DIR%run_jtag_diagnose.bat"
if errorlevel 1 exit /b 1
echo [4] XSCT program_jtag.tcl (psu_init then fpga, 约1-3min)...
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
call xsct "%SCRIPT_DIR%program_jtag.tcl"
if errorlevel 1 (echo FAIL xsct & exit /b 1)
if not exist "%SCRIPT_DIR%.program_jtag.ok" (echo FAIL no ok flag & exit /b 1)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo ===== PASS burn_stable =====
echo 串口 COM3 115200
exit /b 0
