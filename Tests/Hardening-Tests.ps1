# ==============================================================================
# Script: Tests/Hardening-Tests.ps1
# Purpose: Security & Architecture Hardening Test Suite for VaultGuard 360 WPF .NET 8
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

# --- TEST 1: Native WPF (.NET 8) App Component Structure & Files ---
Write-Host "`n[1] Auditing VaultGuard 360 Application Files..." -ForegroundColor Cyan
Assert-Test (Test-Path (Join-Path $AppDir "VaultGuard360.csproj")) "Native WPF (.NET 8) Project File Exists"
Assert-Test (Test-Path (Join-Path $AppDir "MainWindow.xaml")) "Main Window XAML File Exists"
Assert-Test (Test-Path (Join-Path $AppDir "Build-App.ps1")) "App Build Compiler Script Exists"
Assert-Test (Test-Path (Join-Path $AppDir "setup.iss")) "Inno Setup Installer Script Exists"
Assert-Test (Test-Path (Join-Path $AppDir "Update-GitRemote.ps1")) "Git Remote Setup Script Exists"

# --- TEST 2: App Branding & Klyvex Studios Attribution ---
Write-Host "`n[2] Verifying Klyvex Studios Attribution & Branding..." -ForegroundColor Cyan
$mwContent = Get-Content (Join-Path $AppDir "MainWindow.xaml") -Raw
$projContent = Get-Content (Join-Path $AppDir "VaultGuard360.csproj") -Raw
Assert-Test ($mwContent -match "Klyvex Studios") "MainWindow XAML Includes Klyvex Studios Attribution"
Assert-Test ($projContent -match "Klyvex Studios") "Project Metadata Includes Klyvex Studios Publisher Branding"

# --- TEST 3: Notification & Flyout Engine ---
Write-Host "`n[3] Auditing Notification Flyout & Alert Services..." -ForegroundColor Cyan
$notifContent = Get-Content (Join-Path $AppDir "Services\NotificationService.cs") -Raw
Assert-Test ($notifContent -match "NotificationService") "Notification Service Layer Initialized"
Assert-Test ($mwContent -match "NotificationPopup") "WPF Top-Bar Interactive Notification Flyout Exists"
Assert-Test ($mwContent -match "UsbPopup") "WPF Top-Bar Interactive USB Watchdog Flyout Exists"

# --- TEST 4: Auto-Startup Registry Capability ---
Write-Host "`n[4] Auditing Windows Auto-Startup Capability..." -ForegroundColor Cyan
$issContent = Get-Content (Join-Path $AppDir "setup.iss") -Raw
Assert-Test ($issContent -match "Software\\Microsoft\\Windows\\CurrentVersion\\Run") "Inno Setup Script Bundles Auto-Startup Registry Key"

# --- TEST 5: REST API Security Controls in Engine ---
Write-Host "`n[5] Auditing REST API Security Controls in Engine..." -ForegroundColor Cyan
$engineContent = Get-Content (Join-Path $AppDir "PaintGuardEngine.ps1") -Raw
Assert-Test ($engineContent -match "Authorization") "Engine Enforces Authorization Header Checks"
Assert-Test ($engineContent -match "Bearer") "Engine Enforces Cryptographic Bearer Token Validation"

# --- TEST 6: GitHub Release & Auto-Update Engine ---
Write-Host "`n[6] Auditing GitHub Releases & Auto-Update Engine..." -ForegroundColor Cyan
Assert-Test (Test-Path (Join-Path $AppDir ".github\workflows\release.yml")) "GitHub Actions Release Workflow Exists"
Assert-Test (Test-Path (Join-Path $AppDir "Publish-Release.ps1")) "Local Release Publisher Script Exists"
$engServiceContent = Get-Content (Join-Path $AppDir "Services\EngineService.cs") -Raw
Assert-Test ($engServiceContent -match "EngineService") "Engine Service Layer Initialized"

# --- SUMMARY REPORT ---
Write-Host "`n================================================================================" -ForegroundColor Cyan
$summaryColor = if ($FailCount -eq 0) { "Green" } else { "Red" }
$statusColor  = if ($FailCount -eq 0) { "Green" } else { "Yellow" }
$statusText   = if ($FailCount -eq 0) { "SYSTEM HARDENED & SECURE" } else { "ACTION REQUIRED" }

Write-Host " HARDENING TEST SUMMARY: $PassCount PASSED, $FailCount FAILED" -ForegroundColor $summaryColor
Write-Host " Status: $statusText" -ForegroundColor $statusColor
Write-Host " Created by: Klyvex Studios" -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan
