# 用 .NET UdpClient 监听，绕开 Python 层
$port = 5002
$udp = New-Object System.Net.Sockets.UdpClient($port)
$udp.Client.ReceiveTimeout = 10000
$udp.EnableBroadcast = $true
$ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
Write-Host "[TEST] .NET UdpClient listening on :$port for 10s..."
try {
    $data = $udp.Receive([ref]$ep)
    Write-Host "[TEST] GOT $($data.Length) bytes from $ep"
} catch {
    Write-Host "[TEST] TIMEOUT - no UDP received in 10s"
}
$udp.Close()
