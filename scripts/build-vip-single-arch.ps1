<#
.SYNOPSIS
Build a single-architecture VIP by pruning the other architecture's lvlibp from the VIPB and then invoking build_vip.ps1.

.DESCRIPTION
Creates a temporary copy of the VIPB with the non-target lvlibp entries removed (Additional_Files and Destination_Overrides) so that packaging succeeds when only one lvlibp is present. The original VIPB is left untouched.

.PARAMETER SupportedBitness
Target bitness for the VIP (32 or 64). The other bitness is removed from the VIPB copy.

.PARAMETER RepositoryPath
Path to the repository root.

.PARAMETER VIPBPath
Relative path to the source VIPB. Defaults to the main project VIPB.

.PARAMETER OutputVIPBPath
Where to write the pruned VIPB. Defaults to builds/tmp/NI Icon editor.<bitness>.vipb under the repo.

.PARAMETER LabVIEWMinorRevision
LabVIEW minor revision (0 or 3) forwarded to build_vip.ps1.

.PARAMETER Major/Minor/Patch/Build/Commit/ReleaseNotesFile/DisplayInformationJSON
Passed through to build_vip.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("32", "64")]
    [string]$SupportedBitness,

    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$VIPBPath = "Tooling/deployment/NI Icon editor.vipb",
    [string]$OutputVIPBPath,

    [int]$LabVIEWMinorRevision = 3,

    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 0,
    [string]$Commit = "manual",
    [string]$ReleaseNotesFile = "Tooling/deployment/release_notes.md",
    [string]$DisplayInformationJSON = "{}"
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RepoPath {
    param([string]$Path)
    try {
        return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath
    }
    catch {
        throw "RepositoryPath does not exist: $Path"
    }
}

$repoRoot = Resolve-RepoPath -Path $RepositoryPath
$sourceVIPB = if ([System.IO.Path]::IsPathRooted($VIPBPath)) {
    $VIPBPath
} else {
    Join-Path -Path $repoRoot -ChildPath $VIPBPath
}
if (-not (Test-Path -LiteralPath $sourceVIPB)) {
    throw "VIPBPath not found: $sourceVIPB"
}

# Default output path under builds/tmp with an arch suffix
if (-not $OutputVIPBPath) {
    $OutputVIPBPath = Join-Path -Path $repoRoot -ChildPath ("builds/tmp/NI Icon editor.{0}.vipb" -f $SupportedBitness)
} elseif (-not [System.IO.Path]::IsPathRooted($OutputVIPBPath)) {
    $OutputVIPBPath = Join-Path -Path $repoRoot -ChildPath $OutputVIPBPath
}

[xml]$vipb = Get-Content -LiteralPath $sourceVIPB -Raw
$otherToken = if ($SupportedBitness -eq "64") { "resource/plugins/lv_icon_x86.lvlibp" } else { "resource/plugins/lv_icon_x64.lvlibp" }

# Remove the other arch's lvlibp entries
$fileNodes = $vipb.SelectNodes("//File[Path[contains(., '$otherToken')]]")
foreach ($node in @($fileNodes)) {
    [void]$node.ParentNode.RemoveChild($node)
}

$destNodes = $vipb.SelectNodes("//Destination_Overrides[Path[contains(., '$otherToken')]]")
foreach ($node in @($destNodes)) {
    [void]$node.ParentNode.RemoveChild($node)
}

# Add an exclusion for the removed arch to avoid missing-file packaging errors
$sourceFilesNode = $vipb.VI_Package_Builder_Settings.Advanced_Settings.Source_Files
if ($sourceFilesNode -and -not $vipb.SelectSingleNode("//Exclusions[Path='$otherToken']")) {
    $exclusion = $vipb.CreateElement("Exclusions")
    $pathNode = $vipb.CreateElement("Path")
    $pathNode.InnerText = $otherToken
    [void]$exclusion.AppendChild($pathNode)
    [void]$sourceFilesNode.AppendChild($exclusion)
}

$outDir = Split-Path -Parent $OutputVIPBPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$vipb.Save($OutputVIPBPath)

# Build using the pruned VIPB copy
$versionScript = Join-Path -Path $repoRoot -ChildPath "scripts/get-package-lv-version.ps1"
if (-not (Test-Path -LiteralPath $versionScript)) {
    throw "get-package-lv-version.ps1 not found at $versionScript"
}
$packageVersion = & $versionScript -RepositoryPath $repoRoot

$buildVipScript = Join-Path -Path $repoRoot -ChildPath ".github/actions/build-vip/build_vip.ps1"
if (-not (Test-Path -LiteralPath $buildVipScript)) {
    throw "build_vip.ps1 not found at $buildVipScript"
}

$releaseNotesPath = if ([System.IO.Path]::IsPathRooted($ReleaseNotesFile)) {
    $ReleaseNotesFile
} else {
    Join-Path -Path $repoRoot -ChildPath $ReleaseNotesFile
}

$buildParams = @{
    SupportedBitness        = $SupportedBitness
    RepositoryPath          = $repoRoot
    VIPBPath                = $OutputVIPBPath
    Package_LabVIEW_Version = $packageVersion
    LabVIEWMinorRevision    = $LabVIEWMinorRevision
    Major                   = $Major
    Minor                   = $Minor
    Patch                   = $Patch
    Build                   = $Build
    Commit                  = $Commit
    ReleaseNotesFile        = $releaseNotesPath
    DisplayInformationJSON  = $DisplayInformationJSON
}

& $buildVipScript @buildParams
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
