@echo off
setlocal
set PROJ=D:\Project\Vivado\zynq4ev\imgproc_mpsoc\vitis_project
cd /d %PROJ%

echo [1] build net_test_bm...
call D:\Xilinx\Vitis\2020.1\settings64.bat
cd /d %PROJ%\net_test_bm\Debug
make all -j 8
if errorlevel 1 exit /b 1

echo [2] kill JTAG...
cd /d %PROJ%
powershell -NonInteractive -ExecutionPolicy Bypass -File kill_jtag.ps1
ping 127.0.0.1 -n 6 >nul

echo [3] burn net_test...
call burn_nettest.bat
if errorlevel 1 exit /b 1
if not exist "%PROJ%\.program_jtag.ok" (
    echo BURN FAIL
    exit /b 1
)

echo [4] PC test 09_ps_net...
powershell -NonInteractive -ExecutionPolicy Bypass -File run_09_nettest.ps1
exit /b 0
