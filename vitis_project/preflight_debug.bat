@echo off
cd /d "%~dp0"
py -3 "%~dp0preflight_debug.py" %*
exit /b %ERRORLEVEL%
