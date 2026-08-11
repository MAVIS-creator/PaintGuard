# Backward Compatibility Alias Shim for PaintGuard.Detection.psm1
Import-Module (Join-Path $PSScriptRoot "VaultGuard.Detection.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "VaultGuard.PaintGeacata.psm1") -Force

function Invoke-PaintGuardScan {
    param([string[]]$Paths = @("C:\"), [scriptblock]$OnProgress)
    return Invoke-VaultGuardScan -Paths $Paths -OnProgress $OnProgress
}

function Get-PaintGuardHashList {
    return @("844288", "163278912739182739182739812739127391827391283719283719283719283")
}

Export-ModuleMember -Function Invoke-PaintGuardScan, Get-PaintGuardHashList
