@echo off
setlocal
set "PROJ_DIR=%~dp0"
cd /d "%PROJ_DIR%"
if exist "D:\Xilinx\Vivado\2020.1\settings64.bat" call "D:\Xilinx\Vivado\2020.1\settings64.bat"
vivado -mode batch -source scripts/apply_alinx_ddr_config.tcl -log apply_alinx_ddr.log -journal apply_alinx_ddr.jou
if errorlevel 1 (
  echo ERROR: apply_alinx_ddr_config.tcl failed. See apply_alinx_ddr.log
  exit /b 1
)
echo OK: DDR config applied. Re-run Implementation, then: deploy.bat sync ^&^& deploy.bat program
exit /b 0
