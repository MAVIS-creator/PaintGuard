# ==============================================================================
# Script: Build-Installer.ps1
# Purpose: Compile VaultGuard 360 Custom WPF Setup Executable (VaultGuard360_Setup.exe)
# Author: Created by Klyvex Studios
# ==============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 - CUSTOM WPF INSTALLER BUILDER                       " -ForegroundColor Green
Write-Host "          Created by Klyvex Studios                                             " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$AppDir = $PSScriptRoot
Set-Location $AppDir

# 1. Compile Core App into bin\Publish as a single-file binary
Write-Host "[1/4] Compiling VaultGuard 360 Core App..." -ForegroundColor Cyan
& dotnet publish .\VaultGuard360.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o .\bin\Publish\

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Core App Build failed." -ForegroundColor Red
    exit 1
}

# 2. Package bin\Publish into payload.zip
Write-Host "[2/4] Packaging core application binaries into payload.zip..." -ForegroundColor Cyan
Remove-Item ".\payload.zip" -ErrorAction SilentlyContinue
Compress-Archive -Path ".\bin\Publish\*" -DestinationPath ".\payload.zip" -Force

# 3. Compile Custom WPF Installer App
Write-Host "[3/4] Compiling Custom WPF Setup App (VaultGuard360_Setup.exe)..." -ForegroundColor Cyan
& dotnet publish .\VaultGuard360.Setup.csproj -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o .\bin\SingleFilePublish\

if ($LASTEXITCODE -eq 0) {
    Copy-Item ".\bin\SingleFilePublish\VaultGuard360_Setup.exe" ".\VaultGuard360_Setup.exe" -Force -ErrorAction SilentlyContinue
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " [SUCCESS] VaultGuard360_Setup.exe compiled successfully!" -ForegroundColor Green
    Write-Host " Custom WPF Installer Path: $(Join-Path $AppDir 'VaultGuard360_Setup.exe')" -ForegroundColor Yellow
    Write-Host " Created by: Klyvex Studios" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Custom Installer Build failed with exit code $LASTEXITCODE." -ForegroundColor Red
}
