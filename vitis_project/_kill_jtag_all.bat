@echo off
setlocal
echo [jtag] force stop hung xsct/hw_server/cs_server/xsdb...
taskkill /F /IM xsct.exe /T >nul 2>&1
taskkill /F /IM hw_server.exe /T >nul 2>&1
taskkill /F /IM cs_server.exe /T >nul 2>&1
taskkill /F /IM xsdb.exe /T >nul 2>&1
ping 127.0.0.1 -n 2 >nul
exit /b 0
