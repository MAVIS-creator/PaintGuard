# ==============================================================================
# Test: FalsePositiveBaseline.Tests.ps1
# Purpose: Verify clean reference directories return ZERO false positive findings
# ==============================================================================

Import-Module (Join-Path $PSScriptRoot "..\Modules\VaultGuard.Vault.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\Modules\VaultGuard.ShortcutWorm.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\Modules\VaultGuard.Expiro.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\Modules\VaultGuard.PaintGeacata.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\Modules\VaultGuard.Detection.psm1") -Force

Describe "False Positive Baseline Test Suite" {
    It "Returns zero Infected findings for Windows System32 directory" {
        $SysDir = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0"
        $Res = Invoke-VaultGuardScan -Paths @($SysDir) -DryRun
        $Res.ThreatsFound | Should Be 0
    }
}
