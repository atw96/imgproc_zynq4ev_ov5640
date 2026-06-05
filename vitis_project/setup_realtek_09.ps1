# 09_ps_net: Realtek(24) 仅用于直连板 192.168.1.10
$IfIndex = 24
$PcIp = "192.168.1.100"
$BoardIp = "192.168.1.10"

Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -ne $PcIp } |
    ForEach-Object {
        Remove-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength -Confirm:$false -ErrorAction SilentlyContinue
    }
if (-not (Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object IPAddress -eq $PcIp)) {
    New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $PcIp -PrefixLength 24 | Out-Null
}
netsh advfirewall set allprofiles state off | Out-Null
route delete $BoardIp 2>$null | Out-Null
cmd /c "route add $BoardIp mask 255.255.255.255 $PcIp metric 1 IF $IfIndex"
Get-NetAdapter -InterfaceIndex $IfIndex | Format-Table Name, LinkSpeed, Status
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
