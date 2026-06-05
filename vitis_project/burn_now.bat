@echo off
:: burn_now.bat — 一键烧录（板子完整断电30秒上电后执行）
setlocal
set VITIS=D:\Xilinx\Vitis\2020.1
set PROJ=D:\Project\Vivado\zynq4ev\imgproc_mpsoc\vitis_project
set HW_SERVER=%VITIS%\bin\unwrapped\win64.o\hw_server.exe
set HW_PORT=7000

echo ===== [1] 杀掉残留 JTAG 进程 =====
taskkill /F /IM xsct.exe /T >nul 2>&1
taskkill /F /IM hw_server.exe /T >nul 2>&1
ping 127.0.0.1 -n 2 >nul

echo ===== [2] 加载 Xilinx 环境 =====
call "%VITIS%\settings64.bat"
if errorlevel 1 ( echo ERROR: settings64.bat 失败 & pause & exit /b 1 )

echo ===== [3] 启动 hw_server 端口 %HW_PORT% (避开 Windows 保留 3121) =====
start "hw_server" /B "%HW_SERVER%" -s tcp::%HW_PORT%
ping 127.0.0.1 -n 3 >nul

echo ===== [4] 开始烧录（约 90 秒）=====
set XSCT_HW_URL=TCP:127.0.0.1:%HW_PORT%
"%VITIS%\bin\xsct.bat" "%PROJ%\program_jtag.tcl"
if errorlevel 1 ( echo ERROR: 烧录失败 & taskkill /F /IM hw_server.exe /T >nul 2>&1 & pause & exit /b 1 )

taskkill /F /IM hw_server.exe /T >nul 2>&1
echo ===== 烧录成功！串口 115200 查看输出 =====
pause
