param(
    [switch]$Program
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

Write-Host ""
Write-Host "===== JTAG diagnose-first wrapper ====="
Write-Host "默认只做低风险 DAP 读寄存器诊断，不再自动多轮 psu_init。"
Write-Host ""

cmd /c "`"$Root\run_jtag_diagnose.bat`""
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

if ($Program) {
    Write-Host ""
    Write-Host "DAP OK，继续执行 deploy.bat program ..."
    cmd /c "`"$Root\deploy.bat`" program"
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "DAP OK。若要继续烧录，请显式运行："
Write-Host "  powershell -ExecutionPolicy Bypass -File run_jtag_auto.ps1 -Program"
exit 0
