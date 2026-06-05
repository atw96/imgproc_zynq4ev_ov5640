# 09_ps_net 直连：10.0.0.0/24，与 WiFi 192.168.x 完全分离
$IfIndex = 24
$PcIp = "10.0.0.100"
$Prefix = 24

Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    ForEach-Object {
        Remove-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength -Confirm:$false -ErrorAction SilentlyContinue
    }
New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $PcIp -PrefixLength $Prefix -ErrorAction Stop | Out-Null
netsh advfirewall set allprofiles state off | Out-Null

Get-NetAdapter -InterfaceIndex $IfIndex | Format-Table Name, LinkSpeed, Status
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
Write-Host "PC $PcIp <-> board 10.0.0.10 (ps_eth / net_test, WiFi untouched)"
