<#
.SYNOPSIS
    Builds the Editor Packed Library (.lvlibp) using g-cli.

.DESCRIPTION
    Invokes the LabVIEW build specification "Editor Packed Library" through
    g-cli, embedding the provided version information and commit identifier.

.PARAMETER MinimumSupportedLVVersion
    LabVIEW version used for the build.

.PARAMETER SupportedBitness
    Bitness of the LabVIEW environment ("32" or "64").

.PARAMETER RepositoryPath
    Path to the repository root where the project file resides.

.PARAMETER Major
    Major version component for the PPL.

.PARAMETER Minor
    Minor version component for the PPL.

.PARAMETER Patch
    Patch version component for the PPL.

.PARAMETER Build
    Build number component for the PPL.

.PARAMETER Commit
    Commit hash or identifier recorded in the build.

.EXAMPLE
    .\Build_lvlibp.ps1 -MinimumSupportedLVVersion "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor" -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder"
#>
param(
    [string]$MinimumSupportedLVVersion,
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit
)

Write-Output "PPL Version: $Major.$Minor.$Patch.$Build"
Write-Output "Commit: $Commit"

$buildArgs = @(
    "--lv-ver", $MinimumSupportedLVVersion,
    "--arch", $SupportedBitness,
    "lvbuildspec",
    "--",
    "-v", "$Major.$Minor.$Patch.$Build",
    "-p", "$RepositoryPath\lv_icon_editor.lvproj",
    "-b", "Editor Packed Library"
)
Write-Information ("Executing: g-cli {0}" -f ($buildArgs -join ' ')) -InformationAction Continue

$output = & g-cli @buildArgs 2>&1

if ($LASTEXITCODE -ne 0) {
    $joined = ($output -join '; ')
    Write-Error "Build failed with exit code $LASTEXITCODE. Output: $joined"
    g-cli --lv-ver $MinimumSupportedLVVersion --arch $SupportedBitness QuitLabVIEW
    exit 1
}

Write-Information "Build succeeded." -InformationAction Continue
exit 0

