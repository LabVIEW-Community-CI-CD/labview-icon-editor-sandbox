<#
.SYNOPSIS
    Builds the Editor Packed Library (.lvlibp) using g-cli.

.DESCRIPTION
    Invokes the LabVIEW build specification "Editor Packed Library" through
    g-cli, embedding the provided version information and commit identifier.

.PARAMETER Package_LabVIEW_Version
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
    .\Build_lvlibp.ps1 -Package_LabVIEW_Version "2021" -SupportedBitness "64" -RepositoryPath "C:\labview-icon-editor" -Major 1 -Minor 0 -Patch 0 -Build 0 -Commit "Placeholder"
#>
param(
    [Alias('MinimumSupportedLVVersion')][string]$Package_LabVIEW_Version,
    [string]$SupportedBitness,
    [string]$RepositoryPath,
    [Int32]$Major,
    [Int32]$Minor,
    [Int32]$Patch,
    [Int32]$Build,
    [string]$Commit
)

    # Resolve version from VIPB for determinism
$versionScript = @(
    (Join-Path $PSScriptRoot '..\..\scripts\get-package-lv-version.ps1'),
    (Join-Path $PSScriptRoot '..\..\..\scripts\get-package-lv-version.ps1') # fallback if invoked from a different working dir
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $versionScript) {
    throw "Unable to locate get-package-lv-version.ps1 relative to $PSScriptRoot"
}

$Package_LabVIEW_Version = & $versionScript -RepositoryPath $RepositoryPath

# Derive build number from total commit count for PPL versioning; fall back to provided value
$DerivedBuild = $Build
try {
    git -C $RepositoryPath fetch --unshallow 2>$null | Out-Null
}
catch {
    $global:LASTEXITCODE = 0
}
try {
    $commitCount = git -C $RepositoryPath rev-list --count HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $commitCount) {
        $DerivedBuild = [int]$commitCount
        Write-Information ("Using commit count for PPL build number: {0}" -f $DerivedBuild) -InformationAction Continue
    }
    else {
        Write-Information ("Falling back to provided build number: {0}" -f $Build) -InformationAction Continue
    }
}
catch {
    Write-Information ("Falling back to provided build number: {0} (commit count unavailable)" -f $Build) -InformationAction Continue
    $global:LASTEXITCODE = 0
}
$Build = $DerivedBuild
Write-Output "PPL Version: $Major.$Minor.$Patch.$Build"
Write-Output "Commit: $Commit"

$buildArgs = @(
"--lv-ver", $Package_LabVIEW_Version,
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
g-cli --lv-ver $Package_LabVIEW_Version --arch $SupportedBitness QuitLabVIEW
    exit 1
}

Write-Information "Build succeeded." -InformationAction Continue
exit 0

