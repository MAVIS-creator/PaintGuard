# ==============================================================================
# Script: Publish-Release.ps1
# Purpose: Create release tag v2.5.0 and publish to GitHub Releases
# Author: Created by Klyvex Studios
# ==============================================================================

param (
    [string]$VersionTag = "v2.5.0",
    [string]$ReleaseNotes = "VaultGuard 360 Native Desktop Suite v2.5.0 by Klyvex Studios"
)

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 - GITHUB RELEASE PUBLISHER                             " -ForegroundColor Green
Write-Host "          Created by Klyvex Studios                                             " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$AppDir = $PSScriptRoot
Set-Location $AppDir

# 1. Compile binaries locally
Write-Host "[1/3] Compiling App & Installer setup..." -ForegroundColor Cyan
& (Join-Path $AppDir "Build-App.ps1")
& (Join-Path $AppDir "Build-Installer.ps1")

# 2. Tag repository
Write-Host "[2/3] Tagging local repository with $VersionTag..." -ForegroundColor Cyan
git tag -a $VersionTag -m "$ReleaseNotes" 2>&1
git push origin $VersionTag 2>&1

# 3. Publish using GitHub CLI if installed
Write-Host "[3/3] Publishing Release to GitHub..." -ForegroundColor Cyan
$ghCheck = Get-Command gh -ErrorAction SilentlyContinue

if ($ghCheck) {
    Write-Host "[+] GitHub CLI (gh) found. Publishing release $VersionTag..." -ForegroundColor Green
    $InstallerPath = Join-Path $AppDir "Output\VaultGuard360_Setup.exe"
    $ExePath       = Join-Path $AppDir "VaultGuard360.exe"
    
    gh release create $VersionTag "$InstallerPath" "$ExePath" --title "VaultGuard 360 $VersionTag" --notes "$ReleaseNotes"
    Write-Host "`n[SUCCESS] Release $VersionTag published to https://github.com/MAVIS-creator/PaintGuard/releases !" -ForegroundColor Green
} else {
    Write-Host "[+] Tag $VersionTag pushed to GitHub! GitHub Actions workflow will build the release automatically." -ForegroundColor Green
    Write-Host "Visit: https://github.com/MAVIS-creator/PaintGuard/releases" -ForegroundColor Yellow
}
