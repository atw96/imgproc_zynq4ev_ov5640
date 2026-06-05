@echo off
setlocal
set "PSU=%~dp0zynq_imgproc_platform\hw\psu_init.tcl"
findstr /C:"0x00F022FF" "%PSU%" >nul || (echo ERROR: psu_init PHY wrong, run: python fix_psu_init.py & exit /b 1)
findstr /C:"GEM3" "%PSU%" >nul || (echo ERROR: psu_init missing GEM3 & exit /b 1)
findstr /C:"0x00F016CF" "%PSU%" >nul && (echo ERROR: psu_init has stale PHY 0x00F016CF & exit /b 1)
echo OK psu_init verified
exit /b 0
