@echo off
REM 启动 hw_server（Windows 保留 3065-3164，默认 3121 不可用）
setlocal
if not defined VITIS_ROOT (
  if exist "D:\Xilinx\Vitis\2020.1\settings64.bat" set "VITIS_ROOT=D:\Xilinx\Vitis\2020.1"
)
if not defined HW_PORT set "HW_PORT=10245"
set "HW_SERVER=%VITIS_ROOT%\bin\unwrapped\win64.o\hw_server.exe"
if not exist "%HW_SERVER%" (
  echo ERROR: hw_server not found at %HW_SERVER%
  exit /b 1
)
start "hw_server" /B "%HW_SERVER%" -s tcp::%HW_PORT%
ping 127.0.0.1 -n 3 >nul
set "XSCT_HW_URL=TCP:127.0.0.1:%HW_PORT%"
exit /b 0
