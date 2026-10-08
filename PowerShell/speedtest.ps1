Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Local Network Speed Test" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This script tests your internet connection by downloading a 100MB test file" -ForegroundColor Gray
Write-Host "and validates if it meets the bandwidth requirements for Azure Local deployment." -ForegroundColor Gray
Write-Host "Recommended minimum: 20 Mbps (Microsoft minimum: 10 Mbps)" -ForegroundColor Gray
Write-Host ""
Write-Host "For bandwidth requirements, see:" -ForegroundColor Gray
Write-Host "https://learn.microsoft.com/en-us/azure/azure-local/concepts/system-requirements-disaggregated" -ForegroundColor Cyan
Write-Host ""
Write-Host "Select a proxy option:" -ForegroundColor Cyan
Write-Host "1. http://lcpzen.fpl.com:10262" -ForegroundColor Gray
Write-Host "2. http://gopzen.fpl.com:10262" -ForegroundColor Gray
Write-Host "3. http://pzen.fpl.com:10262" -ForegroundColor Gray
Write-Host "4. No proxy" -ForegroundColor Gray
Write-Host "5. Enter a custom proxy" -ForegroundColor Gray
$choice = Read-Host "Enter your choice (1-5)"

switch ($choice) {
    "1" { $Proxy = 'http://lcpzen.fpl.com:10262' }
    "2" { $Proxy = 'http://gopzen.fpl.com:10262' }
    "3" { $Proxy = 'http://pzen.fpl.com:10262' }
    "4" { $Proxy = $null }
    "5" { $Proxy = Read-Host "Enter custom proxy URL (e.g., http://proxy.example.com:8080)" }
    default {
        Write-Host "Invalid choice. Using no proxy."
        $Proxy = $null
    }
}

$Url = 'https://proof.ovh.net/files/100Mb.dat'
$OutFile = "$env:TEMP\100Mb.dat"

if ($Proxy) {
    Write-Host "Downloading test file through proxy: $Proxy" -ForegroundColor Cyan
} else {
    Write-Host "Downloading test file (no proxy)..." -ForegroundColor Cyan
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()

if ($Proxy) {
    Invoke-WebRequest -Uri $Url -Proxy $Proxy -OutFile $OutFile -UseBasicParsing
} else {
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

$sw.Stop()

$file = Get-Item $OutFile

$Mbps = [math]::Round(
    (($file.Length * 8) / $sw.Elapsed.TotalSeconds) / 1MB,
    2
)

Write-Host ""
Write-Host "Bytes Downloaded: $($file.Length)" -ForegroundColor Cyan

$elapsed = $sw.Elapsed
if ($elapsed.TotalHours -ge 1) {
    $timeString = "$([math]::Floor($elapsed.TotalHours))h $($elapsed.Minutes)m $([math]::Round($elapsed.Seconds + $elapsed.Milliseconds/1000, 2))s"
} elseif ($elapsed.TotalMinutes -ge 1) {
    $timeString = "$($elapsed.Minutes)m $([math]::Round($elapsed.Seconds + $elapsed.Milliseconds/1000, 2))s"
} else {
    $timeString = "$([math]::Round($elapsed.TotalSeconds, 2))s"
}
Write-Host "Elapsed Time: $timeString" -ForegroundColor Cyan

Write-Host "Download Speed (Mbps): $Mbps" -ForegroundColor Yellow

$MinRequiredMbps = 20

if ($Mbps -ge $MinRequiredMbps) {
    Write-Host "Result: PASS - Speed meets minimum requirement of $MinRequiredMbps Mbps" -ForegroundColor Green
} elseif ($Mbps -ge 10) {
    Write-Host "Result: WARNING - Speed meets Microsoft minimum (10 Mbps) but is below recommended $MinRequiredMbps Mbps" -ForegroundColor Yellow
} else {
    Write-Host "Result: FAIL - Speed is below both Microsoft minimum (10 Mbps) and recommended $MinRequiredMbps Mbps" -ForegroundColor Red
}

Remove-Item $OutFile -Force
