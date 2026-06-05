# 同一根网线改插 Motorcomm 时用：192.168.10.100（与板 192.168.10.10 同网段）
$desc = "*YT6801*"
$nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like $desc -and $_.Status -eq 'Up' } | Select-Object -First 1
if (-not $nic) {
    Write-Host "未找到 Link Up 的 Motorcomm，请先把网线插到该网口"
    exit 1
}
$idx = $nic.InterfaceIndex
$PcIp = "192.168.10.100"
$have = Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $PcIp }
if (-not $have) {
    New-NetIPAddress -InterfaceIndex $idx -IPAddress $PcIp -PrefixLength 24 -ErrorAction Stop | Out-Null
}
netsh advfirewall set allprofiles state off | Out-Null
Write-Host "Motorcomm $($nic.Name) index=$idx -> $PcIp"
Get-NetAdapter -InterfaceIndex $idx | Format-Table Name, LinkSpeed, Status
Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
