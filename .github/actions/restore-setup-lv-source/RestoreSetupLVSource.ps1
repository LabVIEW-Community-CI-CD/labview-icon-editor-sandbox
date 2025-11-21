<#
.SYNOPSIS
    Restores the LabVIEW source setup from a packaged state.

.DESCRIPTION
    Calls RestoreSetupLVSource.vi via g-cli to unzip the LabVIEW Icon API and
    remove the Localhost.LibraryPaths token from the LabVIEW INI file.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW version used to run g-cli.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RelativePath
    Path to the repository root.

.PARAMETER LabVIEW_Project
    Name of the LabVIEW project (without extension).

.PARAMETER Build_Spec
    Build specification name within the project.

.EXAMPLE
    .\RestoreSetupLVSource.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RelativePath "C:\labview-icon-editor" -LabVIEW_Project "lv_icon_editor" -Build_Spec "Editor Packed Library"
#>
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RelativePath,
    [string]$LabVIEW_Project,
    [string]$Build_Spec
)

$ErrorActionPreference = 'Stop'

$args = @(
    '--lv-ver', $MinimumSupportedLVVersion,
    '--arch', $SupportedBitness,
    '-v', "$RelativePath\Tooling\RestoreSetupLVSource.vi",
    '--',
    "$RelativePath\$LabVIEW_Project.lvproj",
    "$Build_Spec"
)

Write-Information ("Executing g-cli: {0}" -f ($args -join ' ')) -InformationAction Continue
& g-cli @args

if ($LASTEXITCODE -eq 0) {
    Write-Information "Unzipped vi.lib/LabVIEW Icon API and removed localhost.library path from ini file." -InformationAction Continue
    exit 0
}

Write-Warning "g-cli exited with $LASTEXITCODE during restore."
exit $LASTEXITCODE
