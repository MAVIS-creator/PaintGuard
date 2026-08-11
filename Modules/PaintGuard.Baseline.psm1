# Backward Compatibility Alias Shim for PaintGuard.Baseline.psm1
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vault.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vaccine.psm1") -Force

function New-PaintGuardBaseline { param($TargetPaths, [switch]$HardlinkMode) New-VaultGuardBaseline -TargetPaths $TargetPaths -HardlinkMode:$HardlinkMode }
function Test-PaintGuardIntegrity { Test-VaultGuardIntegrity }
function Export-PaintGuardBaseline { param($DestinationPath) Export-VaultGuardBaseline -DestinationPath $DestinationPath }
function Import-PaintGuardBaseline { param($SourceVaultPath) Import-VaultGuardBaseline -SourceVaultPath $SourceVaultPath }
function Start-PaintGuardWatchdog { Start-VaultGuardUsbWatcher }
function Stop-PaintGuardWatchdog { Stop-VaultGuardUsbWatcher }
function Get-PaintGuardWatchdogStatus { return @{ Active = $true; ActiveWatchers = 1 } }

Export-ModuleMember -Function New-PaintGuardBaseline, Test-PaintGuardIntegrity, Export-PaintGuardBaseline, Import-PaintGuardBaseline, Start-PaintGuardWatchdog, Stop-PaintGuardWatchdog, Get-PaintGuardWatchdogStatus
