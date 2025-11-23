[CmdletBinding()]
param(
    [ValidateSet('vip+lvlibp','vip-single')]
    [string]$BuildMode = 'vip+lvlibp',
    [string]$RepositoryPath,
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

$repo = if ([string]::IsNullOrWhiteSpace($RepositoryPath)) { $WorkspacePath } else { $RepositoryPath }
if ([string]::IsNullOrWhiteSpace($repo)) { $repo = (Get-Location).ProviderPath }
$ws = if ([string]::IsNullOrWhiteSpace($WorkspacePath)) { $repo } else { $WorkspacePath }

$buildScript = Join-Path -Path $ws -ChildPath ".github/actions/build/Build.ps1"
$singleScript = Join-Path -Path $ws -ChildPath "scripts/build-vip-single-arch.ps1"

switch ($BuildMode) {
    'vip+lvlibp' {
        & $buildScript -RepositoryPath $repo -Major $SemverMajor -Minor $SemverMinor -Patch $SemverPatch -Build $BuildNumber -LabVIEWMinorRevision $LabVIEWMinorRevision -Commit $CommitHash -CompanyName $CompanyName -AuthorName $AuthorName
    }
    'vip-single' {
        & $singleScript -SupportedBitness $LvlibpBitness -RepositoryPath $repo -VIPBPath "Tooling/deployment/NI Icon editor.vipb" -LabVIEWMinorRevision $LabVIEWMinorRevision -Major $SemverMajor -Minor $SemverMinor -Patch $SemverPatch -Build $BuildNumber -Commit $CommitHash -ReleaseNotesFile (Join-Path $ws "Tooling/deployment/release_notes.md") -DisplayInformationJSON "{}"
    }
    default { throw "Unknown buildMode '$BuildMode'" }
}
