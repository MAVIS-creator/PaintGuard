# ==============================================================================
# Script: Build-App.ps1
# Purpose: Compile VaultGuard360App.cs into VaultGuard360.exe using .NET Framework csc.exe
# Author: Created by Klyvex Studios
# ==============================================================================

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 - NATIVE DESKTOP EXECUTABLE COMPILER                   " -ForegroundColor Green
Write-Host "          Created by Klyvex Studios                                             " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

$AppDir = $PSScriptRoot
Set-Location $AppDir

# 1. Ensure Icon exists
Write-Host "[1/3] Verifying App Icon..." -ForegroundColor Cyan
& (Join-Path $AppDir "ConvertLogoToIcon.ps1")
$IconPath = Join-Path $AppDir "icon.ico"

# 2. Locate .NET Framework csc.exe compiler
Write-Host "[2/3] Locating C# Compiler (csc.exe)..." -ForegroundColor Cyan
$CscPath = Join-Path $env:SystemRoot "Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (-not (Test-Path $CscPath)) {
    $CscPath = Join-Path $env:SystemRoot "Microsoft.NET\Framework\v4.0.30319\csc.exe"
}

if (-not (Test-Path $CscPath)) {
    Write-Host "[ERROR] .NET Framework csc.exe compiler not found at $CscPath." -ForegroundColor Red
    exit 1
}

Write-Host "[+] Compiler found at: $CscPath" -ForegroundColor Green

# 3. Compile C# App Host into Windows Executable
Write-Host "[3/3] Compiling VaultGuard360.exe..." -ForegroundColor Cyan
$SourceFile = Join-Path $AppDir "VaultGuard360App.cs"
$OutputFile = Join-Path $AppDir "VaultGuard360.exe"

$References = "System.dll", "System.Windows.Forms.dll", "System.Drawing.dll", "System.Core.dll"
$RefArgs = $References | ForEach-Object { "/r:$_" }

$CompilerArgs = @(
    "/target:winexe",
    "/out:`"$OutputFile`"",
    "/win32icon:`"$IconPath`""
) + $RefArgs + "`"$SourceFile`""

$Process = Start-Process -FilePath $CscPath -ArgumentList ($CompilerArgs -join " ") -Wait -PassThru -NoNewWindow

if ($Process.ExitCode -eq 0 -and (Test-Path $OutputFile)) {
    Write-Host "`n================================================================================" -ForegroundColor Cyan
    Write-Host " [SUCCESS] VaultGuard360.exe compiled successfully!" -ForegroundColor Green
    Write-Host " File Path: $OutputFile" -ForegroundColor Yellow
    Write-Host " Created by: Klyvex Studios" -ForegroundColor Green
    Write-Host "================================================================================" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Compilation failed with exit code $($Process.ExitCode)." -ForegroundColor Red
}
