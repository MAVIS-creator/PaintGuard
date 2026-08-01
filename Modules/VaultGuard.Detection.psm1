# ==============================================================================
# Module: VaultGuard.Detection.psm1
# Purpose: Multi-Family Threat Dispatcher & Three-Tier Verdict Engine
# ==============================================================================

Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vault.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "VaultGuard.PaintGeacata.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "VaultGuard.ShortcutWorm.psm1") -ErrorAction SilentlyContinue
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Expiro.psm1") -ErrorAction SilentlyContinue

function Invoke-VaultGuardScan {
    [CmdletBinding()]
    param(
        [string[]]$Paths = @("C:\"),
        [string]$ScanShare = "",
        [switch]$DryRun,
        [scriptblock]$OnProgress
    )

    if ($ScanShare) { $Paths += $ScanShare }

    $TotalScanned = 0
    $ThreatsFound = 0
    $Threats = @()
    $ReviewQueue = @()

    foreach ($RootPath in $Paths) {
        if (-not (Test-Path $RootPath)) { continue }

        if ($OnProgress) {
            & $OnProgress @{ Scanned = 0; ThreatsFound = 0; CurrentFile = "Searching target directory: $RootPath" }
        }

        # Fast-Pass 1: Shortcut Worm Drive & Directory Heuristics
        $SwRes = Test-ShortcutWormThreat -Path $RootPath
        if ($SwRes.Verdict -eq "Infected") {
            $Threats += $SwRes
            $ThreatsFound++
        } elseif ($SwRes.Verdict -eq "Suspicious") {
            $ReviewQueue += $SwRes
        }

        # Fast-Pass 2 & Deep-Pass: Pipeline Streaming Target Executables
        try {
            Get-ChildItem -LiteralPath $RootPath -Filter "*.exe" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                $Exe = $_
                $TotalScanned++
                
                if ($OnProgress) {
                    & $OnProgress @{ Scanned = $TotalScanned; ThreatsFound = $ThreatsFound; CurrentFile = $Exe.FullName }
                }

                # 1. Test Paint / Geacata Twin-Pair Signature
                $PaintRes = Test-PaintGeacataThreat -FilePath $Exe.FullName
                if ($PaintRes.Verdict -eq "Infected") {
                    $Threats += $PaintRes
                    $ThreatsFound++
                    return
                } elseif ($PaintRes.Verdict -eq "Suspicious") {
                    $ReviewQueue += $PaintRes
                }

                # 2. Test Expiro Structural PE Signature
                $ExpiroRes = Test-ExpiroThreat -FilePath $Exe.FullName -DeepPass
                if ($ExpiroRes.Verdict -eq "Infected") {
                    $Threats += $ExpiroRes
                    $ThreatsFound++
                    return
                } elseif ($ExpiroRes.Verdict -eq "Suspicious") {
                    $ReviewQueue += $ExpiroRes
                }
            }
        } catch {}
    }

    return @{
        TotalScanned = $TotalScanned
        ThreatsFound = $ThreatsFound
        Threats      = $Threats
        ReviewQueue  = $ReviewQueue
    }
}

Export-ModuleMember -Function Invoke-VaultGuardScan
