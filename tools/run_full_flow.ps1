<#
一键运行：JTAG 上板 + 本地 UDP 接收（端口 5002，避开 nidmsrv 占用的 5000）

用法：
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_full_flow.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_full_flow.ps1 -ElfOnly
#>

param(
    [switch]$ElfOnly,
    [string]$Bind = '0.0.0.0',
    [int]$Port = 5002,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [string]$Out = 'latest.png'
)

Set-StrictMode -Version Latest

$repo = Split-Path -Parent $MyInvocation.MyCommand.Definition
$vitis = Join-Path $repo 'vitis_project'
Push-Location $vitis

$jtagMode = if ($ElfOnly) { 'program-elf' } else { 'program' }
Write-Host "JTAG: deploy.bat $jtagMode"
& cmd /c "deploy.bat $jtagMode"
$jtagEc = $LASTEXITCODE
if ($jtagEc -ne 0) {
    Write-Error "JTAG 失败 (exit $jtagEc)。若 Vivado 已 Program bit，请加 -ElfOnly 重试。"
    Pop-Location
    exit 1
}
Pop-Location
$base = $repo

Write-Host "JTAG 上板完成，启动 UDP 接收器。"
$startArgs = @('-NoProfile','-ExecutionPolicy','Bypass','-File', (Join-Path $base 'start_udp_receiver.ps1'), '-Bind', $Bind, '-Port', $Port.ToString(), '-Width', $Width.ToString(), '-Height', $Height.ToString(), '-Out', $Out)
& powershell @startArgs
