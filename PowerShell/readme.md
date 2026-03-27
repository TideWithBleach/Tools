# This will prompt for input and create a single VM Switch with a single NIC for a 2 node Azure Local Cluster

## Run (Windows PowerShell 5.1)

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((New-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/TideWithBleach/Tools/new/main/PowerShell/New-VMSwitch.ps1'))"
```

```powershell
$uri = "https://github.com/TideWithBleach/Tools/new/main/PowerShell/New-VMSwitch.ps1"
$out = Join-Path $env:TEMP "New-VMSwitch.ps1"
Invoke-WebRequest -Uri $uri -OutFile $out -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $out
```
If your environment uses a proxy and GitHub is allowed but requires proxy, you might need:

```powershell
Invoke-WebRequest -Uri $uri -OutFile $out -Proxy "http://proxy:8080" -ProxyUseDefaultCredentials
```

## Run it from a link

```powershell
$uri = "https://github.com/TideWithBleach/Tools/new/main/PowerShell/New-VMSwitch.ps1"
$out = Join-Path $env:TEMP "New-WafVSwitch.ps1"

Invoke-WebRequest -Uri $uri -OutFile $out -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $out
```
