[CmdletBinding()]
param(
    [ValidateSet('vip+lvlibp','vip-single')]
    [string]$BuildMode = 'vip+lvlibp',
    [string]$WorkspacePath,
    [string]$SemverMajor = '0',
    [string]$SemverMinor = '1',
    [string]$SemverPatch = '0',
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

# Normalize workspace first
$ws = if ([string]::IsNullOrWhiteSpace($WorkspacePath)) { (Get-Location).ProviderPath } else { Resolve-PathSafe $WorkspacePath }

# Resolve repo via git, falling back to workspace
$repo = Resolve-PathSafe $ws
$gitRoot = Resolve-GitRoot -BasePath $ws
if ($gitRoot) { $repo = $gitRoot }

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
        & $buildScript -RepositoryPath $repo -Major $SemverMajor -Minor $SemverMinor -Patch $SemverPatch -Build $BuildNumber -LabVIEWMinorRevision $LabVIEWMinorRevision -Commit $CommitHash -CompanyName $CompanyName -AuthorName $AuthorName
    }
    'vip-single' {
        Assert-DevModePaths -Repo $repo -Arch $LvlibpBitness
        & $singleScript -SupportedBitness $LvlibpBitness -RepositoryPath $repo -VIPBPath "Tooling/deployment/NI Icon editor.vipb" -LabVIEWMinorRevision $LabVIEWMinorRevision -Major $SemverMajor -Minor $SemverMinor -Patch $SemverPatch -Build $BuildNumber -Commit $CommitHash -ReleaseNotesFile (Join-Path $ws "Tooling/deployment/release_notes.md") -DisplayInformationJSON "{}"
    }
    default { throw "Unknown buildMode '$BuildMode'" }
}
