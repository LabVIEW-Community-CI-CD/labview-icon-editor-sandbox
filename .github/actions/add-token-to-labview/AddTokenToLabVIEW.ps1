<#
.SYNOPSIS
    Adds a custom library path token to the LabVIEW INI file.

.DESCRIPTION
    Uses g-cli to call Create_LV_INI_Token.vi, inserting the provided path into
    the LabVIEW INI file under the Localhost.LibraryPaths token. This enables
    LabVIEW to locate local project libraries during development or builds.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW version used by g-cli (e.g., "2021").

.PARAMETER SupportedBitness
    Target bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root that should be added to the INI token.

.EXAMPLE
    .\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor"
#>

param(
    [Parameter(Mandatory)][Alias('Package_LabVIEW_Version')][string]$MinimumSupportedLVVersion,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$SupportedBitness,
    [Parameter(Mandatory)][string]$RepositoryPath
)

$ErrorActionPreference = 'Stop'
$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
$iniTokenVi = Join-Path -Path $RepositoryPath -ChildPath 'Tooling\deployment\Create_LV_INI_Token.vi'
if (-not (Test-Path -LiteralPath $iniTokenVi)) {
    throw "Missing VI required to add INI token: $iniTokenVi"
}

# Determine target folder for Localhost.LibraryPaths (folder that contains the project)
$project = Get-ChildItem -Path $RepositoryPath -Filter *.lvproj -File -Recurse | Select-Object -First 1
$tokenTarget = if ($project) {
    Split-Path -Parent $project.FullName
} else {
    $RepositoryPath
}

$_gcliArgs = @(
    '--lv-ver', $MinimumSupportedLVVersion,
    '--arch', $SupportedBitness,
    '--',
    $iniTokenVi,
    '--',
    'LabVIEW',
    'Localhost.LibraryPaths',
    $SupportedBitness,
    $tokenTarget
)

Write-Information ("Invoking g-cli: {0}" -f ($_gcliArgs -join ' ')) -InformationAction Continue
Write-Information ("Localhost.LibraryPaths target: {0}" -f $tokenTarget) -InformationAction Continue

$gcli = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcli) {
    throw "g-cli is not available on PATH; cannot add INI token."
}

$output = & g-cli @_gcliArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    $joined = ($output -join '; ')
    throw ("g-cli failed with exit code {0}: {1} | cmd: {2}" -f $LASTEXITCODE, $joined, ($_gcliArgs -join ' '))
}

Write-Information "Created localhost.library path in ini file." -InformationAction Continue
