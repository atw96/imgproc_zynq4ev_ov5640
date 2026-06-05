# 在 Realtek(24) 配置 192.168.10.100，不禁用 WiFi
$IfIndex = 24
$PcIp = "192.168.10.100"
$have = Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $PcIp }
if (-not $have) {
    New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $PcIp -PrefixLength 24 | Out-Null
}
Get-NetAdapter -InterfaceIndex $IfIndex | Format-Table Name, LinkSpeed, Status
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
Write-Host "Ping board (192.168.10.10)..."
ping.exe -n 3 192.168.10.10
