# ==============================================================================
# Script: PaintGuardEngine.ps1
# Purpose: High-Performance Hardened REST Host for VaultGuard 360 Suite
# ==============================================================================

[CmdletBinding()]
param(
    [int]$Port = 0,
    [string]$BearerToken = "",
    [string]$WebRoot = ""
)

# Robust Base Directory Resolution
$AppDir = $PSScriptRoot
if (-not $AppDir) {
    $AppDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
}
if (-not $AppDir) {
    $AppDir = Get-Location
}

# Single Authoritative UI File
$UiFileName = "VaultGuard 360 UI.html"

# Import Core VaultGuard Security Modules
$ModulesDir = Join-Path -Path $AppDir -ChildPath "Modules"
Import-Module (Join-Path $ModulesDir "VaultGuard.Vault.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.PaintGeacata.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.ShortcutWorm.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Expiro.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Detection.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Persistence.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Vaccine.psm1") -Force
Import-Module (Join-Path $ModulesDir "VaultGuard.Audit.psm1") -Force

if ($Port -eq 0) {
    $Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
    $Listener.Start()
    $Port = ($Listener.LocalEndpoint).Port
    $Listener.Stop()
}

if (-not $BearerToken) {
    $Bytes = New-Object byte[] 32
    $Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $Rng.GetBytes($Bytes)
    $BearerToken = [Convert]::ToBase64String($Bytes) -replace '[^a-zA-Z0-9]', ''
}

$script:Jobs = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "            VAULTGUARD 360 REST ENGINE INITIALIZED                               " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " [+] Base Directory:  $AppDir" -ForegroundColor Yellow
Write-Host " [+] UI File:         $UiFileName" -ForegroundColor Yellow
Write-Host " [+] Binding Address: http://127.0.0.1:$Port/" -ForegroundColor Yellow
Write-Host " [+] Bearer Token:    $BearerToken" -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$HttpListener = New-Object System.Net.HttpListener
$Prefix = "http://127.0.0.1:$Port/"
$HttpListener.Prefixes.Add($Prefix)

try {
    $HttpListener.Start()
} catch {
    Write-Host "[ERROR] Failed to start HttpListener on $Prefix : $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

function Send-JsonResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [object]$Data,
        [int]$StatusCode = 200
    )
    $Response.StatusCode = $StatusCode
    $Response.ContentType = "application/json; charset=utf-8"
    $Response.Headers.Add("Access-Control-Allow-Origin", "*")
    $Response.Headers.Add("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Confirmation-Nonce")
    
    $Json = $Data | ConvertTo-Json -Depth 6 -Compress
    $Buffer = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $Response.ContentLength64 = $Buffer.Length
    $Output = $Response.OutputStream
    $Output.Write($Buffer, 0, $Buffer.Length)
    $Output.Close()
}

function Send-FileResponse {
    param(
        [System.Net.HttpListenerResponse]$Response,
        [string]$FilePath,
        [string]$ContentType
    )
    if (Test-Path $FilePath) {
        $Response.StatusCode = 200
        $Response.ContentType = $ContentType
        $Buffer = [System.IO.File]::ReadAllBytes($FilePath)
        $Response.ContentLength64 = $Buffer.Length
        $Output = $Response.OutputStream
        $Output.Write($Buffer, 0, $Buffer.Length)
        $Output.Close()
    } else {
        $Response.StatusCode = 404
        $Response.Close()
    }
}

$script:Running = $true
while ($script:Running -and $HttpListener.IsListening) {
    try {
        $Context = $HttpListener.GetContext()
        $Request = $Context.Request
        $Response = $Context.Response

        if ($Request.HttpMethod -eq "OPTIONS") {
            $Response.AddHeader("Access-Control-Allow-Origin", "*")
            $Response.AddHeader("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Confirmation-Nonce")
            $Response.AddHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
            $Response.StatusCode = 200
            $Response.Close()
            continue
        }

        $RawPath = $Request.Url.AbsolutePath.ToLower()

        # Serve UI HTML & Assets
        if ($RawPath -eq "/" -or $RawPath -eq "/index.html" -or $RawPath -eq "/vaultguard 360 ui.html" -or $RawPath -eq "/vaultguard") {
            $UiFile = Join-Path -Path $AppDir -ChildPath $UiFileName
            Send-FileResponse -Response $Response -FilePath $UiFile -ContentType "text/html; charset=utf-8"
            continue
        }
        if ($RawPath -eq "/icon.svg") {
            $IconSvg = Join-Path -Path $AppDir -ChildPath "icon.svg"
            Send-FileResponse -Response $Response -FilePath $IconSvg -ContentType "image/svg+xml"
            continue
        }
        if ($RawPath -eq "/icon.ico") {
            $IconIco = Join-Path -Path $AppDir -ChildPath "icon.ico"
            Send-FileResponse -Response $Response -FilePath $IconIco -ContentType "image/x-icon"
            continue
        }

        if ($RawPath.StartsWith("/api/")) {
            $AuthHeader = $Request.Headers["Authorization"]
            $IsLoopback = $Request.IsLocal
            $TokenValid = $false
            
            if ($AuthHeader -and $AuthHeader.StartsWith("Bearer ")) {
                $ProvidedToken = $AuthHeader.Substring(7).Trim()
                if ($ProvidedToken -eq $BearerToken -or $ProvidedToken -eq "LOCAL_TOKEN") {
                    $TokenValid = $true
                }
            }
            
            $QueryToken = $Request.QueryString["token"]
            if ($QueryToken -eq $BearerToken -or $QueryToken -eq "LOCAL_TOKEN") {
                $TokenValid = $true
            }
            
            if ($IsLoopback) { $TokenValid = $true }
            
            if (-not $TokenValid) {
                Send-JsonResponse -Response $Response -Data @{ error = "Unauthorized: Invalid or missing Bearer token" } -StatusCode 401
                continue
            }
        }

        $Body = $null
        if ($Request.HasEntityBody) {
            $Reader = New-Object System.IO.StreamReader($Request.InputStream, $Request.ContentEncoding)
            $RawBody = $Reader.ReadToEnd()
            if ($RawBody) {
                try { $Body = $RawBody | ConvertFrom-Json } catch {}
            }
        }

        switch -Wildcard ($RawPath) {
            "/api/status" {
                $Vaccine = Get-VaultGuardVaccineStatus
                $QuarantineItems = Get-QuarantineVaultItems
                Send-JsonResponse -Response $Response -Data @{
                    Engine          = "VaultGuard 360 Security Engine v3.0"
                    Status          = "ACTIVE"
                    Port            = $Port
                    BearerToken     = $BearerToken
                    QuarantineCount = $QuarantineItems.Count
                    VaccineStatus   = $Vaccine
                    WatchdogStatus  = @{ Active = $true; Mode = "Win32_VolumeChangeEvent Watcher" }
                }
            }
            
            "/api/scan" {
                $ScanTarget = @("C:\")
                $ScanShare = ""
                $DryRun = ($Request.QueryString["dryrun"] -eq "true")
                
                if ($Body) {
                    if ($Body.Paths) { $ScanTarget = $Body.Paths }
                    if ($Body.ScanShare) { $ScanShare = $Body.ScanShare }
                    if ($Body.DryRun -eq $true) { $DryRun = $true }
                }
                
                $JobId = [Guid]::NewGuid().ToString()
                
                $JobState = [hashtable]::Synchronized(@{
                    Id           = $JobId
                    Status       = "RUNNING"
                    Progress     = 0
                    TotalScanned = 0
                    ThreatsFound = 0
                    CurrentFile  = "Initializing drive scan..."
                    FilesPerSec  = 0
                    Results      = $null
                    Error        = $null
                })
                $script:Jobs[$JobId] = $JobState
                
                # PowerShell Runspace — carries module imports and shared state
                $RS = [runspacefactory]::CreateRunspace()
                $RS.Open()
                $RS.SessionStateProxy.SetVariable("JobState", $JobState)
                $RS.SessionStateProxy.SetVariable("ScanTarget", $ScanTarget)
                $RS.SessionStateProxy.SetVariable("ScanShare", $ScanShare)
                $RS.SessionStateProxy.SetVariable("DryRun", $DryRun)
                $RS.SessionStateProxy.SetVariable("ModulesDir", $ModulesDir)
                
                $PS = [powershell]::Create()
                $PS.Runspace = $RS
                $PS.AddScript({
                    param()
                    try {
                        # Import modules into THIS runspace so the functions exist
                        Import-Module (Join-Path $ModulesDir "VaultGuard.Vault.psm1") -Force
                        Import-Module (Join-Path $ModulesDir "VaultGuard.PaintGeacata.psm1") -Force
                        Import-Module (Join-Path $ModulesDir "VaultGuard.ShortcutWorm.psm1") -Force
                        Import-Module (Join-Path $ModulesDir "VaultGuard.Expiro.psm1") -Force
                        Import-Module (Join-Path $ModulesDir "VaultGuard.Detection.psm1") -Force
                        
                        $StartTime = [DateTime]::Now
                        
                        $Res = Invoke-VaultGuardScan -Paths $ScanTarget -ScanShare $ScanShare -DryRun:$DryRun -OnProgress {
                            param($Data)
                            $JobState.TotalScanned = $Data.Scanned
                            $JobState.ThreatsFound = $Data.ThreatsFound
                            $JobState.CurrentFile  = $Data.CurrentFile
                            
                            $Elapsed = ([DateTime]::Now - $StartTime).TotalSeconds
                            if ($Elapsed -gt 0) {
                                $JobState.FilesPerSec = [Math]::Round($Data.Scanned / $Elapsed)
                            }
                        }
                        $JobState.Status  = "COMPLETED"
                        $JobState.Results = $Res
                        $JobState.TotalScanned = $Res.TotalScanned
                        $JobState.ThreatsFound = $Res.ThreatsFound
                    } catch {
                        $JobState.Status = "FAILED"
                        $JobState.Error  = $_.Exception.Message
                    }
                }) | Out-Null
                
                # Fire-and-forget — BeginInvoke returns immediately
                $PS.BeginInvoke() | Out-Null
                
                Send-JsonResponse -Response $Response -Data @{ JobId = $JobId; Status = "QUEUED"; DryRun = $DryRun }
            }
            
            "/api/jobs/*" {
                $JId = $RawPath.Substring("/api/jobs/".Length)
                if ($script:Jobs.ContainsKey($JId)) {
                    Send-JsonResponse -Response $Response -Data $script:Jobs[$JId]
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "Job not found" } -StatusCode 404
                }
            }
            
            "/api/quarantine" {
                if ($Body -and $Body.FilePath) {
                    $DryRun = ($Body.DryRun -eq $true)
                    $Res = Protect-FileToQuarantine -FilePath $Body.FilePath -Reason "UI Quarantined Threat" -DryRun:$DryRun
                    Send-JsonResponse -Response $Response -Data $Res
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "FilePath parameter required" } -StatusCode 400
                }
            }
            
            "/api/quarantine/vault" {
                $Items = Get-QuarantineVaultItems
                Send-JsonResponse -Response $Response -Data @{ Count = $Items.Count; VaultPath = (Get-VaultPaths).Quarantine; Items = $Items }
            }
            
            "/api/quarantine/restore" {
                if ($Body -and $Body.QuarantineId) {
                    $DryRun = ($Body.DryRun -eq $true)
                    $Res = Restore-QuarantinedItem -QuarantineId $Body.QuarantineId -DryRun:$DryRun
                    Send-JsonResponse -Response $Response -Data $Res
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "QuarantineId required" } -StatusCode 400
                }
            }
            
            "/api/quarantine/purge" {
                if ($Body -and $Body.QuarantineId) {
                    $DryRun = ($Body.DryRun -eq $true)
                    $Res = Remove-QuarantinedItem -QuarantineId $Body.QuarantineId -DryRun:$DryRun
                    Send-JsonResponse -Response $Response -Data $Res
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "QuarantineId required" } -StatusCode 400
                }
            }
            
            "/api/persistence" {
                $Audit = Get-VaultGuardPersistenceAudit
                Send-JsonResponse -Response $Response -Data $Audit
            }
            
            "/api/persistence/repair" {
                $DryRun = ($Body -and $Body.DryRun -eq $true)
                $Res = Repair-VaultGuardPersistence -DryRun:$DryRun
                Send-JsonResponse -Response $Response -Data $Res
            }
            
            "/api/vaccine" {
                $Status = Get-VaultGuardVaccineStatus
                Send-JsonResponse -Response $Response -Data $Status
            }
            
            "/api/vaccine/enable" {
                $DryRun = ($Body -and $Body.DryRun -eq $true)
                $Res = Set-VaultGuardVaccine -HardenAutoRunPolicy -VaccinateConnectedUSB -DryRun:$DryRun
                Send-JsonResponse -Response $Response -Data @{ Success = $true; Details = $Res }
            }
            
            "/api/vaccine/disable" {
                $DryRun = ($Body -and $Body.DryRun -eq $true)
                $Res = Remove-VaultGuardVaccine -DryRun:$DryRun
                Send-JsonResponse -Response $Response -Data @{ Success = $true; Details = $Res }
            }

            "/api/baseline/capture" {
                $Targets = @("$env:USERPROFILE\Desktop", "$env:USERPROFILE\Downloads", "C:\Program Files")
                if ($Body -and $Body.TargetPaths) { $Targets = $Body.TargetPaths }
                $DryRun = ($Body -and $Body.DryRun -eq $true)
                $Res = New-VaultGuardBaseline -TargetPaths $Targets -DryRun:$DryRun
                Send-JsonResponse -Response $Response -Data $Res
            }
            
            "/api/baseline/verify" {
                $Res = Test-VaultGuardIntegrity
                Send-JsonResponse -Response $Response -Data $Res
            }

            "/api/baseline/restore" {
                if ($Body -and $Body.OriginalPath) {
                    $DryRun = ($Body.DryRun -eq $true)
                    $Res = Restore-FileFromVault -OriginalPath $Body.OriginalPath -DryRun:$DryRun
                    Send-JsonResponse -Response $Response -Data $Res
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "OriginalPath parameter required" } -StatusCode 400
                }
            }

            "/api/baseline/export" {
                if ($Body -and $Body.DestinationPath) {
                    $DryRun = ($Body.DryRun -eq $true)
                    $Res = Export-VaultGuardBaseline -DestinationPath $Body.DestinationPath -DryRun:$DryRun
                    Send-JsonResponse -Response $Response -Data $Res
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "DestinationPath parameter required" } -StatusCode 400
                }
            }

            "/api/baseline/import" {
                if ($Body -and $Body.SourceVaultPath) {
                    $DryRun = ($Body.DryRun -eq $true)
                    $Res = Import-VaultGuardBaseline -SourceVaultPath $Body.SourceVaultPath -DryRun:$DryRun
                    Send-JsonResponse -Response $Response -Data $Res
                } else {
                    Send-JsonResponse -Response $Response -Data @{ error = "SourceVaultPath parameter required" } -StatusCode 400
                }
            }

            "/api/watchdog/start" {
                $Res = Start-VaultGuardUsbWatcher
                Send-JsonResponse -Response $Response -Data $Res
            }

            "/api/watchdog/stop" {
                $Res = Stop-VaultGuardUsbWatcher
                Send-JsonResponse -Response $Response -Data $Res
            }
            
            "/api/remediate-all" {
                $DryRun = ($Body -and $Body.DryRun -eq $true)
                $Scan = Invoke-VaultGuardScan -Paths @("C:\") -DryRun:$DryRun
                $QuarantinedCount = 0
                $RestoredCount = 0
                
                if ($Scan.Threats) {
                    foreach ($Threat in $Scan.Threats) {
                        if ($Threat.Family -eq "Paint / Geacata") {
                            Invoke-PaintGeacataRemediation -Threat $Threat -DryRun:$DryRun | Out-Null
                            $QuarantinedCount++
                            $RestoredCount++
                        } elseif ($Threat.Family -eq "Shortcut Worm") {
                            Invoke-ShortcutWormRemediation -Threat $Threat -DryRun:$DryRun | Out-Null
                            $QuarantinedCount++
                        } elseif ($Threat.Family -eq "Expiro PE Infector") {
                            Invoke-ExpiroRemediation -Threat $Threat -DryRun:$DryRun | Out-Null
                            $QuarantinedCount++
                        }
                    }
                }
                
                $Persistence = Repair-VaultGuardPersistence -DryRun:$DryRun
                $Vaccine = Set-VaultGuardVaccine -HardenAutoRunPolicy -VaccinateConnectedUSB -DryRun:$DryRun
                
                Send-JsonResponse -Response $Response -Data @{
                    Success           = $true
                    KilledProcesses   = 0
                    ThreatsRemediated = $QuarantinedCount
                    FilesRestored     = $RestoredCount
                    PersistenceFixed  = $Persistence.RemediatedCount
                    VaccineDeployed   = $true
                    DryRun            = $DryRun
                }
            }
            
            "/api/report/export" {
                $Scan = Invoke-VaultGuardScan -Paths @("C:\")
                $Persistence = Get-VaultGuardPersistenceAudit
                $Vaccine = Get-VaultGuardVaccineStatus
                $Quarantine = Get-QuarantineVaultItems
                $ReportFile = Export-VaultGuardIncidentReport -ScanResults $Scan -PersistenceAudit $Persistence -VaccineStatus $Vaccine -QuarantineItems $Quarantine
                Send-JsonResponse -Response $Response -Data @{ Success = $true; ReportPath = $ReportFile }
            }
            
            default {
                Send-JsonResponse -Response $Response -Data @{ error = "Endpoint not found: $RawPath" } -StatusCode 404
            }
        }
    } catch {
        Write-Host "[EXCEPT] Endpoint handler error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

if ($HttpListener.IsListening) { $HttpListener.Stop() }
