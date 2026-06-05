param(
    [string]$FactoryPsu = "..\doc\factory_vivado\board_test.srcs\sources_1\bd\design_1\ip\design_1_zynq_ultra_ps_e_0_1\psu_init.tcl",
    [string]$TargetPsu = ".\zynq_imgproc_platform\hw\psu_init.tcl"
)
$ErrorActionPreference = "Stop"
function Resolve-RepoPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $PSScriptRoot $Path)
}
function Get-DdrInitBlock([string]$Text) {
    $m = [regex]::Match($Text, '(?s)(set psu_ddr_init_data \{.*?\r?\n\})\s*\r?\n+set psu_ddr_qos_init_data')
    if (-not $m.Success) { throw "未找到 psu_ddr_init_data 块" }
    return $m.Groups[1].Value.TrimEnd()
}
function Get-DdrPhyBlock([string]$Text) {
    $m = [regex]::Match($Text, '(?s)(proc psu_ddr_phybringup_data \{\} \{.*?\r?\n\})\s*$')
    if (-not $m.Success) { throw "未找到 psu_ddr_phybringup_data 块" }
    return $m.Groups[1].Value.TrimEnd()
}
function Replace-DdrInitBlock([string]$Text, [string]$Replacement) {
    $pattern = '(?s)set psu_ddr_init_data \{.*?\r?\n\}\s*\r?\n+set psu_ddr_qos_init_data'
    if (-not [regex]::IsMatch($Text, $pattern)) { throw "目标文件未找到 psu_ddr_init_data 块" }
    return [regex]::Replace($Text, $pattern, ($Replacement + "`r`n`r`nset psu_ddr_qos_init_data"), 1)
}
function Replace-DdrPhyBlock([string]$Text, [string]$Replacement) {
    $pattern = '(?s)proc psu_ddr_phybringup_data \{\} \{.*?\r?\n\}\s*$'
    if (-not [regex]::IsMatch($Text, $pattern)) { throw "目标文件未找到 psu_ddr_phybringup_data 块" }
    return [regex]::Replace($Text, $pattern, ($Replacement + "`r`n"), 1)
}
$factory = Resolve-RepoPath $FactoryPsu
$target = Resolve-RepoPath $TargetPsu
if (-not (Test-Path -LiteralPath $factory)) { throw "factory psu_init 不存在: $factory" }
if (-not (Test-Path -LiteralPath $target)) { throw "target psu_init 不存在: $target" }
$factoryText = Get-Content -LiteralPath $factory -Raw
$targetText = Get-Content -LiteralPath $target -Raw
if ($factoryText -notmatch "psu_ddr_phybringup_data" -or $targetText -notmatch "GEM3") {
    throw "factory 须含 DDR proc，target 须含 GEM3"
}
$factoryDdr = Get-DdrInitBlock $factoryText
$factoryPhy = Get-DdrPhyBlock $factoryText
$targetDdr = Get-DdrInitBlock $targetText
$targetPhy = Get-DdrPhyBlock $targetText
if (($factoryDdr -eq $targetDdr) -and ($factoryPhy -eq $targetPhy)) {
    Write-Host "OK: psu_init DDR 已与 doc/factory_vivado 一致，跳过 patch"
    exit 0
}
$backup = "$target.bak_$(Get-Date -Format yyyyMMdd_HHmmss)"
Copy-Item -LiteralPath $target -Destination $backup -Force
$patched = Replace-DdrInitBlock $targetText $factoryDdr
$patched = Replace-DdrPhyBlock $patched $factoryPhy
[System.IO.File]::WriteAllText($target, $patched)
$idePsu = Join-Path $PSScriptRoot "imgproc_baremetal\_ide\psinit\psu_init.tcl"
New-Item -ItemType Directory -Path (Split-Path $idePsu -Parent) -Force | Out-Null
Copy-Item -LiteralPath $target -Destination $idePsu -Force
Write-Host "OK: 已用 factory DDR 修补 psu_init (保留 GEM3)"
