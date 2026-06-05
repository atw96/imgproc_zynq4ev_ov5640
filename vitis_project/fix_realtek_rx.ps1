# Realtek USB: 关 offload + 固定板子邻居（不换网卡）
$IfIndex = 24
$nic = Get-NetAdapter -InterfaceIndex $IfIndex -ErrorAction SilentlyContinue
if (-not $nic) { Write-Host "No adapter index $IfIndex"; exit 1 }

Disable-NetAdapterPowerManagement -Name $nic.Name -ErrorAction SilentlyContinue
$props = @(
    '*EEE', '*Energy*', '*Green*', '*Power Saving*',
    '*Large Send*', '*LSO*', '*Checksum*Offload*', '*Segmentation*'
)
foreach ($pat in $props) {
    Get-NetAdapterAdvancedProperty -Name $nic.Name -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like $pat } |
        ForEach-Object {
            Set-NetAdapterAdvancedProperty -Name $nic.Name -DisplayName $_.DisplayName -DisplayValue 'Disabled' -ErrorAction SilentlyContinue
        }
}
netsh interface ipv4 add neighbors "$($nic.Name)" 192.168.10.10 00-0a-35-00-01-02 store=persistent 2>$null
arp -s 192.168.10.10 00-0a-35-00-01-02
Write-Host "Done: offload off, neighbor 192.168.10.10 -> 00:0a:35:00:01:02 on $($nic.Name)"
