# Motorcomm 无指示灯时用 Windows 判断链路
Write-Host "=== Motorcomm adapters ===" -ForegroundColor Cyan
Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*YT6801*' } |
    Format-Table InterfaceIndex, Name, Status, LinkSpeed, MediaConnectionState

$up = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*YT6801*' -and $_.Status -eq 'Up' }
if ($up) {
    Write-Host "LINK OK: $($up.Name) $($up.LinkSpeed) (no LED needed)" -ForegroundColor Green
    Get-NetIPAddress -InterfaceIndex $up.InterfaceIndex -AddressFamily IPv4 |
        Format-Table IPAddress, PrefixLength
} else {
    Write-Host "No Up Motorcomm - check cable to YT6801 port" -ForegroundColor Yellow
}
