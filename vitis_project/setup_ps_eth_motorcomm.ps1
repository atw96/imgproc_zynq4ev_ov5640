# 09_ps_net 直连：Motorcomm YT6801，10.0.0.100（与板 10.0.0.10，非 192.168.x）
$PcIp = "10.0.0.100"
$BoardIp = "10.0.0.10"
$Prefix = 24

$nic = Get-NetAdapter | Where-Object {
    $_.InterfaceDescription -like '*YT6801*' -and $_.Status -eq 'Up'
} | Select-Object -First 1

if (-not $nic) {
    Write-Host "ERROR: No Link-Up Motorcomm (YT6801). Plug cable to Motorcomm port first."
    Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*YT6801*' } |
        Format-Table InterfaceIndex, Name, Status, LinkSpeed
    exit 1
}

$idx = $nic.InterfaceIndex
Write-Host "Motorcomm: $($nic.Name) index=$idx $($nic.LinkSpeed)"

# 从 Realtek 去掉 10.0.0.x，避免抢答
Get-NetIPAddress -InterfaceIndex 24 -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like '10.0.0.*' } |
    ForEach-Object {
        Remove-NetIPAddress -InterfaceIndex 24 -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength -Confirm:$false -ErrorAction SilentlyContinue
        Write-Host "Removed $($_.IPAddress) from Realtek (24)"
    }

Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    ForEach-Object {
        if ($_.IPAddress -ne $PcIp) {
            Remove-NetIPAddress -InterfaceIndex $idx -IPAddress $_.IPAddress -PrefixLength $_.PrefixLength -Confirm:$false -ErrorAction SilentlyContinue
        }
    }

if (-not (Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object IPAddress -eq $PcIp)) {
    New-NetIPAddress -InterfaceIndex $idx -IPAddress $PcIp -PrefixLength $Prefix -ErrorAction Stop | Out-Null
}

netsh advfirewall set allprofiles state off | Out-Null
route delete $BoardIp 2>$null | Out-Null
cmd /c "route add $BoardIp mask 255.255.255.255 $PcIp metric 1 IF $idx" 2>$null | Out-Null

Get-NetAdapter -InterfaceIndex $idx | Format-Table Name, LinkSpeed, Status
Get-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 | Format-Table IPAddress, PrefixLength
Write-Host "PC $PcIp <-> board $BoardIp (Motorcomm, WiFi untouched)"
