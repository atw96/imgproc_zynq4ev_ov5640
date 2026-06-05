# ps_eth 诊断：ARP + TCP（ping 失败时仍看 TCP）
$BoardIp = "10.0.0.10"
$BoardMac = "00-0a-35-00-01-02"
$PcIp = "10.0.0.100"

& "$PSScriptRoot\setup_ps_eth_motorcomm.ps1"
if ($LASTEXITCODE -ne 0) { exit 1 }

$nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -like '*YT6801*' -and $_.Status -eq 'Up' } | Select-Object -First 1
$idx = $nic.InterfaceIndex

Write-Host "`n=== ARP before ===" -ForegroundColor Cyan
arp -a | Select-String "10.0.0"

netsh interface ipv4 add neighbors $nic.Name $BoardIp $BoardMac store=persistent 2>$null
arp -s $BoardIp $BoardMac

Write-Host "`n=== ARP after static ===" -ForegroundColor Cyan
arp -a | Select-String "10.0.0"

Write-Host "`n=== Ping (ICMP may be ignored by demo) ===" -ForegroundColor Cyan
ping.exe -n 3 $BoardIp

Write-Host "`n=== TCP :7 (ps_eth real test) ===" -ForegroundColor Cyan
python "$PSScriptRoot\ps_eth_echo_client.py"

Write-Host "`n=== pktmon during ping+TCP (comp 19) ===" -ForegroundColor Cyan
cmd /c "pktmon filter remove && pktmon start --capture --comp 19 --pkt-size 128 --file-name %TEMP%\pkt_mc.etl && ping 10.0.0.10 -n 4 && python D:\Project\Vivado\zynq4ev\imgproc_mpsoc\vitis_project\ps_eth_echo_client.py & pktmon stop && pktmon counters"
