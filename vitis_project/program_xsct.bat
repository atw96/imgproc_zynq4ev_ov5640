@echo off
cd /d "%~dp0"
call deploy.bat program
exit /b %ERRORLEVEL%
