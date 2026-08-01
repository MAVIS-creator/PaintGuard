# ==============================================================================
# Script: RecoveryPlan.ps1
# Purpose: Legacy Recovery Plan & Hash Verification Generator
# ==============================================================================

$Desktop = [Environment]::GetFolderPath("Desktop")
$AuditCSV = Join-Path $Desktop "PaintVirus_Audit.csv"

if (!(Test-Path $AuditCSV)) {
    Write-Host "PaintVirus_Audit.csv not found on Desktop. Running fresh audit..." -ForegroundColor Yellow
    $AuditScript = Join-Path $PSScriptRoot "Audit-PaintVirus.ps1"
    & $AuditScript
}

$Audit = Import-Csv $AuditCSV
$RecoveryPlan = @()
$HashDB = @()

$total = $Audit.Count
$current = 0

foreach ($row in $Audit) {
    $current++
    Write-Progress -Activity "Verifying Recovery Candidates" -Status "$current of $total" -PercentComplete (($current / $total) * 100)

    $Fake = $row.FakeExe
    $Original = $row.HiddenOriginal
    $Status = "READY"
    $Reason = "Twin pair verified ready for restoration."

    $FakeExists = Test-Path $Fake
    $OriginalExists = Test-Path $Original

    if (!$FakeExists) {
        $Status = "MISSING_FAKE"
        $Reason = "Fake executable no longer exists."
    } elseif (!$OriginalExists) {
        $Status = "MISSING_ORIGINAL"
        $Reason = "Hidden original twin not found."
    } else {
        $FakeFile = Get-Item $Fake -Force
        $OriginalFile = Get-Item $Original -Force

        if ($FakeFile.Length -ne 844288) {
            $Status = "SIZE_CHANGED"
            $Reason = "Fake executable size is no longer 844,288 bytes."
        }

        try {
            $FakeHash = (Get-FileHash $Fake -Algorithm SHA256).Hash
            $OriginalHash = (Get-FileHash $Original -Algorithm SHA256).Hash

            $HashDB += [PSCustomObject]@{ File = $Fake; Type = "Fake"; SHA256 = $FakeHash }
            $HashDB += [PSCustomObject]@{ File = $Original; Type = "Original"; SHA256 = $OriginalHash }
        } catch {
            $Status = "HASH_FAILED"
            $Reason = $_.Exception.Message
            $FakeHash = ""
            $OriginalHash = ""
        }
    }

    $RecoveryPlan += [PSCustomObject]@{
        Folder         = $row.Folder
        FakeExe        = $Fake
        HiddenOriginal = $Original
        Status         = $Status
        Reason         = $Reason
        FakeHash       = $FakeHash
        OriginalHash   = $OriginalHash
    }
}

$RecoveryPlan | Export-Csv "$Desktop\RecoveryPlan.csv" -NoTypeInformation
$HashDB | Export-Csv "$Desktop\PaintVirus_Hashes.csv" -NoTypeInformation
$RecoveryPlan | Out-File "$Desktop\RecoveryVerification.log"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "RecoveryPlan.csv created on Desktop"
Write-Host "PaintVirus_Hashes.csv created on Desktop"
Write-Host "RecoveryVerification.log created on Desktop"