# ==============================================================================
# Module: VaultGuard.Audit.psm1
# Purpose: JSON Event Logger & Executive Incident Report Builder (.html)
# ==============================================================================

function Export-VaultGuardIncidentReport {
    [CmdletBinding()]
    param(
        [object]$ScanResults,
        [object]$PersistenceAudit,
        [object]$VaccineStatus,
        [object]$QuarantineItems,
        [string]$OutputPath = ""
    )

    if (-not $OutputPath) {
        $Desktop = [Environment]::GetFolderPath("Desktop")
        $Timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
        $OutputPath = Join-Path $Desktop "VaultGuard_Executive_Report_$Timestamp.html"
    }

    $Scanned = if ($ScanResults) { $ScanResults.TotalScanned } else { 0 }
    $Threats = if ($ScanResults) { $ScanResults.ThreatsFound } else { 0 }
    $PersThreats = if ($PersistenceAudit) { $PersistenceAudit.ThreatsFound } else { 0 }
    $QuarCount = if ($QuarantineItems) { $QuarantineItems.Count } else { 0 }
    $Vaccinated = if ($VaccineStatus) { $VaccineStatus.FullyVaccinated } else { $false }

    $HtmlContent = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>VaultGuard 360 - Executive Incident Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #0f172a; color: #f8fafc; padding: 40px; margin: 0; }
        .card { background: #1e293b; border: 1px solid #334155; border-radius: 12px; padding: 24px; margin-bottom: 24px; }
        h1 { font-size: 24px; color: #2563eb; margin-bottom: 8px; }
        h2 { font-size: 18px; color: #ffffff; margin-bottom: 16px; border-bottom: 1px solid #334155; padding-bottom: 8px; }
        .grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 24px; }
        .stat-box { background: #0f172a; border: 1px solid #334155; border-radius: 8px; padding: 16px; text-align: center; }
        .stat-val { font-size: 26px; font-weight: bold; color: #60a5fa; }
        .stat-lbl { font-size: 12px; color: #94a3b8; text-transform: uppercase; margin-top: 4px; }
        table { width: 100%; border-collapse: collapse; margin-top: 12px; }
        th, td { padding: 10px 14px; text-align: left; border-bottom: 1px solid #334155; font-size: 13px; }
        th { background: #0f172a; color: #94a3b8; text-transform: uppercase; }
        .badge { padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: bold; }
        .badge-critical { background: rgba(220,38,38,0.2); color: #f87171; border: 1px solid #dc2626; }
        .badge-success { background: rgba(5,150,105,0.2); color: #34d399; border: 1px solid #059669; }
    </style>
</head>
<body>
    <div class="card">
        <h1>🛡️ VaultGuard 360 Executive Incident Report</h1>
        <p style="color: #94a3b8;">Generated on $(Get-Date) | Host: $env:COMPUTERNAME | User: $env:USERNAME</p>
    </div>

    <div class="grid">
        <div class="stat-box"><div class="stat-val">$Scanned</div><div class="stat-lbl">Files Scanned</div></div>
        <div class="stat-box"><div class="stat-val" style="color:#f87171;">$Threats</div><div class="stat-lbl">Active Threats</div></div>
        <div class="stat-box"><div class="stat-val">$QuarCount</div><div class="stat-lbl">Quarantined</div></div>
        <div class="stat-box"><div class="stat-val" style="color:#34d399;">$Vaccinated</div><div class="stat-lbl">Vaccinated</div></div>
    </div>

    <div class="card">
        <h2>Identified Threats & Remediation Audit</h2>
        <table>
            <thead>
                <tr><th>Family</th><th>Severity</th><th>Path / Target</th><th>Details</th></tr>
            </thead>
            <tbody>
"@

    if ($ScanResults -and $ScanResults.Threats) {
        foreach ($T in $ScanResults.Threats) {
            $RiskLevel = if ($T.RiskLevel) { $T.RiskLevel } else { 'CRITICAL' }
            $Target = if ($T.CandidatePath) { $T.CandidatePath } else { $T.FilePath }
            $Details = if ($T.Indicators) { $T.Indicators -join ', ' } else { 'Malware Signature Match' }
            $HtmlContent += "<tr><td>$($T.Family)</td><td><span class='badge badge-critical'>$RiskLevel</span></td><td>$Target</td><td>$Details</td></tr>`n"
        }
    } else {
        $HtmlContent += "<tr><td colspan='4' style='text-align:center; color:#34d399;'>No active malware threats identified.</td></tr>`n"
    }

    $HtmlContent += @"
            </tbody>
        </table>
    </div>
</body>
</html>
"@

    $HtmlContent | Out-File -FilePath $OutputPath -Encoding utf8
    return $OutputPath
}

Export-ModuleMember -Function Export-VaultGuardIncidentReport
