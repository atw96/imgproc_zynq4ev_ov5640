$ifIndex = 24
$comp = (pktmon list | Select-String -Pattern "Id.*$ifIndex" -Context 0,3)
if (-not $comp) {
    $name = (Get-NetAdapter -InterfaceIndex $ifIndex).InterfaceDescription
    $comp = pktmon list | Select-String -Pattern [regex]::Escape($name) -Context 2,2
}
Write-Host "Adapter index $ifIndex :"
Get-NetAdapter -InterfaceIndex $ifIndex | Format-List Name, InterfaceDescription, MacAddress, LinkSpeed
pktmon list | Select-String -Pattern "Realtek|Ethernet|以太网|10\.|100" -Context 0,1
