# Backward Compatibility Alias Shim for PaintGuard.Report.psm1
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Audit.psm1") -Force

function Export-PaintGuardIncidentReport {
    param($ScanResults, $PersistenceAudit, $VaccineStatus, $QuarantineItems)
    return Export-VaultGuardIncidentReport -ScanResults $ScanResults -PersistenceAudit $PersistenceAudit -VaccineStatus $VaccineStatus -QuarantineItems $QuarantineItems
}

Export-ModuleMember -Function Export-PaintGuardIncidentReport
