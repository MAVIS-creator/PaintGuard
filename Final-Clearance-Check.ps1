# ==============================================================================
# Script: Final-Clearance-Check.ps1
# Purpose: Legacy Clearance Check Wrapper (Uses PaintGuard.Persistence & Vaccine)
# ==============================================================================

$ModulesDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
Import-Module (Join-Path $ModulesDir "PaintGuard.Persistence.psm1") -Force
Import-Module (Join-Path $ModulesDir "PaintGuard.Vaccine.psm1") -Force

Write-Host "Running PaintGuard Final Clearance Verification..." -ForegroundColor Cyan
Write-Host "--------------------------------------------------" -ForegroundColor Cyan

$Persistence = Get-PaintGuardPersistenceAudit
$Vaccine = Get-PaintGuardVaccineStatus

$ThreatsFound = $Persistence.ThreatsFound

Write-Host "Persistence Hooks Identified: $($Persistence.ThreatsFound)"
if ($Persistence.Findings) {
    foreach ($f in $Persistence.Findings) {
        Write-Host " [WARNING] $($f.Category): $($f.Item) -> $($f.Target)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Vaccine Immunization Status: $(if($Vaccine.FullyVaccinated){'PROTECTED'}else{'INCOMPLETE'})"
foreach ($v in $Vaccine.PathStatuses) {
    $Color = if ($v.IsVaccinated) { "Green" } else { "Yellow" }
    Write-Host " [$($v.IsVaccinated)] $($v.Path) - $($v.Details)" -ForegroundColor $Color
}

Write-Host "--------------------------------------------------" -ForegroundColor Cyan
if ($ThreatsFound -eq 0) {
    Write-Host "[CLEARED] No active paint.exe malware triggers or persistence hooks were found." -ForegroundColor Green
    Write-Host "[CLEARED] System is 100% clean and safe." -ForegroundColor Green
} else {
    Write-Host "[DANGER] Found $ThreatsFound potential threat hook(s). Run Remediation before rebooting!" -ForegroundColor Red
}