@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=jtag"

if exist "D:\Xilinx\Vitis\2020.1\settings64.bat" call "D:\Xilinx\Vitis\2020.1\settings64.bat"
if exist "D:\Xilinx\Vivado\2020.1\settings64.bat" call "D:\Xilinx\Vivado\2020.1\settings64.bat"

where xsct >nul 2>&1
if errorlevel 1 (echo ERROR: xsct not found & exit /b 1)

if /I "%MODE%"=="help" goto usage
if /I "%MODE%"=="/?" goto usage
if /I "%MODE%"=="-h" goto usage
if /I "%MODE%"=="sync" goto do_sync
if /I "%MODE%"=="build" goto do_build
if /I "%MODE%"=="program" goto do_program
if /I "%MODE%"=="program-elf" goto do_program_elf
if /I "%MODE%"=="jtag" goto do_jtag
if /I "%MODE%"=="all" goto do_all
echo ERROR: unknown mode "%MODE%"
goto usage

:do_sync
echo [sync] Vivado bit to Vitis platform
call xsct "%SCRIPT_DIR%sync_hw_from_vivado.tcl"
if errorlevel 1 exit /b 1
goto ok

:do_build
echo [build] imgproc_baremetal
call xsct "%SCRIPT_DIR%build_system.tcl"
if errorlevel 1 exit /b 1
goto ok

:do_program_elf
echo [jtag] post-Vivado: psu_init + dow (close HW Manager first)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
call xsct "%SCRIPT_DIR%program_post_vivado.tcl"
if not exist "%SCRIPT_DIR%.program_jtag.ok" (
  echo ===== RESULT: FAIL =====
  echo Hint: run vivado_proj\regen_psu_init_and_sync.bat then retry
  exit /b 1
)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo ===== RESULT: PASS (post-vivado) =====
goto ok

:do_program
echo [jtag] program only (skip build)
goto do_jtag_program

:do_jtag
echo [build] imgproc_baremetal
call xsct "%SCRIPT_DIR%build_system.tcl"
if errorlevel 1 exit /b 1
:do_jtag_program
echo [jtag] XSCT: psu_init + fpga + dow
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
call xsct "%SCRIPT_DIR%program_psu_first.tcl"
if not exist "%SCRIPT_DIR%.program_jtag.ok" (
  echo ===== RESULT: FAIL =====
  echo If Vivado already programmed bit, try: deploy.bat program-elf
  exit /b 1
)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo ===== RESULT: PASS =====
goto ok

:do_all
call "%~f0" sync
if errorlevel 1 exit /b 1
call "%~f0" jtag
if errorlevel 1 exit /b 1
goto ok

:usage
echo.
echo deploy.bat - JTAG workflow (no SD boot)
echo   jtag         build + program (default)
echo   program      program only
echo   program-elf  after Vivado Program Device: psu_init + dow
echo   build / sync / all
echo.
exit /b 0

:ok
echo OK [%MODE%]
exit /b 0
