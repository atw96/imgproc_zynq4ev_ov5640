$PcIp = "192.168.1.100"
$IfIndex = 24
$other = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -eq $PcIp -and $_.InterfaceIndex -ne $IfIndex }
foreach ($o in $other) {
    Remove-NetIPAddress -InterfaceIndex $o.InterfaceIndex -IPAddress $PcIp -PrefixLength 24 -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "Removed $PcIp from index $($o.InterfaceIndex) $($o.InterfaceAlias)"
}
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -ne $PcIp } |
    ForEach-Object {
        Remove-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength -Confirm:$false -ErrorAction SilentlyContinue
    }
New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $PcIp -PrefixLength 24 | Out-Null
cmd /c "route add 192.168.1.10 mask 255.255.255.255 $PcIp metric 1 IF $IfIndex"
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
ping.exe -n 4 192.168.1.10
