@echo off
setlocal
call "%~dp0_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1
echo === JTAG diagnostic (xsdb) ===
xsdb -eval "connect; after 2000; puts [targets]; exit"
pause
