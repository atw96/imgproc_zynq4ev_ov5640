param(
    [string]$Bind = "0.0.0.0",
    [int]$Port = 5002,
    [int]$Width = 1920,
    [int]$Height = 1080,
    [string]$Out = ""
)

function Ensure-Admin {
    $current = [Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not $current.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "需要管理员权限，正在提升..."
        $argList = @()
        if ($Bind) { $argList += "-Bind '$Bind'" }
        if ($Port) { $argList += "-Port $Port" }
        if ($Width) { $argList += "-Width $Width" }
        if ($Height) { $argList += "-Height $Height" }
        if ($Out) { $argList += "-Out '$Out'" }
        # 使用数组形式传参以避免引号/转义问题
        $invokeArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $PSCommandPath)
        if ($argList.Count -gt 0) { $invokeArgs += $argList }
        Start-Process -FilePath powershell -ArgumentList $invokeArgs -Verb runAs
        Exit
    }
}

Ensure-Admin

Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition)

$py = Get-Command python -ErrorAction SilentlyContinue
if (-not $py) {
    $py = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $py) {
    Write-Error "未找到 Python 可执行文件，请先安装 Python 并确保在 PATH 中。"
    Exit 1
}

$ruleName = "imgproc_udp_$Port"
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
$createdRule = $false
if (-not $existingRule) {
    Write-Host "添加防火墙规则: $ruleName"
    New-NetFirewallRule -DisplayName $ruleName -Direction Inbound -Action Allow -Protocol UDP -LocalPort $Port | Out-Null
    $createdRule = $true
} else {
    Write-Host "防火墙规则已存在: $ruleName"
}

try {
    $pyArgs = @()
    $pyArgs += "--bind"; $pyArgs += $Bind
    $pyArgs += "--port"; $pyArgs += $Port.ToString()
    $pyArgs += "--width"; $pyArgs += $Width.ToString()
    $pyArgs += "--height"; $pyArgs += $Height.ToString()
    if ($Out -ne "") { $pyArgs += "--out"; $pyArgs += $Out }

    $scriptPath = Join-Path -Path (Split-Path -Parent $MyInvocation.MyCommand.Definition) -ChildPath "udp_img_viewer.py"
    Write-Host "运行: python $scriptPath $($pyArgs -join ' ')"
    & $py.Source $scriptPath @pyArgs
}
finally {
    if ($createdRule) {
        Write-Host "移除防火墙规则: $ruleName"
        Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
    }
}

Write-Host "接收程序结束。"
