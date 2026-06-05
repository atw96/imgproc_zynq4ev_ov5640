param(
    [string]$DocXparam,
    [string]$OurXparam
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path $DocXparam)) { throw "missing $DocXparam" }
if (-not (Test-Path $OurXparam)) { throw "missing $OurXparam" }

$doc = Get-Content -LiteralPath $DocXparam -Raw
$our = Get-Content -LiteralPath $OurXparam -Raw

if ($our -match 'XPAR_XTTCPS_NUM_INSTANCES') {
    Write-Host '[patch] xparameters.h already has XTTCPS — skip'
    exit 0
}

$start = $doc.IndexOf('/* Definitions for driver TTCPS */')
$end = $doc.IndexOf('/* Definitions for driver UARTPS */', $start)
if ($start -lt 0 -or $end -lt 0) {
    throw 'cannot find TTCPS block in official xparameters.h'
}
$block = $doc.Substring($start, $end - $start).TrimEnd()

$marker = '/******************************************************************/' + "`r`n`r`n#endif"
$idx = $our.LastIndexOf($marker)
if ($idx -lt 0) {
    $marker = "/******************************************************************/`n`n#endif"
    $idx = $our.LastIndexOf($marker)
}
if ($idx -lt 0) {
    throw 'cannot find insertion point before #endif in our xparameters.h'
}

$new = $our.Substring(0, $idx) + $block + "`r`n`r`n" + $our.Substring($idx)
Set-Content -LiteralPath $OurXparam -Value $new -NoNewline
Write-Host '[patch] inserted TTCPS defines into xparameters.h'
