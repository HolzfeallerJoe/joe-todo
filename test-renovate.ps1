# Ausschliesslich lokale Pruefungen, keine GitHub-Schreibzugriffe.
[CmdletBinding()]
param(
    [ValidateSet('validate', 'extract', 'lookup')]
    [string]$Mode = 'validate'
)

$ErrorActionPreference = 'Stop'
$renovatePackage = 'renovate@44.226.2'
$npxCommand = if ($env:OS -eq 'Windows_NT') { 'npx.cmd' } else { 'npx' }

Push-Location $PSScriptRoot
try {
    if ($Mode -eq 'validate') {
        & $npxCommand --yes --package $renovatePackage -- renovate-config-validator --strict --no-global renovate.json
    }
    else {
        # Die lokale Plattform unterstuetzt extract und lookup, kein full.
        & $npxCommand --yes --package $renovatePackage -- renovate --platform=local "--dry-run=$Mode"
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Renovate ($Mode) ist mit Exitcode $LASTEXITCODE fehlgeschlagen."
    }
}
finally {
    Pop-Location
}
