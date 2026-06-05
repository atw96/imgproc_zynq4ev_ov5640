@echo off
REM 网线插 Motorcomm 后执行；板子保持 10.0.0.10 net_test 固件
cd /d D:\Project\Vivado\zynq4ev\imgproc_mpsoc\vitis_project
powershell -NonInteractive -ExecutionPolicy Bypass -File run_ps_eth.ps1
pause
