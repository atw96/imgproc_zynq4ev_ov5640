@echo off
setlocal
set "SCRIPT_DIR=%~dp0"
cd /d "%SCRIPT_DIR%"

REM 解析 Vitis 2020.1 根目录并调用 settings64.bat（保证 xsct 在 PATH）
set "VITIS_ROOT="
if defined XILINX_VITIS (
  if exist "%XILINX_VITIS%\settings64.bat" set "VITIS_ROOT=%XILINX_VITIS%"
)
if "%VITIS_ROOT%"=="" if exist "C:\Xilinx\Vitis\2020.1\settings64.bat" set "VITIS_ROOT=C:\Xilinx\Vitis\2020.1"
if "%VITIS_ROOT%"=="" if exist "D:\Xilinx\Vitis\2020.1\settings64.bat" set "VITIS_ROOT=D:\Xilinx\Vitis\2020.1"
if "%VITIS_ROOT%"=="" (
  echo ERROR: 未找到 Vitis 2020.1。请设置环境变量 XILINX_VITIS 指向安装目录，或编辑本 bat 增加路径。
  exit /b 1
)
call "%VITIS_ROOT%\settings64.bat"

where xsct >nul 2>&1
if errorlevel 1 (
  echo ERROR: 找不到 xsct.exe。
  exit /b 1
)

echo Running: xsct "%SCRIPT_DIR%create_vitis_workspace.tcl"
xsct "%SCRIPT_DIR%create_vitis_workspace.tcl"
if errorlevel 1 (
  echo ERROR: xsct 执行失败。
  exit /b 1
)
echo OK.
exit /b 0
