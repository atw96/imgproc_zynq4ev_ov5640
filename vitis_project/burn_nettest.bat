@echo off
setlocal
set VITIS=D:\Xilinx\Vitis\2020.1
set PROJ=D:\Project\Vivado\zynq4ev\imgproc_mpsoc\vitis_project
set HW_SERVER=%VITIS%\bin\unwrapped\win64.o\hw_server.exe
set HW_PORT=10245
call "%VITIS%\settings64.bat"
if errorlevel 1 exit /b 1
start "hw_server" /B "%HW_SERVER%" -s tcp::%HW_PORT%
ping 127.0.0.1 -n 4 >nul
set XSCT_HW_URL=TCP:127.0.0.1:%HW_PORT%
"%VITIS%\bin\xsct.bat" "%PROJ%\program_jtag_nettest.tcl"
set RC=%ERRORLEVEL%
taskkill /F /IM hw_server.exe /T >nul 2>&1
exit /b %RC%
