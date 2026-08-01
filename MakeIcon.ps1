Add-Type -AssemblyName System.Drawing

$bmp = New-Object System.Drawing.Bitmap 256, 256
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

# Outer Dark Rounded Square Base
$rectPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$rect = New-Object System.Drawing.Rectangle 8, 8, 240, 240
$radius = 48
$rectPath.AddArc($rect.X, $rect.Y, $radius, $radius, 180, 90)
$rectPath.AddArc($rect.Right - $radius, $rect.Y, $radius, $radius, 270, 90)
$rectPath.AddArc($rect.Right - $radius, $rect.Bottom - $radius, $radius, $radius, 0, 90)
$rectPath.AddArc($rect.X, $rect.Bottom - $radius, $radius, $radius, 90, 90)
$rectPath.CloseFigure()

$p1 = New-Object System.Drawing.Point 0, 0
$p2 = New-Object System.Drawing.Point 256, 256
$c1 = [System.Drawing.Color]::FromArgb(255, 15, 23, 42)
$c2 = [System.Drawing.Color]::FromArgb(255, 30, 41, 59)
$bgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($p1, $p2, $c1, $c2)

$g.FillPath($bgBrush, $rectPath)

# Shield Polygon
$c3 = [System.Drawing.Color]::FromArgb(255, 37, 99, 235)
$c4 = [System.Drawing.Color]::FromArgb(255, 29, 78, 216)
$shieldBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($p1, $p2, $c3, $c4)

$points = [System.Drawing.Point[]]@(
    (New-Object System.Drawing.Point 128, 44),
    (New-Object System.Drawing.Point 196, 62),
    (New-Object System.Drawing.Point 196, 128),
    (New-Object System.Drawing.Point 128, 212),
    (New-Object System.Drawing.Point 60, 128),
    (New-Object System.Drawing.Point 60, 62)
)

$g.FillPolygon($shieldBrush, $points)

# Checkmark
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 16, 185, 129)), 16
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

$g.DrawLine($pen, 96, 126, 118, 150)
$g.DrawLine($pen, 118, 150, 160, 102)

# Save Icon
$hIcon = $bmp.GetHicon()
$icon = [System.Drawing.Icon]::FromHandle($hIcon)
$outPath = Join-Path $PSScriptRoot "icon.ico"
$stream = [System.IO.File]::Create($outPath)
$icon.Save($stream)
$stream.Close()
$bmp.Dispose()
Write-Host "ICON CREATED AT: $outPath"
