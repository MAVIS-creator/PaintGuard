# ==============================================================================
# Script: paintguard-cli.ps1
# Purpose: Standalone SysAdmin Interface for VaultGuard 360 Suite
# ==============================================================================

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [switch]$Scan,
    [string[]]$Drive = @("C:\"),
    [string]$ScanShare = "",
    [switch]$AutoRemediate,
    [switch]$DryRun,
    
    [switch]$PersistenceAudit,
    [switch]$RepairPersistence,
    
    [switch]$VaccinateStatus,
    [switch]$EnableVaccine,
    [switch]$DisableVaccine,
    
    [switch]$ListQuarantine,
    [string]$RestoreQuarantineId = "",
    [string]$PurgeQuarantineId = "",
    
    [switch]$CaptureBaseline,
    [switch]$VerifyIntegrity,
    [string]$ExportBaselinePath = "",
    [string]$ImportBaselinePath = "",
    [switch]$StartWatchdog,
    [switch]$StopWatchdog,
    
    [switch]$GenerateReport
)

# Import Engine Modules
$ModulesDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
Import-Module (Join-Path $ModulesDir "VaultGuard.Vault.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.PaintGeacata.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.ShortcutWorm.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Expiro.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Detection.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Persistence.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Vaccine.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Audit.psm1") -Force

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "             VAULTGUARD 360 ANTIVIRUS & VACCINE CLI v3.0                       " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

if ($CaptureBaseline) {
    Write-Host "[BASELINE] Capturing Clean System Integrity Baseline Vault..." -ForegroundColor Cyan
    $Res = New-VaultGuardBaseline -DryRun:$DryRun
    Write-Host "Captured Files: $($Res.TotalCaptured) | Skipped: $($Res.TotalSkipped)" -ForegroundColor Green
    Write-Host "Vault Location: $($Res.VaultPath)" -ForegroundColor Cyan
    exit
}

if ($VerifyIntegrity) {
    Write-Host "[BASELINE] Verifying System File Integrity against Vault Manifest..." -ForegroundColor Cyan
    $Res = Test-VaultGuardIntegrity
    if (-not $Res.Success) {
        Write-Host "[ERROR] $($Res.Message)" -ForegroundColor Red
        exit 1
    }
    $MColor = if ($Res.CompromisedCount -eq 0) { "Green" } else { "Red" }
    Write-Host "Total Monitored: $($Res.TotalMonitored) | Compromised: $($Res.CompromisedCount)" -ForegroundColor $MColor
    if ($Res.Triage) { $Res.Triage | Format-Table -AutoSize }
    exit
}

if ($ExportBaselinePath) {
    Write-Host "[BASELINE] Exporting Baseline Vault to $ExportBaselinePath ..." -ForegroundColor Cyan
    $Res = Export-VaultGuardBaseline -DestinationPath $ExportBaselinePath -DryRun:$DryRun
    Write-Host ($Res | Out-String)
    exit
}

if ($ImportBaselinePath) {
    Write-Host "[BASELINE] Importing Offline Vault from $ImportBaselinePath ..." -ForegroundColor Cyan
    $Res = Import-VaultGuardBaseline -SourceVaultPath $ImportBaselinePath -DryRun:$DryRun
    Write-Host ($Res | Out-String)
    exit
}

if ($StartWatchdog) {
    Write-Host "[WATCHDOG] Starting Real-Time USB VolumeChangeEvent Watcher..." -ForegroundColor Cyan
    $Res = Start-VaultGuardUsbWatcher
    Write-Host ($Res | Out-String)
    exit
}

if ($StopWatchdog) {
    Write-Host "[WATCHDOG] Stopping USB Watcher..." -ForegroundColor Yellow
    $Res = Stop-VaultGuardUsbWatcher
    Write-Host ($Res | Out-String)
    exit
}

if ($EnableVaccine) {
    Write-Host "[VACCINE] Administering Immutable Traps & AutoRun Hardening..." -ForegroundColor Cyan
    $Res = Set-VaultGuardVaccine -HardenAutoRunPolicy -VaccinateConnectedUSB -DryRun:$DryRun
    $Res | Format-Table -AutoSize
    exit
}

if ($DisableVaccine) {
    Write-Host "[VACCINE] Removing Immutable Traps..." -ForegroundColor Yellow
    $Res = Remove-VaultGuardVaccine -DryRun:$DryRun
    $Res | Format-Table -AutoSize
    exit
}

if ($VaccinateStatus) {
    Write-Host "[VACCINE] Verifying System Immunization Status..." -ForegroundColor Cyan
    $Status = Get-VaultGuardVaccineStatus
    $VColor = if ($Status.FullyVaccinated) { "Green" } else { "Red" }
    $AColor = if ($Status.AutoRunPolicyLocked) { "Green" } else { "Yellow" }
    Write-Host "Fully Vaccinated: $($Status.FullyVaccinated)" -ForegroundColor $VColor
    Write-Host "AutoRun Policy:   $($Status.AutoRunPolicyLocked)" -ForegroundColor $AColor
    $Status.PathStatuses | Format-Table -AutoSize
    exit
}

if ($ListQuarantine) {
    Write-Host "[QUARANTINE] Retrieving Items in Vault..." -ForegroundColor Cyan
    $Items = Get-QuarantineVaultItems
    if ($Items.Count -eq 0) {
        Write-Host "No items currently held in Quarantine Vault." -ForegroundColor Yellow
    } else {
        $Items | Select-Object Id, OriginalName, QuarantinedAt, FileSize, SHA256, OriginalPath | Format-Table -AutoSize
    }
    exit
}

if ($RestoreQuarantineId) {
    Write-Host "[QUARANTINE] Restoring Item $RestoreQuarantineId ..." -ForegroundColor Cyan
    $Res = Restore-QuarantinedItem -QuarantineId $RestoreQuarantineId -DryRun:$DryRun
    Write-Host ($Res | Out-String)
    exit
}

if ($PurgeQuarantineId) {
    Write-Host "[QUARANTINE] Permanently Purging Item $PurgeQuarantineId ..." -ForegroundColor Red
    $Res = Remove-QuarantinedItem -QuarantineId $PurgeQuarantineId -DryRun:$DryRun
    Write-Host ($Res | Out-String)
    exit
}

if ($PersistenceAudit) {
    Write-Host "[PERSISTENCE] Auditing Registry, Tasks, WMI & Startup Hooks..." -ForegroundColor Cyan
    $Audit = Get-VaultGuardPersistenceAudit
    $PColor = if ($Audit.ThreatsFound -eq 0) { "Green" } else { "Red" }
    Write-Host "Threats Identified: $($Audit.ThreatsFound)" -ForegroundColor $PColor
    if ($Audit.Findings) { $Audit.Findings | Format-Table -AutoSize }
    exit
}

if ($RepairPersistence) {
    Write-Host "[PERSISTENCE] Repairing Malicious Persistence Hooks..." -ForegroundColor Cyan
    $Res = Repair-VaultGuardPersistence -DryRun:$DryRun
    Write-Host "Remediated Count: $($Res.RemediatedCount)" -ForegroundColor Green
    $Res.Actions | ForEach-Object { Write-Host " [+] $_" -ForegroundColor Green }
    exit
}

if ($Scan -or $AutoRemediate) {
    Write-Host "[SCAN] Initiating Multi-Family Threat Scan..." -ForegroundColor Cyan
    if ($DryRun) { Write-Host " [DRY-RUN MODE ACTIVE: No files will be modified]" -ForegroundColor Yellow }
    
    $ScanRes = Invoke-VaultGuardScan -Paths $Drive -ScanShare $ScanShare -DryRun:$DryRun
    $SColor = if ($ScanRes.ThreatsFound -eq 0) { "Green" } else { "Red" }
    
    Write-Host ""
    Write-Host "================================================================================" -ForegroundColor Cyan
    Write-Host "Scan Summary: Scanned $($ScanRes.TotalScanned) files | Threats Found: $($ScanRes.ThreatsFound)" -ForegroundColor $SColor
    Write-Host "================================================================================" -ForegroundColor Cyan
    
    if ($ScanRes.Threats) {
        $ScanRes.Threats | Select-Object Family, Verdict, ConfidenceScore, CandidatePath, FilePath | Format-Table -AutoSize
        
        if ($AutoRemediate) {
            Write-Host "[REMEDIATE] Executing Multi-Family Remediation..." -ForegroundColor Cyan
            foreach ($Threat in $ScanRes.Threats) {
                if ($Threat.Family -eq "Paint / Geacata") {
                    Invoke-PaintGeacataRemediation -Threat $Threat -DryRun:$DryRun | Out-Null
                } elseif ($Threat.Family -eq "Shortcut Worm") {
                    Invoke-ShortcutWormRemediation -Threat $Threat -DryRun:$DryRun | Out-Null
                } elseif ($Threat.Family -eq "Expiro PE Infector") {
                    Invoke-ExpiroRemediation -Threat $Threat -DryRun:$DryRun | Out-Null
                }
            }
        }
    }
    
    if ($GenerateReport) {
        Write-Host "[REPORT] Generating Executive Incident Report..." -ForegroundColor Cyan
        $Persistence = Get-VaultGuardPersistenceAudit
        $Vaccine = Get-VaultGuardVaccineStatus
        $Quarantine = Get-QuarantineVaultItems
        $ReportPath = Export-VaultGuardIncidentReport -ScanResults $ScanRes -PersistenceAudit $Persistence -VaccineStatus $Vaccine -QuarantineItems $Quarantine
        Write-Host "Report Saved: $ReportPath" -ForegroundColor Green
    }
    exit
}

Write-Host "Usage Examples:" -ForegroundColor Yellow
Write-Host "  .\paintguard-cli.ps1 -Scan -Drive C:\ -DryRun                       (Preview Scan Findings)"
Write-Host "  .\paintguard-cli.ps1 -Scan -Drive C:\ -ScanShare \\server\share      (Scan Network Share)"
Write-Host "  .\paintguard-cli.ps1 -CaptureBaseline                               (Snapshot Clean System)"
Write-Host "  .\paintguard-cli.ps1 -VerifyIntegrity                               (Check Disk against Vault)"
Write-Host "  .\paintguard-cli.ps1 -ExportBaselinePath D:\                        (Backup Vault to USB)"
Write-Host "  .\paintguard-cli.ps1 -EnableVaccine                                 (Lock Immunity Traps)"
