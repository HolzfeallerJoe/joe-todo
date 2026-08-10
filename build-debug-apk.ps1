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
    Geraete verbunden sind).

.PARAMETER Gradle
    Baut ueber android\gradlew assembleDebug statt ueber die Flutter-CLI.

.PARAMETER SkipPubGet
    Ueberspringt `flutter pub get`.

.EXAMPLE
    .\build-debug-apk.ps1

.EXAMPLE
    .\build-debug-apk.ps1 -Install

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

    if (-not $SkipPubGet) {
        Invoke-Step 'flutter pub get' $flutter @('pub', 'get')
    }

    if ($Gradle) {
        # Exakt der Weg von Android Studio: Gradle-Task assembleDebug.
        # Das Flutter-Gradle-Plugin haengt sich ein und baut die Dart-Assets mit.
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
        Invoke-Step 'flutter build apk --debug' $flutter @('build', 'apk', '--debug')
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
        $adbArgs = @()
        if ($Device) { $adbArgs += @('-s', $Device) }
        $adbArgs += @('install', '-r', $apk)

        $adb = (Get-Command adb -ErrorAction SilentlyContinue)?.Source
        if (-not $adb) {
            $adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
            if (-not (Test-Path $adb)) {
                throw 'adb wurde nicht gefunden – bitte platform-tools in den PATH legen.'
            }
        }
        Invoke-Step 'adb install -r' $adb $adbArgs
        Write-Host 'Installiert.' -ForegroundColor Green
    }
}
finally {
    Pop-Location
}
