param(
    [string]$Port = "COM3",
    [int]$Baud = 115200,
    [int]$Seconds = 120,
    [string]$OutFile = ""
)
if (-not $OutFile) { $OutFile = Join-Path $PSScriptRoot "serial_capture.log" }
$sp = New-Object System.IO.Ports.SerialPort $Port, $Baud, "None", 8, "One"
$sp.ReadTimeout = 500
$sp.Open()
Write-Host "[serial] $Port @ $Baud -> $OutFile"
$sw = [System.IO.StreamWriter]::new($OutFile, $false, [System.Text.Encoding]::UTF8)
$deadline = (Get-Date).AddSeconds($Seconds)
try {
    while ((Get-Date) -lt $deadline) {
        try {
            $chunk = $sp.ReadExisting()
            if ($chunk) {
                $ts = Get-Date -Format "HH:mm:ss"
                foreach ($line in ($chunk -split "`r?`n")) {
                    if ($line) {
                        $row = "[$ts] $line"
                        Write-Host $row
                        $sw.WriteLine($row)
                    }
                }
                $sw.Flush()
            }
            Start-Sleep -Milliseconds 100
        } catch { Start-Sleep -Milliseconds 200 }
    }
} finally { $sp.Close(); $sw.Close() }
Write-Host "[serial] done"
