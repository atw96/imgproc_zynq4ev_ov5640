@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

echo ============================================================
echo  JTAG 自动化流程 (2026_5_28 思路)
echo  [1] factory DDR 片段对齐 psu_init (保留 GEM3)
echo  [2] DAP 低风险探针 (不 psu_init / 不 fpga / 不 dow)
echo  [3] XSCT 烧录 (无 rst-system: psu_init -^> fpga -^> dow -^> con)
echo ============================================================
echo 请先: 关闭 Vivado HW Manager; 若上轮 psu_init 卡住请断电重上电
echo.

call "%SCRIPT_DIR%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1

set "STEP_FAIL="

echo.
echo ===== [1/3] patch psu_init DDR from factory =====
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%patch_psu_ddr_from_factory.ps1"
if errorlevel 1 (
  echo ===== FAIL at step 1 =====
  exit /b 1
)

echo.
echo ===== [2/3] DAP probe =====
call "%SCRIPT_DIR%run_jtag_diagnose.bat"
if errorlevel 1 (
  echo ===== FAIL at step 2 (DAP unstable, skip program) =====
  exit /b 1
)

echo.
echo ===== [3/3] XSCT program (program_jtag.tcl) =====
if not exist "%SCRIPT_DIR%imgproc_baremetal\Debug\imgproc_baremetal.elf" (
  echo ELF missing, building...
  call "%SCRIPT_DIR%deploy.bat" build
  if errorlevel 1 (
    echo ===== FAIL at build =====
    exit /b 1
  )
)

del "%SCRIPT_DIR%.program_jtag.ok" 2>nul
xsct "%SCRIPT_DIR%program_jtag.tcl" > "%SCRIPT_DIR%jtag_flow_program.log" 2>&1
type "%SCRIPT_DIR%jtag_flow_program.log"

if not exist "%SCRIPT_DIR%.program_jtag.ok" (
  echo.
  echo ===== RESULT: FAIL at step 3 (psu_init/program) =====
  echo 若仍见 FD080030: 板子断电重上电后仅重跑本脚本
  echo 若 Vivado 已 Program DONE=HIGH: deploy.bat program-elf
  exit /b 1
)
del "%SCRIPT_DIR%.program_jtag.ok" 2>nul

echo.
echo ===== RESULT: PASS =====
echo 串口 COM3 115200 查看 baremetal 输出
exit /b 0
