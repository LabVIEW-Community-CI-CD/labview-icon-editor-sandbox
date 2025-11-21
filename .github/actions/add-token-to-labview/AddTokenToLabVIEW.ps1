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

.PARAMETER RelativePath
    Path to the repository root that should be added to the INI token.

.EXAMPLE
    .\AddTokenToLabVIEW.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor"
#>

param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath
)

$ErrorActionPreference = 'Stop'

$args = @(
    '--lv-ver', $MinimumSupportedLVVersion,
    '--arch', $SupportedBitness,
    '-v', "$RelativePath\Tooling\deployment\Create_LV_INI_Token.vi",
    '--',
    'LabVIEW',
    'Localhost.LibraryPaths',
    $RelativePath
)

Write-Information ("Invoking g-cli: {0}" -f ($args -join ' ')) -InformationAction Continue
& g-cli @args

if ($LASTEXITCODE -eq 0) {
    Write-Information "Created localhost.library path in ini file." -InformationAction Continue
} else {
    Write-Warning "g-cli exited with $LASTEXITCODE while adding INI token."
}
