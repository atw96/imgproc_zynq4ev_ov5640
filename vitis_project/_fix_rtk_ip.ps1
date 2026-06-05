$IfIndex = 24
$PcIp = "192.168.1.100"
$alias = (Get-NetAdapter -InterfaceIndex $IfIndex).Name
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -ne $PcIp } |
    ForEach-Object { Remove-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength -Confirm:$false -ErrorAction SilentlyContinue }
if (-not (Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Where-Object IPAddress -eq $PcIp)) {
    New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $PcIp -PrefixLength 24 | Out-Null
}
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
