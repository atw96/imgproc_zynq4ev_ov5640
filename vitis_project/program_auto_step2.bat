@echo off
REM Step2 only: after Vivado DONE=HIGH, do NOT kill hw_server
setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo [2/2] XSCT program_post_vivado (no kill hw_server)...
call xsct "%SCRIPT_DIR%program_post_vivado.tcl"
if not exist "%SCRIPT_DIR%.program_jtag.ok" exit /b 1
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo PASS
exit /b 0
