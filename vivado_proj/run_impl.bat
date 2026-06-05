@echo off
setlocal
set "PROJ_DIR=%~dp0"
cd /d "%PROJ_DIR%"
call "%~dp0..\tools\setup_xilinx_env.bat"
echo [vivado] synth + impl ...
vivado -mode batch -source scripts/run_impl.tcl -log run_impl.log -journal run_impl.jou
if errorlevel 1 (echo ERROR: run_impl failed & exit /b 1)
echo OK: bit generated
exit /b 0
