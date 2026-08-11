; ==============================================================================
; Script: setup.iss
; Purpose: Inno Setup Script for VaultGuard 360 Antivirus & Vaccine Suite
; Publisher: Klyvex Studios
; ==============================================================================

#define MyAppName "VaultGuard 360"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Klyvex Studios"
#define MyAppURL "https://github.com/MAVIS-creator/PaintGuard"
#define MyAppExeName "VaultGuard360.exe"

[Setup]
AppId={{D37E86B1-9472-4F11-9A34-47B2E5C9A18D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\VaultGuard 360
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
LicenseFile=LICENSE
PrivilegesRequired=admin
OutputBaseFilename=VaultGuard360_Setup
SetupIconFile=icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#MyAppExeName}

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "autostart"; Description: "Run VaultGuard 360 automatically when Windows starts"; GroupDescription: "Startup Options:"

[Files]
Source: "VaultGuard360.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "PaintGuardEngine.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Start-PaintGuard.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "VaultGuard 360 UI.html"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.ico"; DestDir: "{app}"; Flags: ignoreversion
Source: "icon.svg"; DestDir: "{app}"; Flags: ignoreversion
Source: "Attributes.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Audit-PaintVirus.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Final-Clearance-Check.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Paint-Virus-Vaccine.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "RecoveryPlan.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "Safe-Malware-Sweeper.ps1"; DestDir: "{app}"; Flags: ignoreversion
Source: "vHidden_C.csv"; DestDir: "{app}"; Flags: ignoreversion
Source: "Modules\*"; DestDir: "{app}\Modules"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\icon.ico"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "VaultGuard360"; ValueData: """{app}\{#MyAppExeName}"" --autostart"; Flags: uninsdeletevalue; Tasks: autostart

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
