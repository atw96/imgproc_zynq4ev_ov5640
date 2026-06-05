@echo off
setlocal
echo [jtag] release hw_server only (do not kill Vivado)...
taskkill /F /IM hw_server.exe /T >nul 2>&1
ping 127.0.0.1 -n 3 >nul
exit /b 0
