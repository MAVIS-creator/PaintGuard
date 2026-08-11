# Backward Compatibility Alias Shim for PaintGuard.Remediation.psm1
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Vault.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "VaultGuard.PaintGeacata.psm1") -Force

function Stop-MalwareProcessByHash {
    param([string[]]$KnownHashes)
    return @()
}

function Invoke-AttributeRestoration {
    param([string]$HiddenFilePath)
    $Threat = @{ CandidatePath = $HiddenFilePath -replace '(?i)^v', ''; HiddenPairPath = $HiddenFilePath }
    return Invoke-PaintGeacataRemediation -Threat $Threat
}

function Get-QuarantinePath {
    return (Get-VaultPaths).Quarantine
}

Export-ModuleMember -Function Protect-FileToQuarantine, Get-QuarantineVaultItems, Restore-QuarantinedItem, Remove-QuarantinedItem, Stop-MalwareProcessByHash, Invoke-AttributeRestoration, Get-QuarantinePath
