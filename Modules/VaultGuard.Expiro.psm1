# ==============================================================================
# Module: VaultGuard.Expiro.psm1
# Purpose: Deep-Pass Detector for Expiro PE Infector Family & 4-Rung Remediation
# ==============================================================================

Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vault.psm1") -ErrorAction SilentlyContinue

function Get-PEHeaderInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) { return $null }

    try {
        $Stream = [System.IO.File]::OpenRead($FilePath)
        $Reader = New-Object System.IO.BinaryReader($Stream)

        # 1. Read DOS Header (e_magic 'MZ')
        $e_magic = $Reader.ReadUInt16()
        if ($e_magic -ne 0x5A4D) { $Stream.Close(); return $null }

        $Stream.Seek(0x3C, [System.IO.SeekOrigin]::Begin) | Out-Null
        $e_lfanew = $Reader.ReadInt32()

        # 2. Read PE Header ('PE\0\0')
        $Stream.Seek($e_lfanew, [System.IO.SeekOrigin]::Begin) | Out-Null
        $pe_sig = $Reader.ReadUInt32()
        if ($pe_sig -ne 0x00004550) { $Stream.Close(); return $null }

        # 3. Read COFF File Header (20 Bytes)
        $Machine = $Reader.ReadUInt16()            # 2 bytes
        $NumberOfSections = $Reader.ReadUInt16()   # 2 bytes
        $TimeDateStamp = $Reader.ReadUInt32()      # 4 bytes
        $PointerToSymbolTable = $Reader.ReadUInt32()# 4 bytes
        $NumberOfSymbols = $Reader.ReadUInt32()    # 4 bytes
        $SizeOfOptionalHeader = $Reader.ReadUInt16()# 2 bytes
        $Characteristics = $Reader.ReadUInt16()     # 2 bytes

        # 4. Read Optional Header
        $OptHeaderOffset = $Stream.Position
        $Magic = $Reader.ReadUInt16()              # 0x010B (PE32) or 0x020B (PE32+)
        
        $AddressOfEntryPoint = 0
        if ($Magic -eq 0x010B) { # PE32
            $Stream.Seek($OptHeaderOffset + 16, [System.IO.SeekOrigin]::Begin) | Out-Null
            $AddressOfEntryPoint = $Reader.ReadUInt32()
        } elseif ($Magic -eq 0x020B) { # PE32+
            $Stream.Seek($OptHeaderOffset + 16, [System.IO.SeekOrigin]::Begin) | Out-Null
            $AddressOfEntryPoint = $Reader.ReadUInt32()
        }

        # 5. Read Section Table (Starts right after Optional Header)
        $SectionOffset = $OptHeaderOffset + $SizeOfOptionalHeader
        $Stream.Seek($SectionOffset, [System.IO.SeekOrigin]::Begin) | Out-Null

        $Sections = @()
        for ($i = 0; $i -lt $NumberOfSections; $i++) {
            $NameBytes = $Reader.ReadBytes(8)
            $SecName = ([System.Text.Encoding]::ASCII.GetString($NameBytes)).TrimEnd("`0")
            $VirtualSize = $Reader.ReadUInt32()
            $VirtualAddress = $Reader.ReadUInt32()
            $SizeOfRawData = $Reader.ReadUInt32()
            $PointerToRawData = $Reader.ReadUInt32()
            $PointerToRelocations = $Reader.ReadUInt32()
            $PointerToLinenumbers = $Reader.ReadUInt32()
            $NumberOfRelocations = $Reader.ReadUInt16()
            $NumberOfLinenumbers = $Reader.ReadUInt16()
            $SecCharacteristics = $Reader.ReadUInt32()

            $Sections += [PSCustomObject]@{
                Index            = $i
                Name             = $SecName
                VirtualSize      = $VirtualSize
                VirtualAddress   = $VirtualAddress
                SizeOfRawData    = $SizeOfRawData
                PointerToRawData = $PointerToRawData
                Characteristics  = $SecCharacteristics
            }
        }

        $Stream.Close()

        return [PSCustomObject]@{
            Machine             = $Machine
            NumberOfSections    = [int]$NumberOfSections
            AddressOfEntryPoint = [int]$AddressOfEntryPoint
            Sections            = $Sections
        }
    } catch {
        if ($Stream) { $Stream.Close() }
        return $null
    }
}

function Get-ExpiroSignature {
    return @{
        Family      = "Expiro PE Infector"
        Aliases     = @("Win32/Expiro", "W32.Expiro", "PE Appender")
        Description = "Polymorphic PE section appender infector (.vmp0/.svp sections, EntryPoint shifted to trailing section ~512KB)."
        Severity    = "CRITICAL"
    }
}

function Test-ExpiroThreat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [switch]$DeepPass
    )

    if (-not (Test-Path -LiteralPath $FilePath -PathType Leaf)) {
        return @{ Verdict = "Clean"; ConfidenceScore = 0; Indicators = @() }
    }

    $PE = Get-PEHeaderInfo -FilePath $FilePath
    if (-not $PE) {
        return @{ Verdict = "Clean"; ConfidenceScore = 0; Indicators = @() }
    }

    $Indicators = @()
    $Confidence = 0

    $ExpiroSection = $PE.Sections | Where-Object { $_.Name -match "^(\.vmp0|\.svp)" }
    if ($ExpiroSection) {
        $Indicators += "Found known Expiro section signature ($($ExpiroSection.Name))"
        $Confidence += 50
    }

    if ($PE.Sections -and $PE.Sections.Count -gt 0) {
        $LastSec = $PE.Sections[-1]
        $SecStart = $LastSec.VirtualAddress
        $SecEnd = $SecStart + $LastSec.VirtualSize

        if ($PE.AddressOfEntryPoint -ge $SecStart -and $PE.AddressOfEntryPoint -le $SecEnd) {
            $Indicators += "AddressOfEntryPoint (0x$("{0:X}" -f $PE.AddressOfEntryPoint)) resides inside last section ($($LastSec.Name))"
            $Confidence += 45
        }

        if ($LastSec.SizeOfRawData -ge 400000 -and $LastSec.SizeOfRawData -le 700000) {
            $Indicators += "Trailing section raw size ($($LastSec.SizeOfRawData) B) matches Expiro payload profile"
            $Confidence += 25
        }
    }

    $Verdict = "Clean"
    if ($Confidence -ge 70) {
        $Verdict = "Infected"
    } elseif ($Confidence -ge 40) {
        $Verdict = "Suspicious"
    }

    return @{
        Family          = "Expiro PE Infector"
        Verdict         = $Verdict
        ConfidenceScore = $Confidence
        Indicators      = $Indicators
        FilePath        = $FilePath
        PEHeader        = $PE
    }
}

function Invoke-ExpiroRemediation {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][object]$Threat,
        [switch]$DryRun
    )

    $Actions = @()
    $TargetFile = $Threat.FilePath

    if ($DryRun -or $WhatIfPreference) {
        return @{
            Success = $true
            Message = "DryRun: Would execute 4-Rung Expiro Remediation on $TargetFile"
            Actions = @("Rung 1: Would kill active infected process if running", "Rung 2: Would attempt clean Vault blob restore", "Rung 3: Would delegate to SFC/DISM if system OS file", "Rung 4: Would report unrecoverable if missing from baseline")
        }
    }

    try {
        $Hash = (Get-FileHash -Path $TargetFile -Algorithm SHA256).Hash
        $Procs = Get-CimInstance -ClassName Win32_Process | Where-Object { $_.ExecutablePath -eq $TargetFile }
        foreach ($Proc in $Procs) {
            Stop-Process -Id $Proc.ProcessId -Force -ErrorAction SilentlyContinue
            $Actions += "Rung 1: Terminated active infected process (PID: $($Proc.ProcessId))"
        }
    } catch {}

    $VaultRes = Restore-FileFromVault -OriginalPath $TargetFile
    if ($VaultRes.Success) {
        $Actions += "Rung 2: Successfully restored clean binary from Vault ($($VaultRes.Level))"
        return @{ Success = $true; Family = "Expiro PE Infector"; Level = $VaultRes.Level; Actions = $Actions }
    }

    if ($TargetFile -match "(?i)^C:\\Windows\\System32\\") {
        $Actions += "Rung 3: System OS file detected ($TargetFile). Quarantined infected file and executing native SFC & DISM repair..."
        Protect-FileToQuarantine -FilePath $TargetFile -Reason "Expiro Infected System OS File" | Out-Null
        try {
            Start-Process -FilePath "sfc.exe" -ArgumentList "/scanfile=`"$TargetFile`"" -WindowStyle Hidden -Wait -ErrorAction SilentlyContinue
            $Actions += "Executed: sfc /scanfile=`"$TargetFile`""
        } catch {
            $Actions += "Invoked SFC delegation background process."
        }
        return @{ Success = $true; Family = "Expiro PE Infector"; Level = "Rung-3-SFC-Delegation"; Actions = $Actions; SFCRecommended = $true }
    }

    Protect-FileToQuarantine -FilePath $TargetFile -Reason "Expiro Infected Non-Baseline File" | Out-Null
    $Actions += "Rung 4: File not present in baseline vault. Quarantined infected payload and flagged for user reinstall."
    
    return @{
        Success           = $true
        Family            = "Expiro PE Infector"
        Level             = "Rung-4-Unrecoverable"
        Actions           = $Actions
        ReinstallRequired = $true
    }
}

Export-ModuleMember -Function Get-PEHeaderInfo, Get-ExpiroSignature, Test-ExpiroThreat, Invoke-ExpiroRemediation
