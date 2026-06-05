param([int]$IfIndex = 24)

$BoardIp = "192.168.1.10"
$PcIp    = "192.168.1.100"
$Prefix  = 24

Write-Host "=== adapters ==="
Get-NetAdapter | Select-Object Name, InterfaceIndex, LinkSpeed, Status | Format-Table -AutoSize

$adapter = Get-NetAdapter -InterfaceIndex $IfIndex -ErrorAction SilentlyContinue
if (-not $adapter) { Write-Host "ERROR: adapter $IfIndex not found"; exit 1 }
Write-Host "Using: $($adapter.Name) index=$IfIndex speed=$($adapter.LinkSpeed) status=$($adapter.Status)"

Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -like '169.254.*' } |
    Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue

$existing = Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object { $_.IPAddress -eq $PcIp }
if (-not $existing) {
    New-NetIPAddress -InterfaceIndex $IfIndex -IPAddress $PcIp -PrefixLength $Prefix -ErrorAction SilentlyContinue | Out-Null
}

netsh advfirewall set allprofiles state off | Out-Null
Start-Sleep -Seconds 2

Write-Host "=== IP on adapter $IfIndex ==="
Get-NetIPAddress -InterfaceIndex $IfIndex -AddressFamily IPv4 | Select IPAddress, AddressState
Write-Host "=== ping $BoardIp from $PcIp ==="
ping.exe $BoardIp -n 3 -S $PcIp
