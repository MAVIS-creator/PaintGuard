# ==============================================================================
# Script: Update-GitRemote.ps1
# Purpose: Link workspace git remote to https://github.com/MAVIS-creator/PaintGuard.git
# ==============================================================================

$TargetRepo = "https://github.com/MAVIS-creator/PaintGuard.git"
Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 - GIT REMOTE CONFIGURATION                             " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

try {
    # Check if git is installed
    $gitCheck = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCheck) {
        Write-Host "[!] Git CLI is not found on PATH. Please ensure Git for Windows is installed." -ForegroundColor Yellow
        exit 1
    }

    # Ensure git repo is initialized
    if (-not (Test-Path (Join-Path $PSScriptRoot ".git"))) {
        Write-Host "[+] Initializing git repository in workspace..." -ForegroundColor Cyan
        git init
        git branch -M main
    }

    # Check current remotes
    $remotes = git remote -v 2>&1
    if ($remotes -match "origin") {
        Write-Host "[+] Updating existing 'origin' remote URL to: $TargetRepo" -ForegroundColor Cyan
        git remote set-url origin $TargetRepo
    } else {
        Write-Host "[+] Adding new 'origin' remote URL: $TargetRepo" -ForegroundColor Cyan
        git remote add origin $TargetRepo
    }

    Write-Host "`n[SUCCESS] Git remote set successfully!" -ForegroundColor Green
    Write-Host "Current configured remotes:" -ForegroundColor Yellow
    git remote -v

    Write-Host "`nBranch Status:" -ForegroundColor Yellow
    git status -s
} catch {
    Write-Host "[ERROR] Failed to update git remote: $_" -ForegroundColor Red
}
