@echo off
REM Resolve Xilinx Vitis 2020.1 (prefer D:\Xilinx)
set "VITIS_ROOT="
if defined XILINX_VITIS (
  if exist "%XILINX_VITIS%\settings64.bat" set "VITIS_ROOT=%XILINX_VITIS%"
)
if "%VITIS_ROOT%"=="" if exist "D:\Xilinx\Vitis\2020.1\settings64.bat" set "VITIS_ROOT=D:\Xilinx\Vitis\2020.1"
if "%VITIS_ROOT%"=="" if exist "C:\Xilinx\Vitis\2020.1\settings64.bat" set "VITIS_ROOT=C:\Xilinx\Vitis\2020.1"
if "%VITIS_ROOT%"=="" (
  echo ERROR: Vitis 2020.1 not found. Set XILINX_VITIS or install to D:\Xilinx\Vitis\2020.1
  exit /b 1
)
call "%VITIS_ROOT%\settings64.bat"
exit /b 0
