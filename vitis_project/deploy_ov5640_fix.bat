@echo off
setlocal
set "ROOT=%~dp0.."
echo === OV5640 fix pipeline ===
if /I "%~1"=="skip-vivado" goto sync
call "%ROOT%\vivado_proj\run_impl.bat"
if errorlevel 1 exit /b 1
:sync
call "%~dp0deploy.bat" sync
if errorlevel 1 exit /b 1
call "%~dp0deploy.bat" build
if errorlevel 1 exit /b 1
call "%~dp0deploy.bat" program
if errorlevel 1 exit /b 1
echo Done. UART 115200: expect OV5640 ID 0x56 0x40
exit /b 0
