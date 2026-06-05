Get-Process xsct, hw_server -ErrorAction SilentlyContinue | Stop-Process -Force
$conn = Get-NetTCPConnection -LocalPort 3121 -ErrorAction SilentlyContinue
if ($null -ne $conn) {
    $conn | ForEach-Object { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
}
Start-Sleep -Seconds 2
Write-Host "JTAG cleared"
