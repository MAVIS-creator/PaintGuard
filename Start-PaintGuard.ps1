# ==============================================================================
# Script: Start-PaintGuard.ps1
# Purpose: Administrator Elevation Check, Mutex Guard, REST Server & UI Bootstrap
# ==============================================================================

# 1. Elevation Verification
$IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $IsAdmin) {
    Write-Host "[ELEVATION] Requesting Administrator Privileges..." -ForegroundColor Yellow
    try {
        $Proc = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -PassThru
        exit
    } catch {
        Write-Host "[ERROR] Administrator privileges are required to run VaultGuard 360." -ForegroundColor Red
        Pause
        exit 1
    }
}

# 2. Single-Instance Mutex Lock
$MutexName = "Global\VaultGuard_SingleInstance_Mutex"
$CreatedNew = $false
$Mutex = New-Object System.Threading.Mutex($true, $MutexName, [ref]$CreatedNew)

if (-not $CreatedNew) {
    Write-Host "[WARNING] VaultGuard 360 is already running on this system." -ForegroundColor Red
    [System.Windows.Forms.MessageBox]::Show("VaultGuard 360 Antivirus Suite is already running on this computer.", "VaultGuard 360", 0, 48) | Out-Null
    exit 0
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host "          VAULTGUARD 360 ANTIVIRUS & VACCINE SUITE                              " -ForegroundColor Green
Write-Host "================================================================================" -ForegroundColor Cyan

# 3. Generate Cryptographically Secure Bearer Token
$Bytes = New-Object byte[] 32
$Rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$Rng.GetBytes($Bytes)
$BearerToken = [Convert]::ToBase64String($Bytes) -replace '[^a-zA-Z0-9]', ''

# 4. Discover Available Free TCP Port
$Listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, 0)
$Listener.Start()
$Port = ($Listener.LocalEndpoint).Port
$Listener.Stop()

Write-Host "[+] Working Directory:    $PSScriptRoot" -ForegroundColor Cyan
Write-Host "[+] Local REST Host:      http://127.0.0.1:$Port/" -ForegroundColor Cyan
Write-Host "[+] Session Bearer Token: $BearerToken" -ForegroundColor Cyan

# 5. Launch REST Engine Background Process with Explicit Working Directory
$EngineScript = Join-Path -Path $PSScriptRoot -ChildPath "PaintGuardEngine.ps1"
$EngineProcess = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$EngineScript`" -Port $Port -BearerToken `"$BearerToken`"" -WorkingDirectory $PSScriptRoot -WindowStyle Hidden -PassThru

# Wait for Engine Readiness
Write-Host "[+] Initializing Security Engine..." -NoNewline
$EngineReady = $false
for ($i = 0; $i -lt 10; $i++) {
    Start-Sleep -Milliseconds 500
    try {
        $Req = [System.Net.WebRequest]::Create("http://127.0.0.1:$Port/api/status")
        $Req.Headers.Add("Authorization", "Bearer $BearerToken")
        $Req.Timeout = 1000
        $Resp = $Req.GetResponse()
        if ($Resp.StatusCode -eq 200) {
            $EngineReady = $true
            $Resp.Close()
            break
        }
    } catch {}
    Write-Host "." -NoNewline
}
Write-Host ""

if (-not $EngineReady) {
    Write-Host "[ERROR] Engine failed to respond on port $Port within timeout." -ForegroundColor Red
    Pause
    exit 1
}

Write-Host "[SUCCESS] VaultGuard 360 Engine Active!" -ForegroundColor Green

# 6. Launch Microsoft Edge in App Mode (or default browser) with AppUserModelID
$UiUrl = "http://127.0.0.1:$Port/?token=$BearerToken"
$EdgePath = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
if (-not (Test-Path $EdgePath)) {
    $EdgePath = "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
}

if (Test-Path $EdgePath) {
    Write-Host "[+] Opening VaultGuard 360 App UI in native Edge Window..." -ForegroundColor Cyan
    Start-Process -FilePath $EdgePath -ArgumentList "--app=`"$UiUrl`" --user-data-dir=`"$env:TEMP\VaultGuardEdgeProfile`" --app-id=`"VaultGuard360`""
} else {
    Write-Host "[+] Opening VaultGuard 360 App UI in default Web Browser..." -ForegroundColor Cyan
    Start-Process $UiUrl
}

Write-Host "================================================================================" -ForegroundColor Cyan
Write-Host " VaultGuard 360 is running in the background. Press CTRL+C to stop.           " -ForegroundColor Yellow
Write-Host "================================================================================" -ForegroundColor Cyan

# Keep process alive while engine runs
try {
    while (-not $EngineProcess.HasExited) {
        Start-Sleep -Seconds 1
    }
} finally {
    if ($Mutex) {
        $Mutex.ReleaseMutex()
        $Mutex.Dispose()
    }
    if ($EngineProcess -and -not $EngineProcess.HasExited) {
        Stop-Process -Id $EngineProcess.Id -Force -ErrorAction SilentlyContinue
    }
}
