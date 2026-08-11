# Contributing to PaintGuard Enterprise

Thank you for your interest in contributing to **PaintGuard Enterprise Cyber Security & Vaccine Suite**!

## Development & Code Style Guidelines

1. **PowerShell Module Standard**:
   - Store module code under `Modules/PaintGuard.<Feature>.psm1`.
   - Use standard PowerShell cmdlet verb-noun pairs (e.g., `Get-PaintGuardStatus`, `Invoke-PaintGuardScan`).
   - Support `-WhatIf` / `ShouldProcess` on state-changing cmdlets.

2. **Security Controls**:
   - Never terminate processes by process name alone; always verify executable path and SHA-256 hash.
   - Never delete user files directly; use `Protect-FileToQuarantine` from `PaintGuard.Remediation.psm1`.

3. **UI & Frontend**:
   - PaintGuard UI uses vanilla HTML5, CSS3 glassmorphism, and JavaScript. Do not introduce heavy node_modules dependencies.

4. **Testing**:
   - Verify PowerShell syntax with `[System.Management.Automation.PSParser]::Tokenize`.
   - Test module imports prior to submitting PRs.
