# ==============================================================================
# Module: VaultGuard.Vaccine.psm1
# Purpose: Immunization Traps, AutoRun Policy Hardening, USB Auto-Vaccine Service Watcher
# ==============================================================================

$script:TargetVaccinePaths = @(
    "C:\paint.exe",
    "$env:APPDATA\paint.exe",
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup\paint.lnk",
    "$env:PROGRAMDATA\Microsoft\Windows\Start Menu\Programs\StartUp\paint.lnk"
)

function Set-VaultGuardVaccine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$HardenAutoRunPolicy,
        [switch]$VaccinateConnectedUSB,
        [switch]$DryRun
    )

    $Results = @()

    # 1. Administer Immutable Directory Traps on Protected Paths
    foreach ($Path in $script:TargetVaccinePaths) {
        if ($DryRun -or $WhatIfPreference) {
            $Results += [PSCustomObject]@{ Path = $Path; Status = "DryRun: Would create vaccine trap" }
            continue
        }

        try {
            if (Test-Path $Path) {
                $Item = Get-Item -LiteralPath $Path -Force
                if (-not $Item.PSIsContainer) { Remove-Item -Path $Path -Force }
            }

            if (-not (Test-Path $Path)) {
                New-Item -ItemType Directory -Path $Path -Force | Out-Null
            }

            # Apply Deny Write & Deny Delete ACLs if NTFS
            $Drive = Split-Path -Path $Path -Qualifier
            $Format = (Get-Volume -DriveLetter ($Drive -replace ':', '') -ErrorAction SilentlyContinue).FileSystemType

            if ($Format -eq "NTFS") {
                $Acl = Get-Acl -Path $Path
                $DenyRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "Write, Delete", "ContainerInherit, ObjectInherit", "None", "Deny")
                $Acl.AddAccessRule($DenyRule)
                Set-Acl -Path $Path -AclObject $Acl -ErrorAction SilentlyContinue
            }

            $Results += [PSCustomObject]@{ Path = $Path; Status = "VACCINATED"; FileSystem = $Format }
        } catch {
            $Results += [PSCustomObject]@{ Path = $Path; Status = "ERROR: $($_.Exception.Message)" }
        }
    }

    # 2. Harden AutoRun Registry Policy (NoDriveTypeAutoRun = 0xFF)
    if ($HardenAutoRunPolicy) {
        if (-not ($DryRun -or $WhatIfPreference)) {
            $RegPaths = @(
                "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer",
                "HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
            )
            foreach ($RP in $RegPaths) {
                if (-not (Test-Path $RP)) { New-Item -Path $RP -Force | Out-Null }
                Set-ItemProperty -Path $RP -Name "NoDriveTypeAutoRun" -Value 0xFF -Type DWord -Force | Out-Null
            }
        }
    }

    # 3. Vaccinate Connected USB Media (FAT32 & NTFS empty autorun.inf folder trick)
    if ($VaccinateConnectedUSB) {
        $UsbDrives = Get-Volume | Where-Object { $_.DriveType -eq "Removable" -and $_.DriveLetter }
        foreach ($Usb in $UsbDrives) {
            $AutorunFolder = "$($Usb.DriveLetter):\autorun.inf"
            if ($DryRun -or $WhatIfPreference) {
                $Results += [PSCustomObject]@{ Path = $AutorunFolder; Status = "DryRun: Would vaccinate USB" }
                continue
            }

            try {
                if (Test-Path $AutorunFolder) {
                    $Item = Get-Item -LiteralPath $AutorunFolder -Force
                    if (-not $Item.PSIsContainer) { Remove-Item -Path $AutorunFolder -Force }
                }
                if (-not (Test-Path $AutorunFolder)) {
                    New-Item -ItemType Directory -Path $AutorunFolder -Force | Out-Null
                }
                $Results += [PSCustomObject]@{ Path = $AutorunFolder; Status = "USB_VACCINATED" }
            } catch {}
        }
    }

    return $Results
}

function Remove-VaultGuardVaccine {
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        [switch]$DryRun
    )

    $Results = @()

    foreach ($Path in $script:TargetVaccinePaths) {
        if ($DryRun -or $WhatIfPreference) {
            $Results += [PSCustomObject]@{ Path = $Path; Status = "DryRun: Would remove vaccine trap" }
            continue
        }

        try {
            if (Test-Path $Path) {
                $Acl = Get-Acl -Path $Path
                $Acl.Access | Where-Object { $_.AccessControlType -eq "Deny" } | ForEach-Object { $Acl.RemoveAccessRule($_) }
                Set-Acl -Path $Path -AclObject $Acl -ErrorAction SilentlyContinue
                Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
                $Results += [PSCustomObject]@{ Path = $Path; Status = "REMOVED" }
            }
        } catch {
            $Results += [PSCustomObject]@{ Path = $Path; Status = "ERROR: $($_.Exception.Message)" }
        }
    }

    return $Results
}

function Get-VaultGuardVaccineStatus {
    [CmdletBinding()]
    param()

    $Statuses = @()
    $AllVaccinated = $true

    foreach ($Path in $script:TargetVaccinePaths) {
        $IsVac = $false
        $Details = "Missing"

        if (Test-Path $Path) {
            $Item = Get-Item -LiteralPath $Path -Force
            if ($Item.PSIsContainer) {
                $IsVac = $true
                $Details = "Directory trap present"
            }
        } else {
            $AllVaccinated = $false
        }

        $Statuses += [PSCustomObject]@{
            Path         = $Path
            IsVaccinated = $IsVac
            Details      = $Details
        }
    }

    # Check AutoRun Policy
    $AutoRunLocked = $false
    try {
        $Val = (Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" -Name "NoDriveTypeAutoRun" -ErrorAction SilentlyContinue).NoDriveTypeAutoRun
        if ($Val -eq 255) { $AutoRunLocked = $true }
    } catch {}

    return @{
        FullyVaccinated      = $AllVaccinated
        AutoRunPolicyLocked  = $AutoRunLocked
        PathStatuses         = $Statuses
    }
}

# ------------------------------------------------------------------------------
# Real-Time USB Win32_VolumeChangeEvent Service Watcher
# ------------------------------------------------------------------------------

$script:UsbWatcher = $null

function Start-VaultGuardUsbWatcher {
    [CmdletBinding()]
    param()

    if ($script:UsbWatcher) {
        return @{ Success = $true; Message = "USB Watcher is already running." }
    }

    $Query = "SELECT * FROM Win32_VolumeChangeEvent WHERE EventType = 2" # Drive Arrival
    $script:UsbWatcher = Register-CimIndicationEvent -Query $Query -SourceIdentifier "VaultGuard_USB_Arrival" -Action {
        $DriveLetter = $Event.SourceEventArgs.NewEvent.DriveName
        if ($DriveLetter) {
            # Auto-vaccinate and scan newly inserted USB drive
            Set-VaultGuardVaccine -VaccinateConnectedUSB | Out-Null
        }
    }

    return @{
        Success   = $true
        Message   = "USB VolumeChangeEvent Watcher started successfully."
        SourceId  = "VaultGuard_USB_Arrival"
    }
}

function Stop-VaultGuardUsbWatcher {
    [CmdletBinding()]
    param()

    if ($script:UsbWatcher) {
        Unregister-Event -SourceIdentifier "VaultGuard_USB_Arrival" -ErrorAction SilentlyContinue
        $script:UsbWatcher = $null
        return @{ Success = $true; Message = "USB Watcher stopped." }
    }
    return @{ Success = $true; Message = "USB Watcher was not active." }
}

Export-ModuleMember -Function Set-VaultGuardVaccine, Remove-VaultGuardVaccine, Get-VaultGuardVaccineStatus, Start-VaultGuardUsbWatcher, Stop-VaultGuardUsbWatcher
