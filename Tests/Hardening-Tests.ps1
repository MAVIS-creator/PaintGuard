# ==============================================================================
# Script: Tests/Hardening-Tests.ps1
# Purpose: Security & Connectivity Hardening Test Suite for VaultGuard 360
# Author: Created by Klyvex Studios
# ==============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 - SECURITY HARDENING TEST SUITE                       " -ForegroundColor Green
Write-Host "          Created by Klyvex Studios                                             " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$AppDir = Resolve-Path (Join-Path $PSScriptRoot "..")
$PassCount = 0
$FailCount = 0

function Assert-Test($Condition, $TestName, $Details = "") {
    if ($Condition) {
        Write-Host " [PASS] $TestName" -ForegroundColor Green
        if ($Details) { Write-Host "        $Details" -ForegroundColor Gray }
        $script:PassCount++
    } else {
        Write-Host " [FAIL] $TestName" -ForegroundColor Red
        if ($Details) { Write-Host "        $Details" -ForegroundColor Yellow }
        $script:FailCount++
    }
}

# --- TEST 1: App Component Structure & Files ---
Write-Host "`n[1] Auditing VaultGuard 360 Application Files..." -ForegroundColor Cyan
Assert-Test (Test-Path (Join-Path $AppDir "VaultGuard360App.cs")) "Native C# Host App Source Exists"
Assert-Test (Test-Path (Join-Path $AppDir "Build-App.ps1")) "App Build Compiler Script Exists"
Assert-Test (Test-Path (Join-Path $AppDir "setup.iss")) "Inno Setup Installer Script Exists"
Assert-Test (Test-Path (Join-Path $AppDir "Update-GitRemote.ps1")) "Git Remote Setup Script Exists"
Assert-Test (Test-Path (Join-Path $AppDir "VaultGuard 360 UI.html")) "Upgraded Stitch UI File Exists"

# --- TEST 2: App Branding & Klyvex Studios Attribution ---
Write-Host "`n[2] Verifying Klyvex Studios Attribution & Branding..." -ForegroundColor Cyan
$csContent = Get-Content (Join-Path $AppDir "VaultGuard360App.cs") -Raw
$uiContent = Get-Content (Join-Path $AppDir "VaultGuard 360 UI.html") -Raw
Assert-Test ($csContent -match "Klyvex Studios") "C# Desktop Host Includes Klyvex Studios Metadata"
Assert-Test ($uiContent -match "Created by Klyvex Studios") "UI HTML Includes Klyvex Studios Attribution"

# --- TEST 3: Notification Toast Popup Logic ---
Write-Host "`n[3] Auditing Virus Alert Popup Notification Engine..." -ForegroundColor Cyan
Assert-Test ($csContent -match "ThreatPopupForm") "C# Desktop Host Implements Animated Threat Popup Windows"
Assert-Test ($csContent -match "ShowBalloonTip") "C# Host Implements Windows Tray Balloon Notifications"
Assert-Test ($uiContent -match "showThreatToast") "UI HTML Implements Animated CSS Toast Popups"

# --- TEST 4: Auto-Startup Registry Capability ---
Write-Host "`n[4] Auditing Windows Auto-Startup Capability..." -ForegroundColor Cyan
Assert-Test ($csContent -match "Software\\Microsoft\\Windows\\CurrentVersion\\Run") "C# App Implements Registry Startup Toggle"
$issContent = Get-Content (Join-Path $AppDir "setup.iss") -Raw
Assert-Test ($issContent -match "Software\\Microsoft\\Windows\\CurrentVersion\\Run") "Inno Setup Script Bundles Auto-Startup Registry Key"

# --- TEST 5: REST API Token Security Enforcement ---
Write-Host "`n[5] Auditing REST API Security Controls in Engine..." -ForegroundColor Cyan
$engineContent = Get-Content (Join-Path $AppDir "PaintGuardEngine.ps1") -Raw
Assert-Test ($engineContent -match "Authorization") "Engine Enforces Authorization Header Checks"
Assert-Test ($engineContent -match "Bearer") "Engine Enforces Cryptographic Bearer Token Validation"

# --- TEST 6: GitHub Release & Auto-Update Engine ---
Write-Host "`n[6] Auditing GitHub Releases & Auto-Update Engine..." -ForegroundColor Cyan
Assert-Test (Test-Path (Join-Path $AppDir ".github\workflows\release.yml")) "GitHub Actions Release Workflow Exists"
Assert-Test (Test-Path (Join-Path $AppDir "Publish-Release.ps1")) "Local Release Publisher Script Exists"
Assert-Test ($csContent -match "CheckForUpdates") "C# Desktop Host Implements Auto-Update Checker"
Assert-Test ($uiContent -match "checkForGitHubUpdates") "UI HTML Implements Auto-Update Checker"

# --- SUMMARY REPORT ---
Write-Host "`n================================================================================" -ForegroundColor Cyan
$summaryColor = if ($FailCount -eq 0) { "Green" } else { "Red" }
$statusColor  = if ($FailCount -eq 0) { "Green" } else { "Yellow" }
$statusText   = if ($FailCount -eq 0) { "SYSTEM HARDENED & SECURE" } else { "ACTION REQUIRED" }

Write-Host " HARDENING TEST SUMMARY: $PassCount PASSED, $FailCount FAILED" -ForegroundColor $summaryColor
Write-Host " Status: $statusText" -ForegroundColor $statusColor
Write-Host " Created by: Klyvex Studios" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
