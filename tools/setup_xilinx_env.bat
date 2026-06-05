@echo off
REM Source Vivado/Vitis settings if not already in PATH.
if not defined XILINX_VIVADO (
  if exist "%XILINX_VIVADO%\settings64.bat" goto :vivado_env
  if exist "C:\Xilinx\Vivado\2020.1\settings64.bat" set "XILINX_VIVADO=C:\Xilinx\Vivado\2020.1"
  if exist "D:\Xilinx\Vivado\2020.1\settings64.bat" set "XILINX_VIVADO=D:\Xilinx\Vivado\2020.1"
)
:vivado_env
if defined XILINX_VIVADO if exist "%XILINX_VIVADO%\settings64.bat" call "%XILINX_VIVADO%\settings64.bat"
if not defined XILINX_VITIS (
  if exist "%XILINX_VITIS%\settings64.bat" goto :vitis_env
  if exist "C:\Xilinx\Vitis\2020.1\settings64.bat" set "XILINX_VITIS=C:\Xilinx\Vitis\2020.1"
  if exist "D:\Xilinx\Vitis\2020.1\settings64.bat" set "XILINX_VITIS=D:\Xilinx\Vitis\2020.1"
)
:vitis_env
if defined XILINX_VITIS if exist "%XILINX_VITIS%\settings64.bat" call "%XILINX_VITIS%\settings64.bat"
