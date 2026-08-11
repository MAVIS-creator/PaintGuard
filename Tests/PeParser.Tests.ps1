# ==============================================================================
# Unit Test: PeParser.Tests.ps1
# Purpose: Verify PE Header parsing, MZ/PE signatures, and Section Table resolution
# ==============================================================================

Import-Module (Join-Path $PSScriptRoot "..\Modules\VaultGuard.Expiro.psm1") -Force

Describe "PE Header Parser Unit Tests" {
    It "Parses current process executable" {
        $ExePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
        $PE = Get-PEHeaderInfo -FilePath $ExePath
        ([int]$PE.NumberOfSections -gt 0) | Should Be $true
    }

    It "Returns null gracefully for non-PE text files" {
        $TempFile = [System.IO.Path]::GetTempFileName()
        "Not a PE binary" | Out-File -FilePath $TempFile -Encoding utf8
        $PE = Get-PEHeaderInfo -FilePath $TempFile
        ($PE -eq $null) | Should Be $true
        Remove-Item -Path $TempFile -Force
    }
}
