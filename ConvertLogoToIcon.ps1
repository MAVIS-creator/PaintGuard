# ==============================================================================
# Script: ConvertLogoToIcon.ps1
# Purpose: Generate high-resolution icon.ico from Stitch VaultGuard 360 logo image
# ==============================================================================

Add-Type -AssemblyName System.Drawing

$logoPath = Join-Path $PSScriptRoot "stitch_vaultguard_360_desktop_dashboard\vaultguard_360_logo\screen.png"
$outPath  = Join-Path $PSScriptRoot "icon.ico"

Write-Host "[+] Generating VaultGuard 360 icon from logo..." -ForegroundColor Cyan

if (Test-Path $logoPath) {
    try {
        $sourceImg = [System.Drawing.Bitmap]::FromFile($logoPath)
        $canvasSize = 256
        $targetBmp = New-Object System.Drawing.Bitmap $canvasSize, $canvasSize
        $g = [System.Drawing.Graphics]::FromImage($targetBmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.Clear([System.Drawing.Color]::Transparent)

        # Draw dark rounded container base
        $rectPath = New-Object System.Drawing.Drawing2D.GraphicsPath
        $rect = New-Object System.Drawing.Rectangle 4, 4, 248, 248
        $radius = 44
        $rectPath.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
        $rectPath.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
        $rectPath.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
        $rectPath.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
        $rectPath.CloseFigure()

        $p1 = New-Object System.Drawing.Point 0, 0
        $p2 = New-Object System.Drawing.Point 256, 256
        $bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($p1, $p2, [System.Drawing.Color]::FromArgb(255, 11, 19, 38), [System.Drawing.Color]::FromArgb(255, 30, 41, 59))
        $g.FillPath($bgBrush, $rectPath)

        # Draw subtle border
        $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(100, 59, 130, 246)), 3
        $g.DrawPath($borderPen, $rectPath)

        # Scale source logo inside
        $scaleFactor = [Math]::Min((200.0 / $sourceImg.Width), (200.0 / $sourceImg.Height))
        $drawW = [int]($sourceImg.Width * $scaleFactor)
        $drawH = [int]($sourceImg.Height * $scaleFactor)
        $posX = [int]((256 - $drawW) / 2)
        $posY = [int]((256 - $drawH) / 2)

        $g.DrawImage($sourceImg, $posX, $posY, $drawW, $drawH)

        # Save to ICO stream
        $hIcon = $targetBmp.GetHicon()
        $icon = [System.Drawing.Icon]::FromHandle($hIcon)
        $stream = [System.IO.File]::Create($outPath)
        $icon.Save($stream)
        $stream.Close()
        $sourceImg.Dispose()
        $targetBmp.Dispose()
        Write-Host "[SUCCESS] Icon generated successfully at $outPath" -ForegroundColor Green
    } catch {
        Write-Host "[WARNING] Could not process logo PNG directly: $_. Falling back to MakeIcon.ps1" -ForegroundColor Yellow
        & (Join-Path $PSScriptRoot "MakeIcon.ps1")
    }
} else {
    Write-Host "[INFO] Stitch logo image not found, invoking MakeIcon.ps1..." -ForegroundColor Yellow
    & (Join-Path $PSScriptRoot "MakeIcon.ps1")
}
