# ==============================================================================
# Module: VaultGuard.PaintGeacata.psm1
# Purpose: Detector & Remediation for Paint / Geacata Malware Family
# ==============================================================================

Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vault.psm1") -ErrorAction SilentlyContinue

function Get-PaintGeacataSignature {
    return @{
        Family      = "Paint / Geacata"
        Aliases     = @("Paint Virus", "Geacata Virus", "Paint.exe: virus", "vFilename twin worm")
        Description = "File replacement worm that renames original executables to hidden v<filename>.exe and drops an 844,288 byte fake executable payload."
        Severity    = "CRITICAL"
    }
}

function Test-PaintGeacataThreat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [switch]$DeepPass
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return @{ Verdict = "Clean"; ConfidenceScore = 0; Indicators = @() }
    }

    $File = Get-Item -LiteralPath $FilePath -Force
    $Indicators = @()
    $Confidence = 0

    # Indicator 1: Exact File Size Match (844,288 Bytes / ~825KB)
    if ($File.Length -eq 844288) {
        $Indicators += "File size matches exact 844,288 byte Paint/Geacata payload signature"
        $Confidence += 50
    }

    # Indicator 2: Hidden v<name>.exe Twin-Pair Check
    $Directory = $File.DirectoryName
    $FileName = $File.Name
    $HiddenTwinPath = Join-Path $Directory "v$FileName"

    if (Test-Path $HiddenTwinPath) {
        $TwinFile = Get-Item -LiteralPath $HiddenTwinPath -Force
        if ($TwinFile.Attributes -match "Hidden" -or $TwinFile.Attributes -match "System") {
            $Indicators += "Found hidden twin-pair binary: $HiddenTwinPath"
            $Confidence += 45
        }
    }

    # Indicator 3: Valid PE Header Magic
    try {
        $Stream = [System.IO.File]::OpenRead($FilePath)
        $Header = New-Object byte[] 2
        $Stream.Read($Header, 0, 2) | Out-Null
        $Stream.Close()
        if ($Header[0] -eq 0x4D -and $Header[1] -eq 0x5A) { # 'MZ'
            $Confidence += 5
        }
    } catch {}

    # Determine Verdict
    $Verdict = "Clean"
    if ($Confidence -ge 70) {
        $Verdict = "Infected"
    } elseif ($Confidence -ge 40) {
        $Verdict = "Suspicious"
    }

    return @{
        Family          = "Paint / Geacata"
        Verdict         = $Verdict
        ConfidenceScore = $Confidence
        Indicators      = $Indicators
        CandidatePath   = $File.FullName
        HiddenPairPath  = if (Test-Path $HiddenTwinPath) { $HiddenTwinPath } else { $null }
    }
}

function Invoke-PaintGeacataRemediation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][object]$Threat,
        [switch]$DryRun
    )

    $Actions = @()
    $FakeExe = $Threat.CandidatePath
    $HiddenOriginal = $Threat.HiddenPairPath

    if ($DryRun -or $WhatIfPreference) {
        return @{
            Success = $true
            Message = "DryRun: Would remediate Paint/Geacata threat at $FakeExe"
            Actions = @("Would quarantine fake 825KB binary $FakeExe", "Would restore original hidden twin $HiddenOriginal")
        }
    }

    # 1. Quarantine Fake Payload
    if (Test-Path $FakeExe) {
        try {
            Protect-FileToQuarantine -FilePath $FakeExe -Reason "Paint/Geacata Malicious Payload" | Out-Null
            $Actions += "Quarantined fake 825KB executable: $FakeExe"
        } catch {
            $Actions += "Failed to quarantine fake exe: $($_.Exception.Message)"
        }
    }

    # 2. Restore Hidden Twin or Clean Vault Blob
    if ($HiddenOriginal -and (Test-Path $HiddenOriginal)) {
        try {
            $OriginalName = Split-Path -Path $FakeExe -Leaf
            $File = Get-Item -LiteralPath $HiddenOriginal -Force
            $File.Attributes = "Normal"
            Rename-Item -Path $HiddenOriginal -NewName $OriginalName -Force -ErrorAction Stop
            $Actions += "Restored original binary attributes and renamed to $OriginalName"
        } catch {
            $Actions += "Attribute restoration failed: $($_.Exception.Message)"
        }
    } else {
        # Fallback to Vault Blob Restore
        $VaultRes = Restore-FileFromVault -OriginalPath $FakeExe
        if ($VaultRes.Success) {
            $Actions += "Restored clean binary from Baseline Vault ($($VaultRes.Level))"
        } else {
            $Actions += "Original twin missing and not in baseline vault. Reinstall required."
        }
    }

    return @{
        Success = $true
        Family  = "Paint / Geacata"
        Actions = $Actions
    }
}

Export-ModuleMember -Function Get-PaintGeacataSignature, Test-PaintGeacataThreat, Invoke-PaintGeacataRemediation
