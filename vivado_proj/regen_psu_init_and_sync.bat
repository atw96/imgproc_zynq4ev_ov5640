@echo off
setlocal
set "ROOT=%~dp0.."
set "VIVADO_PROJ=%~dp0"

echo ===== 重新生成 psu_init（对齐 factory DDR 参数，保留本工程 GEM3）=====
echo 参考: doc\factory_vivado\board_test ... psu_init.tcl 仅作 DDR 对照，不可整文件替换
echo.

set "VIVADO_ROOT="
if defined XILINX_VIVADO if exist "%XILINX_VIVADO%\settings64.bat" set "VIVADO_ROOT=%XILINX_VIVADO%"
if "%VIVADO_ROOT%"=="" if exist "D:\Xilinx\Vivado\2020.1\settings64.bat" set "VIVADO_ROOT=D:\Xilinx\Vivado\2020.1"
if "%VIVADO_ROOT%"=="" (echo ERROR: Vivado not found & exit /b 1)
call "%VIVADO_ROOT%\settings64.bat"

cd /d "%VIVADO_PROJ%"
vivado -mode batch -source scripts/apply_alinx_ddr_config.tcl -log regen_psu_init.log -journal regen_psu_init.jou
if errorlevel 1 (
  echo WARN: apply_alinx_ddr 有告警，请查看 regen_psu_init.log
)

for %%F in (
  "%VIVADO_PROJ%imgproc_axu4evb_ov5640.srcs\sources_1\bd\zynq_imgproc_bd\ip\zynq_imgproc_bd_zynq_ultra_ps_e_0_0\psu_init.tcl"
) do (
  if exist %%F (
    echo 新 psu_init: %%~zF bytes  %%F
    findstr /C:"GEM3" %%F >nul && echo   OK: 含 GEM3 配置 || echo   WARN: 无 GEM3，勿用 factory 整文件替换
  )
)

echo.
echo 同步到 Vitis...
cd /d "%ROOT%\vitis_project"
call deploy.bat sync
echo 完成。JTAG: Vivado Program Device 后 deploy.bat program-elf
exit /b 0
