# Backward Compatibility Alias Shim for PaintGuard.Vaccine.psm1
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vaccine.psm1") -Force

function Set-PaintGuardVaccine { param([switch]$HardenAutoRunPolicy, [switch]$VaccinateConnectedUSB) Set-VaultGuardVaccine -HardenAutoRunPolicy:$HardenAutoRunPolicy -VaccinateConnectedUSB:$VaccinateConnectedUSB }
function Remove-PaintGuardVaccine { Remove-VaultGuardVaccine }
function Get-PaintGuardVaccineStatus { Get-VaultGuardVaccineStatus }

Export-ModuleMember -Function Set-PaintGuardVaccine, Remove-PaintGuardVaccine, Get-PaintGuardVaccineStatus
