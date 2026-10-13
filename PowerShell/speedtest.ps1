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
Write-Host "1. http://pzen.fpl.com:10262" -ForegroundColor Gray
Write-Host "2. http://lcpzen.fpl.com:10262" -ForegroundColor Gray
Write-Host "3. http://gopzen.fpl.com:10262" -ForegroundColor Gray
Write-Host "4. No proxy" -ForegroundColor Gray
Write-Host "5. Enter a custom proxy" -ForegroundColor Gray
$choice = Read-Host "Enter your choice (1-5)"

switch ($choice) {
    "1" { $Proxy = 'http://pzen.fpl.com:10262' }
    "2" { $Proxy = 'http://lcpzen.fpl.com:10262' }
    "3" { $Proxy = 'http://gopzen.fpl.com:10262' }
    "4" { $Proxy = $null }
    "5" { $Proxy = Read-Host "Enter custom proxy URL (e.g., http://proxy.example.com:8080)" }
    default {
        Write-Host "Invalid choice. Using no proxy."
        $Proxy = $null
    }
}

Write-Host ""
Write-Host "Select number of parallel connections:" -ForegroundColor Cyan
Write-Host "1. 1 connection (single-threaded)" -ForegroundColor Gray
Write-Host "2. 4 connections (default, recommended)" -ForegroundColor Gray
Write-Host "3. Custom number" -ForegroundColor Gray
$threadChoice = Read-Host "Enter your choice (1-3)"

switch ($threadChoice) {
    "1" { $threads = 1 }
    "2" { $threads = 4 }
    "3" {
        $customThreads = Read-Host "Enter number of connections (1-16)"
        if ($customThreads -match '^\d+$' -and $customThreads -ge 1 -and $customThreads -le 16) {
            $threads = [int]$customThreads
        } else {
            Write-Host "Invalid number. Using 4 connections." -ForegroundColor Yellow
            $threads = 4
        }
    }
    default {
        Write-Host "Invalid choice. Using 4 connections." -ForegroundColor Yellow
        $threads = 4
    }
}

$Url = 'https://files.hexaqa.com/size/100mb.bin'
$OutFile = "$env:TEMP\100mb.bin"

$hostname = $env:COMPUTERNAME
$ipAddress = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" -and $_.IPAddress -notlike "127.*" -and $_.IPAddress -notlike "169.254.*" } | Select-Object -First 1).IPAddress

if ($Proxy) {
    Write-Host "Downloading test file through proxy: $Proxy" -ForegroundColor Cyan
    Write-Host "Hostname: $hostname | IP: $ipAddress" -ForegroundColor Gray
} else {
    Write-Host "Downloading test file (no proxy)..." -ForegroundColor Cyan
    Write-Host "Hostname: $hostname | IP: $ipAddress" -ForegroundColor Gray
}

Write-Host "Using $threads parallel connections..." -ForegroundColor Gray
Write-Host ""

$sw = [System.Diagnostics.Stopwatch]::StartNew()

# Download file in parallel to simulate multi-threaded download
$jobs = @()
for ($i = 0; $i -lt $threads; $i++) {
    $tempFile = "$env:TEMP\100mb_$i.bin"
    $job = Start-Job -ScriptBlock {
        param($url, $outFile, $proxy)
        if ($proxy) {
            Invoke-WebRequest -Uri $url -Proxy $proxy -OutFile $outFile -UseBasicParsing
        } else {
            Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
        }
    } -ArgumentList $Url, $tempFile, $Proxy
    $jobs += $job
}

# Wait for all jobs to complete with progress display
$completed = 0
while ($completed -lt $threads) {
    $completed = 0
    foreach ($job in $jobs) {
        if ($job.State -eq 'Completed') {
            $completed++
        }
    }
    $percent = [math]::Round(($completed / $threads) * 100)
    Write-Progress -Activity "Multi-threaded download in progress" -Status "Completed $completed of $threads connections" -PercentComplete $percent
    Start-Sleep -Milliseconds 200
}
Write-Progress -Activity "Multi-threaded download in progress" -Completed

# Ensure all jobs are fully complete
$jobs | ForEach-Object { $_ | Wait-Job | Out-Null }

$sw.Stop()

# Calculate total bytes downloaded
$totalBytes = 0
for ($i = 0; $i -lt $threads; $i++) {
    $tempFile = "$env:TEMP\100mb_$i.bin"
    if (Test-Path $tempFile) {
        $totalBytes += (Get-Item $tempFile).Length
        Remove-Item $tempFile -Force
    }
}

# Cleanup jobs
$jobs | ForEach-Object { Remove-Job $_ }

$Mbps = [math]::Round(
    (($totalBytes * 8) / $sw.Elapsed.TotalSeconds) / 1MB,
    2
)

Write-Host ""
Write-Host "Bytes Downloaded: $totalBytes (connections: $threads)" -ForegroundColor Cyan

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
    Write-Host "Result: PASS - Speed meets Microsoft minimum (10 Mbps) and recommended ($MinRequiredMbps Mbps)" -ForegroundColor Green
} elseif ($Mbps -ge 10) {
    Write-Host "Result: WARNING - Speed meets Microsoft minimum (10 Mbps) but is below recommended $MinRequiredMbps Mbps" -ForegroundColor Yellow
} else {
    Write-Host "Result: FAIL - Speed is below both Microsoft minimum (10 Mbps) and recommended $MinRequiredMbps Mbps" -ForegroundColor Red
}
