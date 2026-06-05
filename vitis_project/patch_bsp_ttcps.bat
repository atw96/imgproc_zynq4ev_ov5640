@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "DOC_BSP=%ROOT%..\doc\course_s2\09_ps_net\vitis\design_1_wrapper\psu_cortexa53_0\standalone_domain\bsp\psu_cortexa53_0"
set "OUR_BSP=%ROOT%zynq_imgproc_platform\psu_cortexa53_0\standalone_psu_cortexa53_0\bsp\psu_cortexa53_0"

if not exist "%DOC_BSP%\libsrc\ttcps_v3_11" (
  echo ERROR: 官方 09_ps_net BSP 不存在: %DOC_BSP%
  exit /b 1
)
if not exist "%OUR_BSP%\include" (
  echo ERROR: 本工程 BSP 不存在: %OUR_BSP%
  exit /b 1
)

echo [patch] copy ttcps_v3_11 libsrc from 09_ps_net
xcopy /E /I /Y "%DOC_BSP%\libsrc\ttcps_v3_11" "%OUR_BSP%\libsrc\ttcps_v3_11\" >nul
if errorlevel 1 exit /b 1

echo [patch] copy xttcps headers
copy /Y "%DOC_BSP%\include\xttcps.h" "%OUR_BSP%\include\" >nul
copy /Y "%DOC_BSP%\include\xttcps_hw.h" "%OUR_BSP%\include\" >nul

echo [patch] merge TTC xparameters from 09_ps_net
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%patch_bsp_ttcps.ps1" -DocXparam "%DOC_BSP%\include\xparameters.h" -OurXparam "%OUR_BSP%\include\xparameters.h"
if errorlevel 1 exit /b 1

call "%ROOT%_setup_xilinx_env.bat"
if errorlevel 1 exit /b 1

echo [patch] rebuild BSP libs (make libs in bsp)
cd /d "%ROOT%zynq_imgproc_platform\psu_cortexa53_0\standalone_psu_cortexa53_0\bsp"
make libs
if errorlevel 1 exit /b 1

if not exist "%OUR_BSP%\include\xttcps.h" (
  echo ERROR: xttcps.h still missing
  exit /b 1
)
echo [patch] OK: BSP has xttcps
exit /b 0
