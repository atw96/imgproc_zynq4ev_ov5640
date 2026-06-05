@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"
set "MODE=%~1"
if "%MODE%"=="" set "MODE=jtag"
call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1
where xsct >nul 2>&1
if errorlevel 1 (echo ERROR: xsct not found & exit /b 1)
if /I "%MODE%"=="help" goto usage
if /I "%MODE%"=="/?" goto usage
if /I "%MODE%"=="-h" goto usage
if /I "%MODE%"=="sync" goto do_sync
if /I "%MODE%"=="build" goto do_build
if /I "%MODE%"=="program" goto do_program
if /I "%MODE%"=="program-elf" goto do_program_elf
if /I "%MODE%"=="program-auto" goto do_program_auto
if /I "%MODE%"=="program-xsct" goto do_program
if /I "%MODE%"=="boot" goto do_boot_disabled
if /I "%MODE%"=="jtag" goto do_jtag
if /I "%MODE%"=="all" goto do_all
if /I "%MODE%"=="check" goto do_check
echo ERROR: unknown mode "%MODE%"
goto usage
:do_sync
echo [sync] Vivado bit to Vitis platform
call xsct "%SCRIPT_DIR%sync_hw_from_vivado.tcl"
if errorlevel 1 exit /b 1
echo [sync] verify psu_init from Vivado (do NOT factory-patch)
python "%SCRIPT_DIR%fix_psu_init.py"
python "%SCRIPT_DIR%fix_axidma_sg_length.py"
call "%SCRIPT_DIR%check_psu_init.bat"
if errorlevel 1 exit /b 1
goto ok
:do_build
echo [build] imgproc_baremetal
call xsct "%SCRIPT_DIR%build_system.tcl"
if errorlevel 1 exit /b 1
goto ok
:do_check
call "%SCRIPT_DIR%check_jtag.bat"
if errorlevel 1 exit /b 1
goto ok
:do_boot_disabled
echo ERROR: SD/boot disabled. Use: deploy.bat jtag
exit /b 1
:do_program_elf
echo [jtag] Vivado DONE=HIGH 后: psu_init + dow (勿杀 hw_server)
echo [jtag] 请先关闭 Vivado HW Manager 再执行本命令
goto do_jtag_elf
:do_program_auto
call "%SCRIPT_DIR%program_auto.bat"
if errorlevel 1 exit /b 1
goto ok
:do_program
echo [jtag] program only (skip build)
goto do_jtag_program
:do_jtag
echo [build] imgproc_baremetal
call xsct "%SCRIPT_DIR%build_system.tcl"
if errorlevel 1 exit /b 1
:do_jtag_program
echo [jtag] XSCT: psu_init + fpga + dow (无 rst-system)
echo [jtag] Close Vivado Hardware Manager first.
call "%SCRIPT_DIR%_kill_jtag_all.bat"
call "%SCRIPT_DIR%_start_hw_server.bat"
if errorlevel 1 exit /b 1
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
call xsct "%SCRIPT_DIR%program_jtag.tcl"
taskkill /F /IM hw_server.exe /T >nul 2>&1
if not exist "%SCRIPT_DIR%.program_jtag.ok" (
  echo.
  echo ===== RESULT: FAIL =====
  echo If Vivado already programmed bit, try: deploy.bat program-elf
  exit /b 1
)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo.
echo ===== RESULT: PASS =====
goto ok
:do_jtag_elf
REM 勿 _kill_hw_server：若刚在 Vivado Program，杀进程会导致 Channel closed
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
call xsct "%SCRIPT_DIR%program_post_vivado.tcl"
if not exist "%SCRIPT_DIR%.program_jtag.ok" (
  echo ===== RESULT: FAIL =====
  echo 若 psu_init 失败: vivado_proj\regen_psu_init_and_sync.bat 后重试
  exit /b 1
)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
echo ===== RESULT: PASS (post-vivado) =====
goto ok
:do_all
call "%SCRIPT_DIR%deploy.bat" sync
if errorlevel 1 exit /b 1
call "%SCRIPT_DIR%deploy.bat" jtag
if errorlevel 1 exit /b 1
goto ok
:usage
echo.
echo deploy.bat — JTAG only, no SD
echo   jtag         build + program (default)
echo   program      program only
echo   program-auto Vivado bit + XSCT post-vivado
echo   program-elf  Vivado DONE=HIGH 后 psu_init+dow
echo   build / sync / check / all
echo.
exit /b 0
:ok
echo OK [%MODE%]
exit /b 0
