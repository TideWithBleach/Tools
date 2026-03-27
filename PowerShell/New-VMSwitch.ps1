& {
    Set-StrictMode -Version 2.0
    $ErrorActionPreference = 'Stop'

    function Write-Section([string]$Text) {
        Write-Host "`n=== $Text ===" -ForegroundColor Cyan
    }

    function Read-NonEmpty([string]$Prompt) {
        do {
            $v = (Read-Host $Prompt).Trim()
        } until (-not [string]::IsNullOrWhiteSpace($v))
        return $v
    }

    function Read-SwitchName {
        do {
            $name = (Read-Host "Enter the VM Switch Name (e.g. WAFSCADANet)").Trim()
            if ([string]::IsNullOrWhiteSpace($name) -or $name -match '[=\$]') {
                Write-Warning "Invalid switch name. Use only the switch name (no '=' or '$' characters)."
                $name = $null
            }
        } until ($name)
        return $name
    }

    function Test-WinRM([string]$ComputerName) {
        try {
            Test-WSMan -ComputerName $ComputerName -ErrorAction Stop | Out-Null
            return $true
        } catch {
            return $false
        }
    }

    function Get-HostNicChoices {
        param(
            [Parameter(Mandatory)][string]$ComputerName
        )

        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            $nics = @(Get-NetAdapter -Physical -ErrorAction Stop)

            $extSwitches = @()
            if (Get-Command Get-VMSwitch -ErrorAction SilentlyContinue) {
                $extSwitches = @(Get-VMSwitch | Where-Object SwitchType -eq 'External')
            }

            foreach ($nic in $nics) {
                $inUseBy = $null
                if ($extSwitches.Count -gt 0) {
                    $match = $extSwitches | Where-Object {
                        $desc = @($_.NetAdapterInterfaceDescription) | Where-Object { $_ }
                        $desc -contains $nic.InterfaceDescription
                    } | Select-Object -First 1
                    if ($match) { $inUseBy = $match.Name }
                }

                $vmspp = 'Unknown'
                try {
                    $b = Get-NetAdapterBinding -Name $nic.Name -ComponentID vms_pp -ErrorAction Stop
                    $vmspp = $b.Enabled
                } catch { }

                [pscustomobject]@{
                    ComputerName            = $env:COMPUTERNAME
                    NicName                 = $nic.Name
                    InterfaceAlias          = $nic.InterfaceAlias
                    InterfaceDescription    = $nic.InterfaceDescription
                    Status                  = $nic.Status
                    LinkSpeed               = $nic.LinkSpeed
                    MacAddress              = $nic.MacAddress
                    VmsPpEnabled            = $vmspp
                    InUseByExternalVSwitch  = $inUseBy
                }
            }
        }
    }

    function Select-NicForHost {
        param(
            [Parameter(Mandatory)][string]$ComputerName
        )

        Write-Section "NIC selection for $ComputerName"

        $choices = @(Get-HostNicChoices -ComputerName $ComputerName)
        if (-not $choices -or $choices.Count -eq 0) {
            throw "No physical NICs were returned from $ComputerName."
        }

        for ($i = 0; $i -lt $choices.Count; $i++) {
            $c = $choices[$i]
            $inUse = if ($c.InUseByExternalVSwitch) { "IN USE by External vSwitch: '$($c.InUseByExternalVSwitch)'" } else { "Free (no External vSwitch detected)" }
            $vmspp = "vms_pp=$($c.VmsPpEnabled)"
            Write-Host ("[{0}] Alias='{1}' | Name='{2}' | Status={3} | Speed={4} | {5} | {6}" -f ($i+1), $c.InterfaceAlias, $c.NicName, $c.Status, $c.LinkSpeed, $vmspp, $inUse)
            Write-Host ("     Desc: {0}" -f $c.InterfaceDescription) -ForegroundColor DarkGray
            Write-Host ("     MAC : {0}" -f $c.MacAddress) -ForegroundColor DarkGray
        }

        do {
            $sel = Read-Host "Select NIC number for $ComputerName (1-$($choices.Count))"
            $n = 0
            if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $choices.Count) {
                return $choices[$n-1]
            }
            Write-Warning "Invalid selection. Enter a number from 1 to $($choices.Count)."
        } while ($true)
    }

    #region Prompts
    Write-Section "Inputs"
    $vmswitchname = Read-SwitchName
    $host1 = Read-NonEmpty "Enter the first computer hostname (e.g., Host1)"
    $host2 = Read-NonEmpty "Enter the second computer hostname (e.g., Host2)"

    if ($host1 -eq $host2) {
        Write-Warning "You entered the same host twice ($host1). This script expects two distinct hosts."
        throw "Hosts must be distinct."
    }
    $computername = @($host1, $host2)
    #endregion

    #region WinRM check (no ICMP/ping)
    Write-Section "Remoting (WinRM) Check"
    $bad = @()
    foreach ($c in $computername) {
        if (Test-WinRM -ComputerName $c) {
            Write-Host "$($c): WinRM OK" -ForegroundColor Green
        } else {
            Write-Host "$($c): WinRM FAILED" -ForegroundColor Red
            $bad += $c
        }
    }
    if ($bad.Count -gt 0) {
        throw "WinRM/PowerShell remoting not available on: $($bad -join ', ')"
    }
    #endregion

    #region NIC selection per host
    $nic1 = Select-NicForHost -ComputerName $host1
    $nic2 = Select-NicForHost -ComputerName $host2

    Write-Section "Selections"
    Write-Host "$host1 -> Alias '$($nic1.InterfaceAlias)' (Name '$($nic1.NicName)')" -ForegroundColor Yellow
    Write-Host "$host2 -> Alias '$($nic2.InterfaceAlias)' (Name '$($nic2.NicName)')" -ForegroundColor Yellow
    #endregion

    #region Remote execution per host
    Write-Section "Create/Validate vSwitch"

    $remoteScript = {
        param(
            [string]$SwitchName,
            [string]$NicAlias
        )

        $r = [ordered]@{
            ComputerName         = $env:COMPUTERNAME
            SwitchName           = $SwitchName
            NicAlias             = $NicAlias
            NicName              = $null
            NicInterfaceDesc     = $null
            NicStatus            = $null
            VmsPpEnabled_Before  = $null
            VmsPpEnabled_After   = $null
            BoundToOtherSwitch   = $null
            SwitchAction         = $null
            Success              = $false
            Error                = $null
        }

        function Test-NicBoundToSwitch {
            param($VMSwitch, $Nic)
            $desc = @($VMSwitch.NetAdapterInterfaceDescription) | Where-Object { $_ }
            return ($desc -contains $Nic.InterfaceDescription)
        }

        try {
            if (-not (Get-Command Get-VMSwitch -ErrorAction SilentlyContinue)) {
                throw "Hyper-V cmdlets not available on this host."
            }

            $nic = Get-NetAdapter -InterfaceAlias $NicAlias -ErrorAction Stop
            $r.NicName          = $nic.Name
            $r.NicInterfaceDesc = $nic.InterfaceDescription
            $r.NicStatus        = $nic.Status

            # vms_pp binding check/enable
            $b = Get-NetAdapterBinding -Name $nic.Name -ComponentID vms_pp -ErrorAction Stop
            $r.VmsPpEnabled_Before = $b.Enabled

            if (-not $b.Enabled) {
                Enable-NetAdapterBinding -Name $nic.Name -ComponentID vms_pp -ErrorAction SilentlyContinue | Out-Null
                $b2 = Get-NetAdapterBinding -Name $nic.Name -ComponentID vms_pp -ErrorAction Stop
                $r.VmsPpEnabled_After = $b2.Enabled

                if (-not $b2.Enabled) {
                    throw "vms_pp (Hyper-V Extensible Virtual Switch) is disabled and could not be enabled. NIC may be link-down, driver-enforced, or managed by policy/intent."
                }
            } else {
                $r.VmsPpEnabled_After = $b.Enabled
            }

            # Block if NIC is bound to a different external switch
            $external = @(Get-VMSwitch | Where-Object SwitchType -eq 'External')
            $bound = foreach ($sw in $external) { if (Test-NicBoundToSwitch -VMSwitch $sw -Nic $nic) { $sw } }
            $foreign = $bound | Where-Object Name -ne $SwitchName
            if ($foreign) {
                $r.BoundToOtherSwitch = ($foreign.Name -join ', ')
                throw "NIC is already bound to another External vSwitch: $($r.BoundToOtherSwitch). Refusing to proceed."
            }

            # If switch exists, validate binding
            $existing = Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue
            if ($existing) {
                if (-not (Test-NicBoundToSwitch -VMSwitch $existing -Nic $nic)) {
                    throw "VMSwitch '$SwitchName' exists but is not bound to NIC '$NicAlias'."
                }
                $r.SwitchAction = "AlreadyExistsAndBound"
                $r.Success = $true
                return [pscustomobject]$r
            }

            # Create switch using NIC.Name (robust)
            New-VMSwitch -Name $SwitchName -AllowManagementOS:$false -NetAdapterName $nic.Name -ErrorAction Stop | Out-Null
            $r.SwitchAction = "Created"
            $r.Success = $true
            return [pscustomobject]$r
        }
        catch {
            $r.Error = $_.Exception.Message
            $r.Success = $false
            return [pscustomobject]$r
        }
    }

    $results = @()

    $perHostPlan = @(
        [pscustomobject]@{ Host = $host1; NicAlias = $nic1.InterfaceAlias }
        [pscustomobject]@{ Host = $host2; NicAlias = $nic2.InterfaceAlias }
    )

    foreach ($p in $perHostPlan) {
        try {
            $results += Invoke-Command -ComputerName $p.Host -ScriptBlock $remoteScript -ArgumentList $vmswitchname, $p.NicAlias -ErrorAction Stop
        }
        catch {
            $results += [pscustomobject]@{
                ComputerName         = $p.Host
                SwitchName           = $vmswitchname
                NicAlias             = $p.NicAlias
                NicName              = $null
                NicInterfaceDesc     = $null
                NicStatus            = $null
                VmsPpEnabled_Before  = $null
                VmsPpEnabled_After   = $null
                BoundToOtherSwitch   = $null
                SwitchAction         = $null
                Success              = $false
                Error                = "Invoke-Command failed: $($_.Exception.Message)"
            }
        }
    }

    # Display results
    Write-Section "Results"
    $results | Sort-Object ComputerName | Format-Table -AutoSize

    # Optional CSV log
    $logPath = Join-Path $env:TEMP ("vSwitch_{0}_{1}.csv" -f $vmswitchname, (Get-Date -Format "yyyyMMdd_HHmmss"))
    $results | Export-Csv -Path $logPath -NoTypeInformation
    Write-Host "`nLog written to: $logPath" -ForegroundColor DarkCyan

    # Fail run if any host failed
    $failed = @($results | Where-Object { -not $_.Success })
    if ($failed.Count -gt 0) {
        Write-Host "`nFAILED HOSTS DETAILS:" -ForegroundColor Red
        $failed | Select-Object ComputerName, Error, NicAlias, NicName, NicStatus, VmsPpEnabled_Before, VmsPpEnabled_After, BoundToOtherSwitch | Format-List
        throw "One or more hosts failed. Review FAILED HOSTS DETAILS above."
    }

    Write-Host "`nAll hosts succeeded." -ForegroundColor Green
    #endregion
}
