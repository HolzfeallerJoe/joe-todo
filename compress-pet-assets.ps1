<#
.SYNOPSIS
    Erzeugt aus den Original-Begleiterbildern die WebP-Fassungen, die die App
    ausliefert.

.DESCRIPTION
    Liest die PNG-Originale aus -Source (Ordnerstruktur wie im Download:
    Aqarell\, Axos\, Dinos_Drachen\, KalasStuff\, Katzen\, Obst\,
    Weichnachten\) und schreibt nach app\assets\pets\<kategorie>\<slug>.webp.

    Anders als bei den Hintergruenden liegen die Originale (~53 MB) NICHT im
    Repo – nur die erzeugten WebPs. Zum Neu-Erzeugen den Originalordner ueber
    -Source angeben.

    Pro Bild:
      * transparenter Rand wird abgeschnitten (die Aquarell-Motive haben viel
        Luft drumherum, sonst wirkt der Begleiter winzig),
      * laengste Kante auf -Size skaliert (Standard 320 px – reicht fuer die
        72-px-Anzeige auf dem Dashboard bis 3x-Displays),
      * als WebP mit Alphakanal gespeichert. WebP statt PNG, weil PNG hier
        rund 7x so gross waere (~6,5 MB statt ~1 MB fuer alle 53 Motive).

    Die Datei-/Ordnernamen werden dabei auf ASCII-Slugs normalisiert
    (BuecherAxo.png -> axos\buecher-axo.webp), damit die Asset-Pfade in
    pubspec.yaml ohne Umlaute und '&' auskommen.

.PARAMETER Source
    Ordner mit den Original-Unterordnern.

.PARAMETER Size
    Laengste Kante des Ergebnisses in Pixeln (Standard 320).

.PARAMETER Quality
    WebP-Qualitaet 1-100 (Standard 82).

.EXAMPLE
    .\compress-pet-assets.ps1

.EXAMPLE
    .\compress-pet-assets.ps1 -Source D:\Begleiter -Size 384 -Quality 88

.NOTES
    Benoetigt ffmpeg im PATH (fuer den WebP-Encoder libwebp).
#>
[CmdletBinding()]
param(
    [string]$Source = "$env:USERPROFILE\Downloads\Begleiter-20260810T182004Z-1-001\Begleiter",
    [ValidateRange(64, 1024)]
    [int]$Size = 320,
    [ValidateRange(1, 100)]
    [int]$Quality = 82
)

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $Source)) { throw "Quellordner nicht gefunden: '$Source'." }
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    throw "ffmpeg nicht im PATH gefunden – wird fuer die WebP-Kodierung gebraucht."
}

$out = Join-Path $PSScriptRoot 'app\assets\pets'

# Quelldatei -> Zielkategorie\Slug. Bewusst ausgeschrieben statt automatisch
# abgeleitet: die Ordner heissen im Download teils falsch geschrieben
# ("Aqarell", "Weichnachten") und einige Motive bekommen sprechendere Namen.
# Die Reihenfolge und Klartextnamen dazu stehen in app\lib\pets.dart.
$map = [ordered]@{
    'Aqarell\AquaAxolottel.png'       = 'aquarell\axolotl'
    'Aqarell\Chamelion.png'           = 'aquarell\chamaeleon'
    'Aqarell\Delfin.png'              = 'aquarell\delfin'
    'Aqarell\Fledermaus.png'          = 'aquarell\fledermaus'
    'Aqarell\Fuchs.png'               = 'aquarell\fuchs'
    'Aqarell\Hai.png'                 = 'aquarell\hai'
    'Aqarell\Katze.png'               = 'aquarell\katze'
    'Aqarell\Krebs.png'               = 'aquarell\krebs'
    'Aqarell\Llama.png'               = 'aquarell\lama'
    'Aqarell\Narwal.png'              = 'aquarell\narwal'
    'Aqarell\Nashorn.png'             = 'aquarell\nashorn'
    'Aqarell\Otter.png'               = 'aquarell\otter'
    'Aqarell\Pinguin.png'             = 'aquarell\pinguin'
    'Aqarell\Qualle.png'              = 'aquarell\qualle'
    'Aqarell\Sonne.png'               = 'aquarell\sonne'

    'Axos\BubbleteaAxo.png'           = 'axos\bubbletea-axo'
    'Axos\BücherAxo.png'              = 'axos\buecher-axo'
    'Axos\CookieAxo.png'              = 'axos\keks-axo'
    'Axos\DABAxo.png'                 = 'axos\dab-axo'
    'Axos\DreamingAxo.png'            = 'axos\schlaf-axo'
    'Axos\GamingAxo.png'              = 'axos\gaming-axo'
    'Axos\LaptopAxo.png'              = 'axos\laptop-axo'
    'Axos\OhmmAxo.png'                = 'axos\yoga-axo'
    'Axos\PhoneAxo.png'               = 'axos\handy-axo'
    'Axos\PizzaAxo.png'               = 'axos\pizza-axo'

    'Dinos_Drachen\Ankylosaurus.png'    = 'dinos\ankylosaurus'
    'Dinos_Drachen\Brontosaurus.png'    = 'dinos\brontosaurus'
    'Dinos_Drachen\BubbleteaDino.png'   = 'dinos\bubbletea-dino'
    'Dinos_Drachen\Drache.png'          = 'dinos\drache'
    'Dinos_Drachen\Pterodactyl.png'     = 'dinos\flugsaurier'
    'Dinos_Drachen\RainboDino.png'      = 'dinos\regenbogen-dino'
    'Dinos_Drachen\RainbowDiino.png'    = 'dinos\regenbogen-riese'
    'Dinos_Drachen\RainbowDinobaby.png' = 'dinos\regenbogen-baby'
    'Dinos_Drachen\T-Rex.png'           = 'dinos\t-rex'
    'Dinos_Drachen\Triceratops.png'     = 'dinos\triceratops'
    'Dinos_Drachen\Velociraptor.png'    = 'dinos\velociraptor'

    'KalasStuff\BlumenSchaf.png'      = 'kalasstuff\blumenschaf'
    'KalasStuff\Einhorn.png'          = 'kalasstuff\einhorn'
    'KalasStuff\HappySchaf.png'       = 'kalasstuff\froehliches-schaf'
    'KalasStuff\Kuh.png'              = 'kalasstuff\kuh'
    'KalasStuff\Leuchtturm.png'       = 'kalasstuff\leuchtturm'
    'KalasStuff\Schaf.png'            = 'kalasstuff\schaf'

    'Katzen\BlumeKatze.png'           = 'katzen\blumenkatze'
    'Katzen\CookieKatze.png'          = 'katzen\kekskatze'
    'Katzen\Grinsekatze.png'          = 'katzen\grinsekatze'

    'Obst\Banane.png'                 = 'obst\banane'
    'Obst\Drachenfrucht.png'          = 'obst\drachenfrucht'
    'Obst\Kiwi.png'                   = 'obst\kiwi'
    'Obst\Litchi.png'                 = 'obst\litschi'
    'Obst\Orange.png'                 = 'obst\orange'
    'Obst\Zitrone.png'                = 'obst\zitrone'

    'Weichnachten\Santa&Rudolf.png'   = 'weihnachten\santa-rudolf'
    'Weichnachten\Schneemann.png'     = 'weihnachten\schneemann'
}

# Skaliert [bmp] auf hoechstens $max Kantenlaenge und liefert eine neue Bitmap.
function Resize-Bitmap {
    param([System.Drawing.Bitmap]$bmp, [int]$max, [System.Drawing.Rectangle]$srcRect)
    $scale = $max / [math]::Max($srcRect.Width, $srcRect.Height)
    $w = [math]::Max(1, [int][math]::Round($srcRect.Width * $scale))
    $h = [math]::Max(1, [int][math]::Round($srcRect.Height * $scale))
    $dst = New-Object System.Drawing.Bitmap($w, $h,
               [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($dst)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.DrawImage($bmp, (New-Object System.Drawing.Rectangle(0, 0, $w, $h)), $srcRect,
                 [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    return $dst
}

# Umschliessendes Rechteck aller nicht (nahezu) transparenten Pixel.
function Get-AlphaBounds {
    param([System.Drawing.Bitmap]$bmp)
    $rect = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                          [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        $bytes = New-Object byte[] ($data.Stride * $bmp.Height)
        [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        $minX = $bmp.Width; $minY = $bmp.Height; $maxX = -1; $maxY = -1
        for ($y = 0; $y -lt $bmp.Height; $y++) {
            $row = $y * $data.Stride
            for ($x = 0; $x -lt $bmp.Width; $x++) {
                if ($bytes[$row + $x * 4 + 3] -gt 8) {
                    if ($x -lt $minX) { $minX = $x }
                    if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }
                    if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
    } finally { $bmp.UnlockBits($data) }
    if ($maxX -lt 0) { return $rect }  # komplett transparent: nichts abschneiden
    return New-Object System.Drawing.Rectangle($minX, $minY, ($maxX - $minX + 1), ($maxY - $minY + 1))
}

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("joe-pets-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null

$report = @()
try {
    foreach ($rel in $map.Keys) {
        $srcFile = Join-Path $Source $rel
        if (-not (Test-Path $srcFile)) {
            Write-Warning "fehlt: $rel"
            continue
        }
        $target = Join-Path $out ($map[$rel] + '.webp')
        $targetDir = Split-Path $target -Parent
        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }

        $bmp = New-Object System.Drawing.Bitmap($srcFile)

        # Zuschnitt auf einer verkleinerten Kopie suchen – ein Pixel-Loop ueber
        # 1500x1500 dauert in PowerShell spuerbar laenger als ueber 320x320.
        $full = New-Object System.Drawing.Rectangle(0, 0, $bmp.Width, $bmp.Height)
        $probe = Resize-Bitmap -bmp $bmp -max 320 -srcRect $full
        $pb = Get-AlphaBounds -bmp $probe
        $fx = $bmp.Width / $probe.Width
        $fy = $bmp.Height / $probe.Height
        $probe.Dispose()

        # Grosszuegig zurueckrechnen (1 Probe-Pixel Reserve), damit der
        # Grobzuschnitt keine weichen Aquarellkanten abschneidet.
        $x0 = [math]::Max(0, [int][math]::Floor(($pb.X - 1) * $fx))
        $y0 = [math]::Max(0, [int][math]::Floor(($pb.Y - 1) * $fy))
        $x1 = [math]::Min($bmp.Width, [int][math]::Ceiling(($pb.Right + 1) * $fx))
        $y1 = [math]::Min($bmp.Height, [int][math]::Ceiling(($pb.Bottom + 1) * $fy))
        $crop = New-Object System.Drawing.Rectangle($x0, $y0, ($x1 - $x0), ($y1 - $y0))

        $dst = Resize-Bitmap -bmp $bmp -max $Size -srcRect $crop
        $png = Join-Path $tmp 'frame.png'
        $dst.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
        $outW = $dst.Width; $outH = $dst.Height
        $dst.Dispose()
        $bmp.Dispose()

        & ffmpeg -y -loglevel error -i $png -c:v libwebp -pix_fmt yuva420p `
                 -lossless 0 -q:v $Quality -compression_level 6 $target
        if ($LASTEXITCODE -ne 0) { throw "ffmpeg ist bei '$rel' fehlgeschlagen." }
        Remove-Item $png

        $report += [pscustomobject]@{
            Pet   = $map[$rel]
            OldKB = [math]::Round((Get-Item $srcFile).Length / 1KB)
            NewKB = [math]::Round((Get-Item $target).Length / 1KB, 1)
            Px    = "${outW}x${outH}"
        }
    }
} finally {
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$report | Format-Table -AutoSize
"OLD TOTAL MB = $([math]::Round((($report | Measure-Object OldKB -Sum).Sum)/1024, 2))"
"NEW TOTAL MB = $([math]::Round((($report | Measure-Object NewKB -Sum).Sum)/1024, 2))"
"$($report.Count) Begleiter geschrieben nach $out"
