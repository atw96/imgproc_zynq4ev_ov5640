# 拔插网线诊断：看哪块网卡 Link 状态变化（不需第二根网线）
Write-Host "=== 当前 Up 的以太网 ===" -ForegroundColor Cyan
Get-NetAdapter | Where-Object { $_.MediaType -eq '802.3' } |
    Format-Table InterfaceIndex, Name, InterfaceDescription, LinkSpeed, Status

Write-Host "`n=== 各网卡 IPv4 ===" -ForegroundColor Cyan
Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.InterfaceAlias -notmatch 'Loopback' } |
    Format-Table InterfaceIndex, InterfaceAlias, IPAddress, PrefixLength

Write-Host "`n=== 192.168.10.x ARP ===" -ForegroundColor Cyan
arp -a | Select-String "192.168.10"

Write-Host ""
Write-Host "Unplug board cable 3s then replug, run this script again, see which adapter Down/Up." -ForegroundColor Yellow
