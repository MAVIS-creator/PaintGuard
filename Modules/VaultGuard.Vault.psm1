# ==============================================================================
# Module: VaultGuard.Vault.psm1
# Purpose: Dual-Compartment Clean Vault, Threat Quarantine, Self-Protection ACLs
# ==============================================================================

$script:VaultRoot = "C:\ProgramData\VaultGuard"
try {
    if (-not (Test-Path $script:VaultRoot)) {
        New-Item -ItemType Directory -Path $script:VaultRoot -Force -ErrorAction Stop | Out-Null
    }
} catch {
    $script:VaultRoot = Join-Path $env:APPDATA "VaultGuard"
    if (-not (Test-Path $script:VaultRoot)) {
        New-Item -ItemType Directory -Path $script:VaultRoot -Force | Out-Null
    }
}

$script:BaselinePath = Join-Path $script:VaultRoot "Baseline"
$script:QuarantinePath = Join-Path $script:VaultRoot "Quarantine"
$script:GoldenPath = Join-Path $script:VaultRoot "GoldenVault"

function Initialize-VaultGuardProtection {
    [CmdletBinding()]
    param()

    $Dirs = @($script:VaultRoot, $script:BaselinePath, $script:QuarantinePath, $script:GoldenPath)
    foreach ($Dir in $Dirs) {
        if (-not (Test-Path $Dir)) {
            try { New-Item -ItemType Directory -Path $Dir -Force -ErrorAction Stop | Out-Null } catch {}
        }
        
        # Harden ACLs: Inherit None, SYSTEM & Administrators Full Control, Everyone Deny
        if (Test-Path $Dir) {
            try {
                $Acl = Get-Acl -Path $Dir
                $Acl.SetAccessRuleProtection($true, $false)
                
                $SystemRule = New-Object System.Security.AccessControl.FileSystemAccessRule("NT AUTHORITY\SYSTEM", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $AdminRule = New-Object System.Security.AccessControl.FileSystemAccessRule("BUILTIN\Administrators", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $EveryoneDeny = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Deny")
                
                $Acl.ResetAccessRule($SystemRule)
                $Acl.AddAccessRule($AdminRule)
                $Acl.AddAccessRule($EveryoneDeny)
                Set-Acl -Path $Dir -AclObject $Acl -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}

Initialize-VaultGuardProtection

function Get-VaultPaths {
    return @{
        Root       = $script:VaultRoot
        Baseline   = $script:BaselinePath
        Quarantine = $script:QuarantinePath
        Golden     = $script:GoldenPath
    }
}

# ------------------------------------------------------------------------------
# 1. Zero-Data-Loss Quarantine Vault Compartment
# ------------------------------------------------------------------------------

function Protect-FileToQuarantine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$FilePath,
        [string]$Reason = "Threat Remediation",
        [switch]$DryRun
    )
    
    if (-not (Test-Path -LiteralPath $FilePath)) {
        return @{ Success = $false; Message = "File does not exist: $FilePath" }
    }
    
    $Guid = [Guid]::NewGuid().ToString()
    $BinPath = Join-Path $script:QuarantinePath "$Guid.bin"
    $JsonPath = Join-Path $script:QuarantinePath "$Guid.json"
    
    $Item = Get-Item -LiteralPath $FilePath -Force
    $Hash = ""
    try { $Hash = (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash } catch {}
    
    $Metadata = [PSCustomObject]@{
        Id            = $Guid
        OriginalPath  = $Item.FullName
        OriginalName  = $Item.Name
        QuarantinedAt = (Get-Date).ToString("o")
        SHA256        = $Hash
        FileSize      = $Item.Length
        Attributes    = $Item.Attributes.ToString()
        Reason        = $Reason
    }
    
    if ($DryRun -or $WhatIfPreference) {
        return @{ Success = $true; QuarantineId = $Guid; OriginalPath = $FilePath; Message = "DryRun: Would quarantine file to $BinPath" }
    }
    
    if ($PSCmdlet.ShouldProcess($FilePath, "Move to Quarantine Vault ($Guid)")) {
        try {
            $Metadata | ConvertTo-Json -Depth 3 | Out-File -FilePath $JsonPath -Encoding utf8
            Move-Item -Path $FilePath -Destination $BinPath -Force -ErrorAction Stop
            return @{ Success = $true; QuarantineId = $Guid; OriginalPath = $FilePath }
        } catch {
            return @{ Success = $false; Message = "Quarantine operation failed: $($_.Exception.Message)" }
        }
    }
    return @{ Success = $true; QuarantineId = $Guid; Message = "WhatIf: Skipping file move." }
}

function Get-QuarantineVaultItems {
    [CmdletBinding()]
    param()
    
    $Items = @()
    $JsonFiles = Get-ChildItem -LiteralPath $script:QuarantinePath -Filter "*.json" -ErrorAction SilentlyContinue
    
    foreach ($JsonFile in $JsonFiles) {
        try {
            $Content = Get-Content -Path $JsonFile.FullName -Raw | ConvertFrom-Json
            $BinPath = Join-Path -Path $script:QuarantinePath -ChildPath "$($Content.Id).bin"
            $Content | Add-Member -NotePropertyName "PayloadExists" -NotePropertyValue (Test-Path $BinPath) -Force
            $Items += $Content
        } catch {}
    }
    return ,$Items
}

function Restore-QuarantinedItem {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$QuarantineId,
        [switch]$DryRun
    )
    
    $BinPath = Join-Path -Path $script:QuarantinePath -ChildPath "$QuarantineId.bin"
    $JsonPath = Join-Path -Path $script:QuarantinePath -ChildPath "$QuarantineId.json"
    
    if (-not (Test-Path -LiteralPath $JsonPath)) {
        return @{ Success = $false; Message = "Quarantine metadata record not found." }
    }
    
    $Meta = Get-Content -Path $JsonPath -Raw | ConvertFrom-Json
    $TargetFolder = Split-Path -Path $Meta.OriginalPath -Parent
    
    if ($DryRun -or $WhatIfPreference) {
        return @{ Success = $true; RestoredPath = $Meta.OriginalPath; Message = "DryRun: Would restore quarantined item $QuarantineId to $($Meta.OriginalPath)" }
    }
    
    if ($PSCmdlet.ShouldProcess($Meta.OriginalPath, "Restore Quarantined File from Vault")) {
        try {
            if (-not (Test-Path -LiteralPath $TargetFolder)) {
                New-Item -ItemType Directory -Path $TargetFolder -Force | Out-Null
            }
            Move-Item -Path $BinPath -Destination $Meta.OriginalPath -Force -ErrorAction Stop
            Remove-Item -Path $JsonPath -Force -ErrorAction SilentlyContinue
            return @{ Success = $true; RestoredPath = $Meta.OriginalPath }
        } catch {
            return @{ Success = $false; Message = "Failed to restore file: $($_.Exception.Message)" }
        }
    }
    return @{ Success = $true; Message = "WhatIf: Skipping restore." }
}

function Remove-QuarantinedItem {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$QuarantineId,
        [switch]$DryRun
    )
    
    $BinPath = Join-Path -Path $script:QuarantinePath -ChildPath "$QuarantineId.bin"
    $JsonPath = Join-Path -Path $script:QuarantinePath -ChildPath "$QuarantineId.json"
    
    if ($DryRun -or $WhatIfPreference) {
        return @{ Success = $true; Id = $QuarantineId; Message = "DryRun: Would purge quarantined item $QuarantineId" }
    }
    
    if ($PSCmdlet.ShouldProcess($QuarantineId, "Permanently Purge from Quarantine Vault")) {
        try {
            if (Test-Path $BinPath) { Remove-Item -Path $BinPath -Force }
            if (Test-Path $JsonPath) { Remove-Item -Path $JsonPath -Force }
            return @{ Success = $true; Id = $QuarantineId }
        } catch {
            return @{ Success = $false; Message = "Purge failed: $($_.Exception.Message)" }
        }
    }
    return @{ Success = $true; Message = "WhatIf: Skipping purge." }
}

# ------------------------------------------------------------------------------
# 2. Clean-File Baseline Vault Compartment
# ------------------------------------------------------------------------------

function New-VaultGuardBaseline {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [string[]]$TargetPaths = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "C:\Program Files"),
        [switch]$HardlinkMode,
        [switch]$DryRun
    )
    
    $BlobsDir = Join-Path $script:BaselinePath "blobs"
    if (-not (Test-Path $BlobsDir)) { New-Item -ItemType Directory -Path $BlobsDir -Force | Out-Null }
    
    $ManifestFile = Join-Path $script:BaselinePath "manifest.json"
    $SigFile = Join-Path $script:BaselinePath "vault.sig"
    
    $Entries = @()
    $Captured = 0
    $Skipped = 0
    
    foreach ($TargetPath in $TargetPaths) {
        if (-not (Test-Path $TargetPath)) { continue }
        $Exes = Get-ChildItem -LiteralPath $TargetPath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue
        
        foreach ($Exe in $Exes) {
            if ($Exe.Length -eq 844288) { $Skipped++; continue }
            if ($Exe.Name -match "^v") { $Skipped++; continue }
            
            try {
                $Hash = (Get-FileHash -Path $Exe.FullName -Algorithm SHA256).Hash
                $BlobPath = Join-Path $BlobsDir "$Hash.exe"
                
                if (-not ($DryRun -or $WhatIfPreference)) {
                    if (-not (Test-Path $BlobPath)) {
                        if ($HardlinkMode) {
                            New-Item -ItemType HardLink -Path $BlobPath -Value $Exe.FullName -ErrorAction Stop | Out-Null
                        } else {
                            Copy-Item -Path $Exe.FullName -Destination $BlobPath -Force -ErrorAction Stop
                        }
                    }
                }
                
                $Entries += [PSCustomObject]@{
                    OriginalPath = $Exe.FullName
                    FileName     = $Exe.Name
                    SHA256       = $Hash
                    FileSize     = $Exe.Length
                    LastWrite    = $Exe.LastWriteTime.ToString("o")
                    Attributes   = $Exe.Attributes.ToString()
                }
                $Captured++
            } catch {
                $Skipped++
            }
        }
    }
    
    if (-not ($DryRun -or $WhatIfPreference)) {
        $Entries | ConvertTo-Json -Depth 4 | Out-File -FilePath $ManifestFile -Encoding utf8
        $SigHash = (Get-FileHash -Path $ManifestFile -Algorithm SHA256).Hash
        $SigHash | Out-File -FilePath $SigFile -Encoding utf8
    }
    
    return @{
        Success       = $true
        TotalCaptured = $Captured
        TotalSkipped  = $Skipped
        VaultPath     = $script:BaselinePath
    }
}

function Test-VaultGuardIntegrity {
    [CmdletBinding()]
    param()
    
    $ManifestFile = Join-Path $script:BaselinePath "manifest.json"
    $SigFile = Join-Path $script:BaselinePath "vault.sig"
    
    if (-not (Test-Path $ManifestFile)) {
        return @{ Success = $false; Message = "Baseline manifest missing. Capture baseline first." }
    }
    
    if (Test-Path $SigFile) {
        $CurrentSig = (Get-FileHash -Path $ManifestFile -Algorithm SHA256).Hash
        $ExpectedSig = (Get-Content -Path $SigFile -Raw).Trim()
        if ($CurrentSig -ne $ExpectedSig) {
            return @{ Success = $false; Message = "WARNING: Baseline manifest signature mismatch. Possible tampering detected." }
        }
    }
    
    $Entries = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json
    $Triage = @()
    $Compromised = 0
    
    foreach ($Entry in $Entries) {
        $DiskPath = $Entry.OriginalPath
        $Status = "CLEAN"
        $CurrentHash = "MISSING"
        
        if (Test-Path $DiskPath) {
            try {
                $CurrentHash = (Get-FileHash -Path $DiskPath -Algorithm SHA256).Hash
                if ($CurrentHash -ne $Entry.SHA256) {
                    $Item = Get-Item -LiteralPath $DiskPath -Force
                    if ($Item.Length -eq 844288) {
                        $Status = "PAINT_INFECTED_PAYLOAD"
                    } else {
                        $Status = "MODIFIED"
                    }
                    $Compromised++
                }
            } catch {
                $Status = "UNREADABLE"
                $Compromised++
            }
        } else {
            $Status = "DELETED_OR_RENAMED"
            $Compromised++
        }
        
        $Triage += [PSCustomObject]@{
            OriginalPath = $DiskPath
            BaselineHash = $Entry.SHA256
            CurrentHash  = $CurrentHash
            Status       = $Status
        }
    }
    
    return @{
        Success          = $true
        TotalMonitored   = $Entries.Count
        CompromisedCount = $Compromised
        Triage           = $Triage
    }
}

function Restore-FileFromVault {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$OriginalPath,
        [switch]$DryRun
    )
    
    $ManifestFile = Join-Path $script:BaselinePath "manifest.json"
    if (-not (Test-Path $ManifestFile)) {
        return @{ Success = $false; Message = "No baseline manifest found." }
    }
    
    $Entries = Get-Content -Path $ManifestFile -Raw | ConvertFrom-Json
    $TargetEntry = $Entries | Where-Object { $_.OriginalPath -eq $OriginalPath }
    
    if (-not $TargetEntry) {
        return @{ Success = $false; Level = "Unrecoverable"; Message = "File not present in clean baseline manifest." }
    }
    
    # Rung 1: In-place Twin Repair
    $ParentDir = Split-Path -Path $OriginalPath -Parent
    $FileName = Split-Path -Path $OriginalPath -Leaf
    $HiddenTwinPath = Join-Path $ParentDir "v$FileName"
    
    if (Test-Path $HiddenTwinPath) {
        try {
            $TwinHash = (Get-FileHash -Path $HiddenTwinPath -Algorithm SHA256).Hash
            if ($TwinHash -eq $TargetEntry.SHA256) {
                if ($DryRun -or $WhatIfPreference) {
                    return @{ Success = $true; Level = "Level-1-Twin-Repair"; RestoredPath = $OriginalPath; Message = "DryRun: Would restore twin $HiddenTwinPath" }
                }
                
                $TwinFile = Get-Item -LiteralPath $HiddenTwinPath -Force
                $TwinFile.Attributes = "Normal"
                
                if (Test-Path $OriginalPath) {
                    Protect-FileToQuarantine -FilePath $OriginalPath -Reason "Replaced during twin restoration" | Out-Null
                }
                
                Rename-Item -Path $HiddenTwinPath -NewName $FileName -Force -ErrorAction Stop
                return @{ Success = $true; Level = "Level-1-Twin-Repair"; RestoredPath = $OriginalPath }
            }
        } catch {}
    }
    
    # Rung 2: Vault Blob Restore
    $BlobPath = Join-Path $script:BaselinePath "blobs\$($TargetEntry.SHA256).exe"
    if (Test-Path $BlobPath) {
        if ($DryRun -or $WhatIfPreference) {
            return @{ Success = $true; Level = "Level-2-Vault-Blob"; RestoredPath = $OriginalPath; Message = "DryRun: Would copy $BlobPath to $OriginalPath" }
        }
        try {
            if (Test-Path $OriginalPath) {
                Protect-FileToQuarantine -FilePath $OriginalPath -Reason "Replaced during Vault restoration" | Out-Null
            }
            Copy-Item -Path $BlobPath -Destination $OriginalPath -Force -ErrorAction Stop
            return @{ Success = $true; Level = "Level-2-Vault-Blob"; RestoredPath = $OriginalPath }
        } catch {
            return @{ Success = $false; Level = "Failed"; Message = "Blob restore failed: $($_.Exception.Message)" }
        }
    }
    
    return @{ Success = $false; Level = "Level-4-Unrecoverable"; Message = "Clean binary blob missing from Vault. Reinstall required." }
}

# ------------------------------------------------------------------------------
# 3. Off-Box USB Vault Backup & Import
# ------------------------------------------------------------------------------

function Export-VaultGuardBaseline {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$DestinationPath,
        [switch]$DryRun
    )
    
    if ($DryRun -or $WhatIfPreference) {
        return @{ Success = $true; ExportLocation = $DestinationPath; Message = "DryRun: Would export Vault to $DestinationPath" }
    }
    
    if (-not (Test-Path $DestinationPath)) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    
    try {
        Copy-Item -Path "$script:BaselinePath\*" -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
        return @{ Success = $true; ExportLocation = $DestinationPath }
    } catch {
        return @{ Success = $false; Message = "Vault export failed: $($_.Exception.Message)" }
    }
}

function Import-VaultGuardBaseline {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [Parameter(Mandatory=$true)][string]$SourceVaultPath,
        [switch]$DryRun
    )
    
    if (-not (Test-Path $SourceVaultPath)) {
        return @{ Success = $false; Message = "Source vault path not found: $SourceVaultPath" }
    }
    
    if ($DryRun -or $WhatIfPreference) {
        return @{ Success = $true; Message = "DryRun: Would import vault from $SourceVaultPath" }
    }
    
    try {
        Copy-Item -Path "$SourceVaultPath\*" -Destination $script:BaselinePath -Recurse -Force -ErrorAction Stop
        return @{ Success = $true; Message = "Baseline vault imported successfully." }
    } catch {
        return @{ Success = $false; Message = "Vault import failed: $($_.Exception.Message)" }
    }
}

Export-ModuleMember -Function Initialize-VaultGuardProtection, Get-VaultPaths, Protect-FileToQuarantine, Get-QuarantineVaultItems, Restore-QuarantinedItem, Remove-QuarantinedItem, New-VaultGuardBaseline, Test-VaultGuardIntegrity, Restore-FileFromVault, Export-VaultGuardBaseline, Import-VaultGuardBaseline
