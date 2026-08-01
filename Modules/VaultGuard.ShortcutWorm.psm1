# ==============================================================================
# Module: VaultGuard.ShortcutWorm.psm1
# Purpose: Detector for Shortcut Worm Family (Vobfus, Dorkbot, Gamarue, Icon Swap)
# ==============================================================================

Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vault.psm1") -ErrorAction SilentlyContinue

$script:SystemDirWhitelist = @(
    "System Volume Information",
    '$RECYCLE.BIN',
    "System Recovery",
    "Recovery",
    "MSOCache",
    "Config.Msi"
)

function Get-ShortcutWormSignature {
    return @{
        Family      = "Shortcut Worm"
        Aliases     = @("Worm:Win32/Vobfus", "Win32/Dorkbot", "Win32/Gamarue", "1KB Shortcut Worm")
        Description = "Removable drive worm that swaps folder icons via desktop.ini (SHELL32.dll,7), hides user folders, and creates malicious .lnk shortcuts."
        Severity    = "HIGH"
    }
}

function Test-ShortcutWormThreat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [switch]$DeepPass
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return @{ Verdict = "Clean"; ConfidenceScore = 0; Indicators = @() }
    }

    $Indicators = @()
    $Confidence = 0
    $TargetDir = Get-Item -LiteralPath $Path -Force

    if (-not $TargetDir.PSIsContainer) {
        return @{ Verdict = "Clean"; ConfidenceScore = 0; Indicators = @() }
    }

    # Indicator 1: desktop.ini IconResource Hijack
    $DesktopIni = Join-Path $TargetDir.FullName "desktop.ini"
    if (Test-Path $DesktopIni) {
        try {
            $IniContent = Get-Content -Path $DesktopIni -Raw -ErrorAction SilentlyContinue
            if ($IniContent -match "SHELL32\.dll,7" -or $IniContent -match "IconResource=.*SHELL32\.dll,7") {
                $Indicators += "desktop.ini contains folder icon swap signature (SHELL32.dll,7)"
                $Confidence += 35
            }
        } catch {}
    }

    # Indicator 2: Malicious .lnk Flood Ratio
    $LnkFiles = Get-ChildItem -LiteralPath $TargetDir.FullName -Filter "*.lnk" -ErrorAction SilentlyContinue
    $SuspiciousLnks = 0

    foreach ($Lnk in $LnkFiles) {
        try {
            $WshShell = New-Object -ComObject WScript.Shell
            $Shortcut = $WshShell.CreateShortcut($Lnk.FullName)
            $Target = $Shortcut.TargetPath
            
            if ($Target -match "(cmd\.exe|wscript\.exe|cscript\.exe|powershell\.exe)" -or $Shortcut.Arguments -match "\.(vbs|js|bat|exe)") {
                $SuspiciousLnks++
            }
        } catch {}
    }

    if ($SuspiciousLnks -gt 0) {
        $Indicators += "Detected $SuspiciousLnks malicious .lnk shortcuts pointing to script interpreters"
        $Confidence += [Math]::Min(40, 20 + ($SuspiciousLnks * 10))
    }

    # Indicator 3: Hidden User Directories (excluding whitelist)
    $HiddenSubdirs = Get-ChildItem -LiteralPath $TargetDir.FullName -Directory -Force -ErrorAction SilentlyContinue | Where-Object {
        $_.Attributes -match "Hidden" -and ($script:SystemDirWhitelist -notcontains $_.Name)
    }

    if ($HiddenSubdirs -and $HiddenSubdirs.Count -gt 0) {
        $Indicators += "Found $($HiddenSubdirs.Count) hidden non-system user directories"
        $Confidence += 25
    }

    # Determine Verdict
    $Verdict = "Clean"
    if ($Confidence -ge 70) {
        $Verdict = "Infected"
    } elseif ($Confidence -ge 40) {
        $Verdict = "Suspicious"
    }

    return @{
        Family          = "Shortcut Worm"
        Verdict         = $Verdict
        ConfidenceScore = $Confidence
        Indicators      = $Indicators
        TargetDir       = $TargetDir.FullName
        SuspiciousLnks  = $LnkFiles
        HiddenDirs      = $HiddenSubdirs
    }
}

function Invoke-ShortcutWormRemediation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][object]$Threat,
        [switch]$DryRun
    )

    $Actions = @()

    if ($DryRun -or $WhatIfPreference) {
        return @{
            Success = $true
            Message = "DryRun: Would clean Shortcut Worm artifacts in $($Threat.TargetDir)"
            Actions = @("Would remove desktop.ini hijack", "Would remove $($Threat.SuspiciousLnks.Count) malicious .lnk traps", "Would unhide $($Threat.HiddenDirs.Count) user directories")
        }
    }

    # 1. Neutralize desktop.ini Icon Hijack
    $DesktopIni = Join-Path $Threat.TargetDir "desktop.ini"
    if (Test-Path $DesktopIni) {
        try {
            $File = Get-Item -LiteralPath $DesktopIni -Force
            $File.Attributes = "Normal"
            Remove-Item -Path $DesktopIni -Force -ErrorAction Stop
            $Actions += "Removed malicious desktop.ini icon hijack"
        } catch {
            $Actions += "Failed to remove desktop.ini: $($_.Exception.Message)"
        }
    }

    # 2. Quarantine & Remove Malicious .lnk Shortcuts
    if ($Threat.SuspiciousLnks) {
        foreach ($Lnk in $Threat.SuspiciousLnks) {
            try {
                Protect-FileToQuarantine -FilePath $Lnk.FullName -Reason "Shortcut Worm .lnk Trap" | Out-Null
                $Actions += "Quarantined shortcut trap: $($Lnk.Name)"
            } catch {}
        }
    }

    # 3. Perform Attribute Surgery on Hidden User Directories
    if ($Threat.HiddenDirs) {
        foreach ($Dir in $Threat.HiddenDirs) {
            try {
                $Dir.Attributes = "Directory"
                $Actions += "Unhid user directory: $($Dir.Name)"
            } catch {}
        }
    }

    return @{
        Success = $true
        Family  = "Shortcut Worm"
        Actions = $Actions
    }
}

Export-ModuleMember -Function Get-ShortcutWormSignature, Test-ShortcutWormThreat, Invoke-ShortcutWormRemediation
