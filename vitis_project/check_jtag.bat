@echo off
setlocal
cd /d "%~dp0"
call _setup_xilinx_env.bat
call _kill_hw_server.bat
ping 127.0.0.1 -n 3 >nul
xsct check_jtag.tcl
if errorlevel 1 (echo. & echo ===== JTAG检测: 失败 ===== & exit /b 1)
echo. & echo ===== JTAG检测: 通过 =====
exit /b 0
