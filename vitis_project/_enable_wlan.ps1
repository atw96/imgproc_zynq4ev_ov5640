Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'Wi-Fi|WLAN|Wireless' } |
    ForEach-Object {
        if ($_.Status -ne 'Up') { Enable-NetAdapter -Name $_.Name -Confirm:$false; Write-Host "Enabled $($_.Name)" }
    }
