# New-VMSwitch.ps1
This will prompt for input and create a single VM Switch with a single NIC for a 2 node Azure Local Cluster

## Run (Windows PowerShell 5.1)

```powershell
$uri = "https://raw.githubusercontent.com/TideWithBleach/Tools/main/PowerShell/New-VMSwitch.ps1"
$out = Join-Path $env:TEMP "New-VMSwitch.ps1"
Invoke-WebRequest -Uri $uri -OutFile $out -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $out

```
