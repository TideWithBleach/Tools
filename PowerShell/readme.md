# New-VMSwitch.ps1
This will prompt for input and create a single VM Switch with a single NIC for a 2 node Azure Local Cluster
<img width="1036" height="168" alt="image" src="https://github.com/user-attachments/assets/a682d2ed-6a59-440f-8c13-652f0cecc05d" />

```powershell
$uri = "https://raw.githubusercontent.com/TideWithBleach/Tools/main/PowerShell/New-VMSwitch.ps1"
$out = Join-Path $env:TEMP "New-VMSwitch.ps1"
Invoke-WebRequest -Uri $uri -OutFile $out -UseBasicParsing
powershell.exe -NoProfile -ExecutionPolicy Bypass -File $out

```
