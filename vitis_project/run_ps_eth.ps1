# 09_ps_net ps_eth：默认 Motorcomm；Realtek 用 -UseRealtek
param([switch]$UseRealtek)

$BoardIp = "10.0.0.10"
$PcIp = "10.0.0.100"

if ($UseRealtek) {
    & "$PSScriptRoot\setup_ps_eth_direct.ps1"
    $IfIndex = 24
} else {
    & "$PSScriptRoot\setup_ps_eth_motorcomm.ps1"
    if ($LASTEXITCODE -ne 0) { exit 1 }
    $nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*YT6801*' -and $_.Status -eq 'Up' } | Select-Object -First 1
    $IfIndex = $nic.InterfaceIndex
}

arp -d $BoardIp 2>$null

Write-Host "`n[1] Ping $BoardIp"
ping.exe -n 4 $BoardIp

Write-Host "`n[2] TCP echo port 7"
$t = Test-NetConnection -ComputerName $BoardIp -Port 7 -WarningAction SilentlyContinue
Write-Host "TcpTestSucceeded: $($t.TcpTestSucceeded)"

if ($t.TcpTestSucceeded) {
    Write-Host "`nPASS: ps_eth OK on Motorcomm. telnet $BoardIp 7"
} else {
    python "$PSScriptRoot\tcp_echo_test.py" 2>$null
    Write-Host "`nFAIL: check serial Board IP 10.0.0.10 + TCP echo port 7"
}
