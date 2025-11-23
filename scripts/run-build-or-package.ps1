[CmdletBinding()]
param(
    [ValidateSet('vip+lvlibp','vip-single')]
    [string]$BuildMode = 'vip+lvlibp',
    [string]$WorkspacePath,
    [string]$LabVIEWMinorRevision = '3',
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

function Resolve-CommitHash {
    param([Parameter(Mandatory)][string]$RepoRoot)
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { return "manual" }
    try {
        $hash = git -C $RepoRoot rev-parse HEAD 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($hash)) {
            return $hash.Trim()
        }
    } catch {
        $global:LASTEXITCODE = 0
    }
    return "manual"
}

function Resolve-BuildNumber {
    param(
        [Parameter(Mandatory)][string]$RepoRoot
    )

    try { git -C $RepoRoot fetch --unshallow 2>$null | Out-Null } catch { $global:LASTEXITCODE = 0 }
    $count = ''
    try {
        $count = git -C $RepoRoot rev-list --count HEAD 2>$null
    }
    catch {
        $global:LASTEXITCODE = 0
        $count = ''
    }
    if ([string]::IsNullOrWhiteSpace($count)) {
        throw "Unable to compute build number from commits in the repository. Ensure git history is available (fetch-depth 0)."
    }

    return [int]$count
}

# Normalize workspace first
$ws = if ([string]::IsNullOrWhiteSpace($WorkspacePath)) { (Get-Location).ProviderPath } else { Resolve-PathSafe $WorkspacePath }

# Resolve repo via git, falling back to workspace
$repo = Resolve-PathSafe $ws
$gitRoot = Resolve-GitRoot -BasePath $ws
if ($gitRoot) { $repo = $gitRoot }

$semver = Resolve-SemverFromLatestTag -RepoRoot $repo
Write-Information ("Using semantic version from latest tag: v{0}.{1}.{2} (raw: {3})" -f $semver.Major, $semver.Minor, $semver.Patch, $semver.Raw) -InformationAction Continue

$buildNumber = Resolve-BuildNumber -RepoRoot $repo
Write-Information ("Build number = commits from repository root: {0}" -f $buildNumber) -InformationAction Continue

$commitHash = Resolve-CommitHash -RepoRoot $repo
Write-Information ("Using commit hash: {0}" -f $commitHash) -InformationAction Continue

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
        if ($LvlibpBitness -eq '32') {
            throw "buildMode 'vip+lvlibp' packages a 64-bit VIP and requires LabVIEW 64-bit. If you only have LabVIEW 32-bit installed, rerun with buildMode 'vip-single' and LvlibpBitness=32."
        }
        # Enforce selected bitness preflight; warn on the other arch
        Assert-DevModePaths -Repo $repo -Arch '64'
        & $buildScript -RepositoryPath $repo -Major $semver.Major -Minor $semver.Minor -Patch $semver.Patch -Build $buildNumber -LabVIEWMinorRevision $LabVIEWMinorRevision -Commit $commitHash -CompanyName $CompanyName -AuthorName $AuthorName -LvlibpBitness $LvlibpBitness
    }
    'vip-single' {
        Assert-DevModePaths -Repo $repo -Arch $LvlibpBitness
        & $singleScript -SupportedBitness $LvlibpBitness -RepositoryPath $repo -VIPBPath "Tooling/deployment/NI Icon editor.vipb" -LabVIEWMinorRevision $LabVIEWMinorRevision -Major $semver.Major -Minor $semver.Minor -Patch $semver.Patch -Build $buildNumber -Commit $commitHash -ReleaseNotesFile (Join-Path $ws "Tooling/deployment/release_notes.md") -DisplayInformationJSON "{}"
    }
    default { throw "Unknown buildMode '$BuildMode'" }
}
