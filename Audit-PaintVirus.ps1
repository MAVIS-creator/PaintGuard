# ==============================================================================
# Script: Audit-PaintVirus.ps1
# Purpose: Legacy Threat Audit Wrapper (Uses PaintGuard.Detection.psm1)
# ==============================================================================

$ModulesDir = Join-Path -Path $PSScriptRoot -ChildPath "Modules"
Import-Module (Join-Path $ModulesDir "PaintGuard.Detection.psm1") -Force

Write-Host "Initiating Paint Virus Audit Scan..." -ForegroundColor Cyan

$ScanRes = Invoke-PaintGuardScan -Paths @("C:\")
$Desktop = [Environment]::GetFolderPath("Desktop")
$OutCsv = Join-Path $Desktop "PaintVirus_Audit.csv"

$FlatResults = @()
if ($ScanRes.Threats) {
    foreach ($t in $ScanRes.Threats) {
        $FlatResults += [PSCustomObject]@{
            Folder         = Split-Path -Path $t.CandidatePath -Parent
            FakeExe        = $t.CandidatePath
            FakeSize       = $t.CandidateSize
            FakeHash       = $t.CandidateHash
            HiddenOriginal = $t.HiddenPairPath
            OriginalSize   = $t.HiddenPairSize
            OriginalHidden = $t.HiddenAttributes
            SafeCandidate  = $t.SafeToRestore
            ConfidenceScore= $t.ConfidenceScore
            RiskLevel      = $t.RiskLevel
        }
    }
}

$FlatResults | Export-Csv -Path $OutCsv -NoTypeInformation
Write-Host ""
Write-Host "Audit Complete. Scanned $($ScanRes.TotalScanned) files. Threats found: $($ScanRes.ThreatsFound)" -ForegroundColor (if($ScanRes.ThreatsFound -eq 0){"Green"}else{"Yellow"})
Write-Host "Audit report saved to Desktop: $OutCsv" -ForegroundColor Cyan