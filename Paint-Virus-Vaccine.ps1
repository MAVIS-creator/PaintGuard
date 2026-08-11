# ==============================================================================
# Script: Paint-Virus-Vaccine.ps1
# Purpose: Legacy Vaccine Wrapper (Calls PaintGuard.Vaccine.psm1 Engine)
# ==============================================================================

$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "[ERROR] This script requires Administrator privileges." -ForegroundColor Red
    exit 1
}

$ModulesDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
Import-Module (Join-Path $ModulesDir "PaintGuard.Vaccine.psm1") -Force

Write-Host "Administering PaintGuard System Vaccine..." -ForegroundColor Cyan

$Results = Set-PaintGuardVaccine -HardenAutoRunPolicy -VaccinateConnectedUSB
foreach ($Res in $Results) {
    if ($Res.Status -eq "VACCINATED" -or $Res.Status -eq "HARDENED") {
        Write-Host "[$($Res.Status)] $($Res.Path) - $($Res.Message)" -ForegroundColor Green
    } else {
        Write-Host "[$($Res.Status)] $($Res.Path) - $($Res.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Vaccination complete. The malware can no longer install itself on this PC." -ForegroundColor Cyan