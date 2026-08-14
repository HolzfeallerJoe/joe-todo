<#
.SYNOPSIS
    Baut das Debug-APK von Joe – dasselbe Artefakt wie "Build > Build APK(s)" in Android Studio.

.DESCRIPTION
    Standardweg ist `flutter build apk --debug`: debuggable, signiert mit dem
    Android-Debug-Keystore (~/.android/debug.keystore), universal (alle ABIs).
    Mit -Gradle laeuft stattdessen woertlich das, was Android Studio ausfuehrt:
    der Gradle-Wrapper mit der Task assembleDebug.

.PARAMETER Install
    Installiert das fertige APK per adb auf dem verbundenen Geraet/Emulator.

.PARAMETER Device
    Seriennummer fuer adb -s (nur zusammen mit -Install noetig, wenn mehrere
    Geraete verbunden sind). Ohne Angabe nimmt das Skript das einzige
    angeschlossene Geraet und listet sonst die vorhandenen auf.

.PARAMETER Gradle
    Baut ueber android\gradlew assembleDebug statt ueber die Flutter-CLI.

.PARAMETER SkipPubGet
    Ueberspringt `flutter pub get`.

.EXAMPLE
    .\build-debug-apk.ps1

.EXAMPLE
    .\build-debug-apk.ps1 -Install

.EXAMPLE
    .\build-debug-apk.ps1 -Install -Device emulator-5554

.EXAMPLE
    .\build-debug-apk.ps1 -Gradle
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [string]$Device,
    [switch]$Gradle,
    [switch]$SkipPubGet
)

$ErrorActionPreference = 'Stop'

$appDir = Join-Path $PSScriptRoot 'app'
if (-not (Test-Path (Join-Path $appDir 'pubspec.yaml'))) {
    throw "Flutter-Projekt nicht gefunden unter '$appDir'."
}

function Resolve-FlutterExe {
    $cmd = Get-Command flutter -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }

    # Fallback: flutter.sdk aus android/local.properties (setzt Android Studio/Flutter selbst).
    $localProps = Join-Path $appDir 'android\local.properties'
    if (Test-Path $localProps) {
        $line = Select-String -Path $localProps -Pattern '^\s*flutter\.sdk\s*=\s*(.+)$' |
            Select-Object -First 1
        if ($line) {
            $sdk = $line.Matches[0].Groups[1].Value.Trim() -replace '\\\\', '\'
            $exe = Join-Path $sdk 'bin\flutter.bat'
            if (Test-Path $exe) { return $exe }
        }
    }
    throw 'flutter wurde nicht gefunden – weder im PATH noch als flutter.sdk in android\local.properties.'
}

function Invoke-Step {
    # Achtung: der Parameter darf nicht $Args heissen – das ist eine
    # automatische Variable und wuerde die uebergebenen Argumente schlucken.
    param([string]$Label, [string]$Exe, [string[]]$Arguments)

    Write-Host "==> $Label" -ForegroundColor Cyan
    & $Exe @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Label fehlgeschlagen (Exit-Code $LASTEXITCODE)."
    }
}

Push-Location $appDir
try {
    $flutter = Resolve-FlutterExe
    $startedAt = Get-Date

    # Die Schalter aus env\.env kommen als --dart-define-from-file in den
    # Build (siehe app\lib\env.dart); die Datei selbst wandert nicht ins APK.
    # Sie ist nicht im Repo (sie darf Geheimnisse enthalten), fehlt auf einem
    # frischen Klon also – dann baut das hier ohne das Flag, und es gelten die
    # Standardwerte aus env.dart. Das sind die ausgelieferten, ein fehlendes
    # Flag kann also nur eine Abweichung verschlucken, nichts kaputtmachen.
    $envArgs = @()
    if (Test-Path (Join-Path $appDir 'env\.env')) {
        $envArgs = @('--dart-define-from-file=env/.env')
    }
    else {
        Write-Host 'Hinweis: env\.env fehlt, es gelten die Standardwerte aus lib\env.dart.' -ForegroundColor DarkGray
        Write-Host '         Vorlage: Copy-Item app\env\.env.example app\env\.env' -ForegroundColor DarkGray
    }

    if (-not $SkipPubGet) {
        Invoke-Step 'flutter pub get' $flutter @('pub', 'get')
    }

    if ($Gradle) {
        # Exakt der Weg von Android Studio: Gradle-Task assembleDebug.
        # Das Flutter-Gradle-Plugin haengt sich ein und baut die Dart-Assets mit.
        # Hier gibt es kein --dart-define-from-file: Gradle nimmt die Schalter
        # nicht entgegen, es gelten die Standardwerte aus lib\env.dart. Genau
        # wie beim "Run" aus Android Studio – und genau wie beim Nutzer.
        $gradlew = Join-Path $appDir 'android\gradlew.bat'
        Push-Location (Join-Path $appDir 'android')
        try {
            Invoke-Step 'gradlew assembleDebug' $gradlew @('assembleDebug')
        }
        finally {
            Pop-Location
        }
        # Flutter biegt das Gradle-Build-Verzeichnis auf app\build um,
        # deshalb liegt das APK nicht unter android\app\build\...
        $apk = Join-Path $appDir 'build\app\outputs\apk\debug\app-debug.apk'
    }
    else {
        Invoke-Step 'flutter build apk --debug' $flutter (@('build', 'apk', '--debug') + $envArgs)
        $apk = Join-Path $appDir 'build\app\outputs\flutter-apk\app-debug.apk'
    }

    if (-not (Test-Path $apk)) {
        throw "Build lief durch, aber das APK liegt nicht unter '$apk'."
    }

    $apkFile = Get-Item $apk
    $upToDate = $apkFile.LastWriteTime -lt $startedAt

    $size = [math]::Round($apkFile.Length / 1MB, 1)
    Write-Host ''
    Write-Host "APK fertig: $apk ($size MB)" -ForegroundColor Green
    if ($upToDate) {
        # Inkrementeller Build: nichts hat sich geaendert, das APK ist unveraendert.
        Write-Host "Hinweis: unveraendert seit $($apkFile.LastWriteTime) (Build war up-to-date)." -ForegroundColor DarkGray
    }

    if ($Install) {
        $adb = (Get-Command adb -ErrorAction SilentlyContinue)?.Source
        if (-not $adb) {
            $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
            if (-not (Test-Path $adb)) {
                throw 'adb wurde nicht gefunden – bitte platform-tools in den PATH legen.'
            }
        }

        # Ohne -Device selbst nachsehen, wer dranhaengt. adb bricht bei mehreren
        # Geraeten nur mit "more than one device/emulator" ab und sagt weder,
        # welche das sind, noch wie man eines auswaehlt – und das nach einem
        # fertigen Build, was wie ein Build-Fehler aussieht.
        $target = $Device
        if (-not $target) {
            $attached = @(
                & $adb devices -l |
                    Select-Object -Skip 1 |
                    Where-Object { $_.Trim() -match '^(\S+)\s+(\S+)' } |
                    ForEach-Object {
                        $line = $_.Trim()
                        $null = $line -match '^(\S+)\s+(\S+)'
                        $serial = $Matches[1]
                        $state = $Matches[2]
                        $model = if ($line -match 'model:(\S+)') { $Matches[1] } else { '' }
                        [pscustomobject]@{ Serial = $serial; State = $state; Model = $model }
                    }
            )
            $ready = @($attached | Where-Object { $_.State -eq 'device' })

            if ($ready.Count -eq 0) {
                if ($attached.Count -gt 0) {
                    Write-Host 'Angeschlossen, aber nicht bereit:' -ForegroundColor Yellow
                    foreach ($d in $attached) {
                        Write-Host ("  {0,-24} {1}" -f $d.Serial, $d.State)
                    }
                }
                throw 'Kein installierbares Geraet an adb. Emulator starten oder Telefon per USB-Debugging verbinden.'
            }

            if ($ready.Count -gt 1) {
                Write-Host ''
                Write-Host 'Mehrere Geraete haengen an adb:' -ForegroundColor Yellow
                foreach ($d in $ready) {
                    Write-Host ("  {0,-24} {1}" -f $d.Serial, $d.Model)
                }
                Write-Host ''
                Write-Host 'Das APK ist gebaut, nur das Ziel fehlt. Nochmal mit:' -ForegroundColor DarkGray
                Write-Host ("  .\build-debug-apk.ps1 -Install -SkipPubGet -Device {0}" -f $ready[0].Serial) -ForegroundColor DarkGray
                throw 'Installation abgebrochen: bitte das Geraet mit -Device angeben.'
            }

            $target = $ready[0].Serial
        }

        Invoke-Step "adb -s $target install -r" $adb @('-s', $target, 'install', '-r', $apk)
        Write-Host "Installiert auf $target." -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
