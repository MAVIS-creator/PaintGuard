# Backward Compatibility Alias Shim for PaintGuard.Persistence.psm1
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Persistence.psm1") -Force

function Get-PaintGuardPersistenceAudit { return Get-VaultGuardPersistenceAudit }
function Repair-PersistenceHooks { return Repair-VaultGuardPersistence }

Export-ModuleMember -Function Get-PaintGuardPersistenceAudit, Repair-PersistenceHooks
