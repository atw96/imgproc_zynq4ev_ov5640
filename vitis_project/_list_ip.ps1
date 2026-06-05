Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -like '192.168.1.*' } |
    Format-Table InterfaceAlias, InterfaceIndex, IPAddress, PrefixLength
