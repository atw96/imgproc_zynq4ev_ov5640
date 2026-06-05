@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1
echo [0] kill hung xsct only...
taskkill /F /IM xsct.exe /T >nul 2>&1
ping 127.0.0.1 -n 2 >nul
call "%SCRIPT_DIR%program_auto.bat"
exit /b %ERRORLEVEL%
