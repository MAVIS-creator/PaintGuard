@echo off
title VaultGuard 360 - Full Automated Build and Hardening Pipeline (Klyvex Studios)
color 0A

echo ================================================================================
echo           VAULTGUARD 360 - AUTOMATED BUILD AND HARDENING PIPELINE
echo           Created by Klyvex Studios
echo ================================================================================
echo.

cd /d "%~dp0"

echo [1/4] Linking Git Repository...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Update-GitRemote.ps1"
echo.

echo [2/4] Generating Icon and Compiling VaultGuard360.exe...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-App.ps1"
echo.

echo [3/4] Running Security Hardening Tests...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Tests\Hardening-Tests.ps1"
echo.

echo [4/4] Building Installer Setup File (VaultGuard360_Setup.exe)...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Build-Installer.ps1"
echo.

echo ================================================================================
echo [COMPLETE] All VaultGuard 360 build and hardening steps completed!
echo ================================================================================
pause
