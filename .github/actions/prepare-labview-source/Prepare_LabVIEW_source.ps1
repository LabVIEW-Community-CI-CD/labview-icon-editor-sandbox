<#
.SYNOPSIS
    Prepares LabVIEW source code for building.

.DESCRIPTION
    Executes the PrepareIESource.vi via g-cli to unzip required components and
    update the LabVIEW configuration, ensuring the project is ready for
    subsequent build steps.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW version used by g-cli.

.PARAMETER SupportedBitness
    Target bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RelativePath
    Path to the repository root containing the project.

.PARAMETER LabVIEW_Project
    Name of the LabVIEW project (without extension).

.PARAMETER Build_Spec
    Name of the build specification to prepare.

.EXAMPLE
    .\Prepare_LabVIEW_source.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview icon editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$MinimumSupportedLVVersion,

    [Parameter(Mandatory = $true)]
    [ValidateSet("32", "64", IgnoreCase = $true)]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RelativePath,

    [Parameter(Mandatory = $true)]
    [string]$LabVIEW_Project,

    [Parameter(Mandatory = $true)]
    [string]$Build_Spec
)

$ErrorActionPreference = 'Stop'

$args = @(
    '--lv-ver', $MinimumSupportedLVVersion,
    '--arch', $SupportedBitness,
    '-v', "$RelativePath\Tooling\PrepareIESource.vi",
    '--',
    'LabVIEW',
    'Localhost.LibraryPaths',
    "$RelativePath\$LabVIEW_Project.lvproj",
    $Build_Spec
)

Write-Information ("Executing g-cli: {0}" -f ($args -join ' ')) -InformationAction Continue
& g-cli @args

if ($LASTEXITCODE -eq 0) {
    Write-Information "Success: Process completed. Unzipped vi.lib/LabVIEW Icon API and updated INI." -InformationAction Continue
    exit 0
}

Write-Error "Command execution failed with exit code $LASTEXITCODE."
exit $LASTEXITCODE

