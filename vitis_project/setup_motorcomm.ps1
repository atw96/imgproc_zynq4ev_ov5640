# setup_motorcomm.ps1 - 配置 Motorcomm 直连 IP
$ifIndex = 26
$ip = "192.168.1.100"
$prefix = 24

# 移除 APIPA
Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like "169.254.*" } |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

# 设置静态 IP（若已存在则跳过）
$existing = Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $ip }
if (-not $existing) {
    New-NetIPAddress -InterfaceIndex $ifIndex -IPAddress $ip -PrefixLength $prefix -ErrorAction SilentlyContinue | Out-Null
}

# 关闭防火墙（调试期间）
netsh advfirewall set allprofiles state off | Out-Null

# 显示状态
Get-NetAdapter -InterfaceIndex $ifIndex | Select-Object Name, LinkSpeed, Status
Get-NetIPAddress -InterfaceIndex $ifIndex -AddressFamily IPv4 | Select-Object IPAddress, AddressState
