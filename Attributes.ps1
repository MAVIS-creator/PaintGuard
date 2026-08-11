# ==============================================================================
# Script: Attributes.ps1
# Purpose: Legacy Attribute Restoration Wrapper (Uses PaintGuard.Remediation.psm1)
# ==============================================================================

$ModulesDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
Import-Module (Join-Path $ModulesDir "PaintGuard.Remediation.psm1") -Force

Write-Host "Starting File Attribute Restoration & Renaming..." -ForegroundColor Cyan

$Desktop = [Environment]::GetFolderPath("Desktop")
$CsvPath = Join-Path $Desktop "PaintVirus_Audit.csv"
if (-not (Test-Path $CsvPath)) {
    $CsvPath = Join-Path $Desktop "New_vHidden_Scan.csv"
}

if (-not (Test-Path $CsvPath)) {
    Write-Host "[ERROR] Scan CSV report not found on Desktop." -ForegroundColor Red
    exit 1
}

$ScanData = Import-Csv -Path $CsvPath
$RestoredCount = 0

foreach ($Item in $ScanData) {
    $HiddenFile = if ($Item.HiddenOriginal) { $Item.HiddenOriginal } else { $Item.FullName }
    if (-not $HiddenFile -or -not (Test-Path $HiddenFile)) { continue }

    $Res = Invoke-AttributeRestoration -HiddenFilePath $HiddenFile
    if ($Res.Success) {
        Write-Host "[RESTORED] $($Res.RestoredPath)" -ForegroundColor Green
        $RestoredCount++
    } else {
        Write-Host "[SKIPPED] $HiddenFile : $($Res.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Restoration Complete. Restored $RestoredCount user binaries to original state." -ForegroundColor Cyan