# ==============================================================================
# Script: Build-Installer.ps1
# Purpose: Compile setup.iss into VaultGuard360_Setup.exe using Inno Setup Compiler
# Author: Created by Klyvex Studios
# ==============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 - INNO SETUP INSTALLER BUILDER                        " -ForegroundColor Green
Write-Host "          Created by Klyvex Studios                                             " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$AppDir = $PSScriptRoot
Set-Location $AppDir

# First, ensure app executable is built
Write-Host "[1/2] Verifying VaultGuard360.exe..." -ForegroundColor Cyan
if (-not (Test-Path (Join-Path $AppDir "VaultGuard360.exe"))) {
    Write-Host "[+] Compiling VaultGuard360.exe first..." -ForegroundColor Yellow
    & (Join-Path $AppDir "Build-App.ps1")
}

# Locate Inno Setup Compiler (ISCC.exe)
Write-Host "[2/2] Locating Inno Setup Compiler (ISCC.exe)..." -ForegroundColor Cyan
$IsccPaths = @(
    "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
    "C:\Program Files\Inno Setup 6\ISCC.exe",
    "C:\Program Files (x86)\Inno Setup 5\ISCC.exe",
    "C:\Program Files\Inno Setup 5\ISCC.exe"
)

$IsccPath = $IsccPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($IsccPath) {
    Write-Host "[+] Found Inno Setup Compiler at: $IsccPath" -ForegroundColor Green
    $IssFile = Join-Path $AppDir "setup.iss"
    $Process = Start-Process -FilePath $IsccPath -ArgumentList "`"$IssFile`"" -Wait -PassThru -NoNewWindow
    
    if ($Process.ExitCode -eq 0) {
        Write-Host "`n================================================================================" -ForegroundColor Cyan
        Write-Host " [SUCCESS] Installer VaultGuard360_Setup.exe built successfully!" -ForegroundColor Green
        Write-Host " Location: $(Join-Path $AppDir 'Output\VaultGuard360_Setup.exe')" -ForegroundColor Yellow
        Write-Host " Created by: Klyvex Studios" -ForegroundColor Green
        Write-Host "================================================================================" -ForegroundColor Cyan
    } else {
        Write-Host "[ERROR] Inno Setup compilation failed with exit code $($Process.ExitCode)." -ForegroundColor Red
    }
} else {
    Write-Host "[!] ISCC.exe command-line compiler was not found in default Program Files paths." -ForegroundColor Yellow
    Write-Host "To generate the installer setup file:" -ForegroundColor Cyan
    Write-Host " 1. Open Inno Setup Compiler GUI on your machine." -ForegroundColor White
    Write-Host " 2. Open file: $(Join-Path $AppDir 'setup.iss')" -ForegroundColor White
    Write-Host " 3. Click 'Compile' (F9) to generate VaultGuard360_Setup.exe!" -ForegroundColor White
}
