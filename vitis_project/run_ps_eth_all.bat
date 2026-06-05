@echo off
setlocal
set PROJ=D:\Project\Vivado\zynq4ev\imgproc_mpsoc\vitis_project
cd /d %PROJ%

echo [1] build net_test_bm (09_ps_net)...
call D:\Xilinx\Vitis\2020.1\settings64.bat
cd /d %PROJ%\net_test_bm\Debug
make all -j 8
if errorlevel 1 exit /b 1

echo [2] JTAG burn...
cd /d %PROJ%
powershell -NonInteractive -ExecutionPolicy Bypass -File kill_jtag.ps1
ping 127.0.0.1 -n 6 >nul
call burn_nettest.bat
if not exist "%PROJ%\.program_jtag.ok" exit /b 1

echo [3] PC ps_eth test...
powershell -NonInteractive -ExecutionPolicy Bypass -File run_ps_eth.ps1
exit /b 0
