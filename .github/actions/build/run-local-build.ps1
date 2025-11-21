# Wrapper to execute Build.ps1 with sane defaults for local/headless runs
[CmdletBinding()]
param(
    [Alias('RelativePath')]
    [string]$RepositoryPath = $PWD,
    [int]$Major = 0,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 1,
    [string]$CompanyName = "LabVIEW-Community-CI-CD",
    [string]$AuthorName = "LabVIEW Icon Editor CI",
    [string]$Commit
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
    throw "RepositoryPath is required."
}

# Resolve commit hash (fallback to 'manual' if git is unavailable)
if ([string]::IsNullOrWhiteSpace($Commit)) {
    try {
        $Commit = git -C $RepositoryPath rev-parse HEAD
    }
    catch {
        $Commit = 'manual'
    }
}

$buildScript = Join-Path -Path $PSScriptRoot -ChildPath 'Build.ps1'

& $buildScript `
    -RepositoryPath $RepositoryPath `
    -Major $Major `
    -Minor $Minor `
    -Patch $Patch `
    -Build $Build `
    -Commit $Commit `
    -CompanyName $CompanyName `
    -AuthorName $AuthorName
