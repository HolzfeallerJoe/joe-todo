<#
.SYNOPSIS
    Erzeugt aus den Original-Hintergrundbildern die komprimierten Fassungen,
    die die App tatsaechlich ausliefert.

.DESCRIPTION
    Liest app\assets\themes\*.jpg|png (die Originale, Quelle der Wahrheit) und
    schreibt nach app\assets\themes\compressed\*.jpg. Nur der Unterordner
    compressed\ ist in pubspec.yaml als Asset eingetragen und landet im APK.

    Die Aufloesung bleibt unveraendert – die Originale waren schlicht sehr
    ineffizient kodiert (holz.jpg: 3,5 MB bei 756x1612). Bilder mit
    Alphakanal werden auf Weiss flachgerechnet.

.PARAMETER Quality
    JPEG-Qualitaet 1-100 (Standard 85).

.EXAMPLE
    .\compress-theme-assets.ps1

.EXAMPLE
    .\compress-theme-assets.ps1 -Quality 90
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 100)]
    [int]$Quality = 85
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$src = Join-Path $PSScriptRoot 'app\assets\themes'
if (-not (Test-Path $src)) {
    throw "Theme-Ordner nicht gefunden unter '$src'."
}
$out = Join-Path $src "compressed"
$quality = $Quality

if (-not (Test-Path $out)) { New-Item -ItemType Directory -Path $out | Out-Null }

# JPEG encoder + quality parameter
$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
    Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Quality, [int64]$quality)

function Get-MinAlpha {
    param([System.Drawing.Bitmap]$bmp)
    if (-not [System.Drawing.Image]::IsAlphaPixelFormat($bmp.PixelFormat)) { return 255 }
    $rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                          [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $min = 255
        # BGRA order; alpha is every 4th byte
        for ($i = 3; $i -lt $bytes.Length; $i += 4) {
            if ($bytes[$i] -lt $min) { $min = $bytes[$i]; if ($min -eq 0) { break } }
        }
        return $min
    } finally { $bmp.UnlockBits($data) }
}

$report = @()
Get-ChildItem $src -File | Sort-Object Name | ForEach-Object {
    $srcFile = $_
    $bmp = New-Object System.Drawing.Bitmap($srcFile.FullName)
    $minA = Get-MinAlpha -bmp $bmp

    # Flatten onto white so any transparency becomes an opaque background.
    $flat = New-Object System.Drawing.Bitmap($bmp.Width, $bmp.Height,
                [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($flat)
    $g.Clear([System.Drawing.Color]::White)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($bmp, 0, 0, $bmp.Width, $bmp.Height)
    $g.Dispose()

    $target = Join-Path $out ([System.IO.Path]::GetFileNameWithoutExtension($srcFile.Name) + ".jpg")
    $flat.Save($target, $codec, $encParams)

    $flat.Dispose()
    $bmp.Dispose()

    $newLen = (Get-Item $target).Length
    $report += [pscustomobject]@{
        File     = $srcFile.Name
        OldKB    = [math]::Round($srcFile.Length / 1KB)
        NewKB    = [math]::Round($newLen / 1KB)
        MinAlpha = $minA
    }
}

$report | Format-Table -AutoSize
"OLD TOTAL MB = $([math]::Round((($report | Measure-Object OldKB -Sum).Sum)/1024, 2))"
"NEW TOTAL MB = $([math]::Round((($report | Measure-Object NewKB -Sum).Sum)/1024, 2))"
