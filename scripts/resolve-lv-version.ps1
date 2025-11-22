#Requires -Version 7.0
param(
    [Parameter(Mandatory)][string]$RepositoryPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path $RepositoryPath).Path
$candidates = @(
    Join-Path $repo 'scripts/get-package-lv-version.ps1'
    Join-Path $repo '.github/scripts/get-package-lv-version.ps1'
)

$lvScript = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $lvScript) {
    throw "Unable to locate get-package-lv-version.ps1 under '$repo/scripts' or '$repo/.github/scripts'."
}

$lvVer = pwsh -NoProfile -File $lvScript -RepositoryPath $repo
if ([string]::IsNullOrWhiteSpace($lvVer)) {
    throw "Failed to resolve LabVIEW version from VIPB."
}

Write-Output $lvVer
