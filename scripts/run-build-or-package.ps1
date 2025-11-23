[CmdletBinding()]
param(
    [ValidateSet('vip+lvlibp','vip-single')]
    [string]$BuildMode = 'vip+lvlibp',
    [string]$WorkspacePath,
    [string]$BuildNumber = '1',
    [string]$LabVIEWMinorRevision = '3',
    [string]$CommitHash = 'manual',
    [string]$CompanyName = 'LabVIEW-Community-CI-CD',
    [string]$AuthorName = 'LabVIEW Icon Editor CI',
    [string]$LvlibpBitness = '64'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-PathSafe {
    param([string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
    try { return (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath } catch { return $Path }
}

function Resolve-GitRoot {
    param([string]$BasePath)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return $null }
    if ([string]::IsNullOrWhiteSpace($BasePath)) { $BasePath = (Get-Location).ProviderPath }
    try {
        $root = git -C $BasePath rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)) { return $root.Trim() }
    } catch { $global:LASTEXITCODE = 0 }
    return $null
}

function Resolve-SemverFromLatestTag {
    param([Parameter(Mandatory)][string]$RepoRoot)

    $helper = Join-Path -Path $RepoRoot -ChildPath ".github/actions/compute-version/Get-LastTag.ps1"
    $tag = ''
    if (Test-Path -LiteralPath $helper) {
        $info = & $helper -RequireTag
        $tag = $info.LastTag
    }
    else {
        try {
            $tag = git -C $RepoRoot describe --tags --abbrev=0 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($tag)) {
                $tag = ''
            }
        }
        catch {
            $tag = ''
        }

        if ([string]::IsNullOrWhiteSpace($tag)) {
            throw "No git tags were found. Create the first semantic version tag (for example, v0.1.0) so versioning can derive MAJOR/MINOR/PATCH."
        }
    }

    $tagTrimmed = $tag.Trim()
    $match = [regex]::Match($tagTrimmed, '^(?:refs/tags/)?v?(?<maj>\d+)\.(?<min>\d+)\.(?<pat>\d+)')
    if (-not $match.Success) {
        throw "Latest tag '$tag' is not a semantic version (expected vMAJOR.MINOR.PATCH[...]). Fix or recreate the tag to continue."
    }

    return [PSCustomObject]@{
        Major = [int]$match.Groups['maj'].Value
        Minor = [int]$match.Groups['min'].Value
        Patch = [int]$match.Groups['pat'].Value
        Raw   = $tagTrimmed
    }
}

# Normalize workspace first
$ws = if ([string]::IsNullOrWhiteSpace($WorkspacePath)) { (Get-Location).ProviderPath } else { Resolve-PathSafe $WorkspacePath }

# Resolve repo via git, falling back to workspace
$repo = Resolve-PathSafe $ws
$gitRoot = Resolve-GitRoot -BasePath $ws
if ($gitRoot) { $repo = $gitRoot }

$semver = Resolve-SemverFromLatestTag -RepoRoot $repo
Write-Information ("Using semantic version from latest tag: v{0}.{1}.{2} (raw: {3})" -f $semver.Major, $semver.Minor, $semver.Patch, $semver.Raw) -InformationAction Continue

$buildScript = Join-Path -Path $ws -ChildPath ".github/actions/build/Build.ps1"
$singleScript = Join-Path -Path $ws -ChildPath "scripts/build-vip-single-arch.ps1"
function Assert-DevModePaths {
    param(
        [string]$Repo,
        [string]$Arch,
        [switch]$WarnOnly
    )
    $pathsScript = Join-Path -Path $ws -ChildPath "scripts/read-library-paths.ps1"
    if (-not (Test-Path -LiteralPath $pathsScript)) { return }
    if ($WarnOnly) {
        & $pathsScript -RepositoryPath $Repo -SupportedBitness $Arch
        if ($LASTEXITCODE -ne 0) {
            Write-Warning ("LocalHost.LibraryPaths preflight failed for {0}-bit (non-blocking). Please run 'Revert Dev Mode (LabVIEW)' then 'Set Dev Mode (LabVIEW)' for bitness {0} to refresh the path." -f $Arch)
        }
    }
    else {
        & $pathsScript -RepositoryPath $Repo -SupportedBitness $Arch -FailOnMissing
        if ($LASTEXITCODE -ne 0) {
            $msg = "LocalHost.LibraryPaths preflight failed for $Arch-bit. Please run 'Revert Dev Mode (LabVIEW)' then 'Set Dev Mode (LabVIEW)' for bitness $Arch to refresh the path."
            throw $msg
        }
    }
}

switch ($BuildMode) {
    'vip+lvlibp' {
        # Enforce selected bitness preflight; warn on the other arch
        if ($LvlibpBitness -eq '32') {
            Assert-DevModePaths -Repo $repo -Arch '32'
            Assert-DevModePaths -Repo $repo -Arch '64' -WarnOnly
        } else {
            Assert-DevModePaths -Repo $repo -Arch '64'
            Assert-DevModePaths -Repo $repo -Arch '32' -WarnOnly
        }
        & $buildScript -RepositoryPath $repo -Major $semver.Major -Minor $semver.Minor -Patch $semver.Patch -Build $BuildNumber -LabVIEWMinorRevision $LabVIEWMinorRevision -Commit $CommitHash -CompanyName $CompanyName -AuthorName $AuthorName
    }
    'vip-single' {
        Assert-DevModePaths -Repo $repo -Arch $LvlibpBitness
        & $singleScript -SupportedBitness $LvlibpBitness -RepositoryPath $repo -VIPBPath "Tooling/deployment/NI Icon editor.vipb" -LabVIEWMinorRevision $LabVIEWMinorRevision -Major $semver.Major -Minor $semver.Minor -Patch $semver.Patch -Build $BuildNumber -Commit $CommitHash -ReleaseNotesFile (Join-Path $ws "Tooling/deployment/release_notes.md") -DisplayInformationJSON "{}"
    }
    default { throw "Unknown buildMode '$BuildMode'" }
}
