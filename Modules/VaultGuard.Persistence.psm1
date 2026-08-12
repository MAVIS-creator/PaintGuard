# ==============================================================================
# Module: VaultGuard.Persistence.psm1
# Purpose: Persistence Audit & Remediation (Registry, Tasks, WMI, Defender, Startup)
# ==============================================================================

function Get-VaultGuardPersistenceAudit {
    [CmdletBinding()]
    param()

    $Findings = @()

    # 1. Registry Run & RunOnce (HKCU & HKLM, 32-bit & 64-bit)
    $RegPaths = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\RunOnce"
    )

    foreach ($RegPath in $RegPaths) {
        if (Test-Path $RegPath) {
            $Props = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
            foreach ($PropName in $Props.PSObject.Properties.Name) {
                if ($PropName -match "^PS") { continue }
                $Val = $Props.$PropName
                if ($Val -match "paint\.exe" -or $Val -match "paint\.lnk" -or $Val -match "wscript.*\.vbs" -or $Val -match "cscript.*\.vbs" -or $Val -match "powershell.*\.vbs") {
                    $Findings += [PSCustomObject]@{
                        Location = $RegPath
                        Name     = $PropName
                        Value    = $Val
                        Type     = "Registry Run Hook"
                        Severity = "CRITICAL"
                    }
                }
            }
        }
    }

    # 2. Startup Folder Shortcuts (.lnk)
    $StartupPaths = @(
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\StartUp"
    )

    foreach ($StartupPath in $StartupPaths) {
        if (Test-Path $StartupPath) {
            $Shortcuts = Get-ChildItem -LiteralPath $StartupPath -Filter "*.lnk" -ErrorAction SilentlyContinue
            foreach ($Lnk in $Shortcuts) {
                if ($Lnk.Name -match "paint\.lnk" -or $Lnk.Name -match "v.*\.lnk") {
                    $Findings += [PSCustomObject]@{
                        Location = $StartupPath
                        Name     = $Lnk.Name
                        Value    = $Lnk.FullName
                        Type     = "Startup Shortcut"
                        Severity = "HIGH"
                    }
                }
            }
        }
    }

    # 3. Scheduled Tasks
    try {
        $Tasks = Get-ScheduledTask -ErrorAction SilentlyContinue
        foreach ($Task in $Tasks) {
            foreach ($Action in $Task.Actions) {
                if ($Action.Execute -match "paint\.exe" -or $Action.Arguments -match "\.vbs") {
                    $Findings += [PSCustomObject]@{
                        Location = "TaskScheduler:\$($Task.TaskPath)"
                        Name     = $Task.TaskName
                        Value    = "$($Action.Execute) $($Action.Arguments)"
                        Type     = "Scheduled Task"
                        Severity = "HIGH"
                    }
                }
            }
        }
    } catch {}

    # 4. WMI Event Subscriptions
    try {
        $WmiConsumers = Get-CimInstance -Namespace "root\subscription" -ClassName "__EventConsumer" -ErrorAction SilentlyContinue
        foreach ($Consumer in $WmiConsumers) {
            if ($Consumer.CommandLineTemplate -match "paint\.exe" -or $Consumer.CommandLineTemplate -match "\.vbs") {
                $Findings += [PSCustomObject]@{
                    Location = "WMI Subscription"
                    Name     = $Consumer.Name
                    Value    = $Consumer.CommandLineTemplate
                    Type     = "WMI Hook"
                    Severity = "CRITICAL"
                }
            }
        }
    } catch {}

    return @{
        ThreatsFound = $Findings.Count
        Findings     = $Findings
    }
}

function Repair-VaultGuardPersistence {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$DryRun
    )

    $Audit = Get-VaultGuardPersistenceAudit
    $Actions = @()

    if ($DryRun -or $WhatIfPreference) {
        return @{
            Success         = $true
            RemediatedCount = $Audit.ThreatsFound
            Message         = "DryRun: Would repair $($Audit.ThreatsFound) persistence hooks"
            Actions         = $Audit.Findings | ForEach-Object { "Would remove $($_.Type): $($_.Name) at $($_.Location)" }
        }
    }

    foreach ($Finding in $Audit.Findings) {
        try {
            if ($Finding.Type -eq "Registry Run Hook") {
                Remove-ItemProperty -Path $Finding.Location -Name $Finding.Name -Force -ErrorAction Stop
                $Actions += "Removed Registry Run hook: $($Finding.Name) from $($Finding.Location)"
            } elseif ($Finding.Type -eq "Startup Shortcut") {
                Remove-Item -Path $Finding.Value -Force -ErrorAction Stop
                $Actions += "Deleted startup shortcut: $($Finding.Value)"
            } elseif ($Finding.Type -eq "Scheduled Task") {
                Unregister-ScheduledTask -TaskName $Finding.Name -Confirm:$false -ErrorAction Stop
                $Actions += "Unregistered malicious scheduled task: $($Finding.Name)"
            } elseif ($Finding.Type -eq "WMI Hook") {
                Get-CimInstance -Namespace "root\subscription" -ClassName "__EventConsumer" | Where-Object { $_.Name -eq $Finding.Name } | Remove-CimInstance -ErrorAction SilentlyContinue
                Get-CimInstance -Namespace "root\subscription" -ClassName "__EventFilter" | Where-Object { $_.Name -eq $Finding.Name } | Remove-CimInstance -ErrorAction SilentlyContinue
                $Actions += "Purged malicious WMI Event Consumer & Filter: $($Finding.Name)"
            }
        } catch {
            $Actions += "Failed to repair $($Finding.Name): $($_.Exception.Message)"
        }
    }

    return @{
        Success         = $true
        RemediatedCount = $Actions.Count
        Actions         = $Actions
    }
}

Export-ModuleMember -Function Get-VaultGuardPersistenceAudit, Repair-VaultGuardPersistence
