param(
    [Parameter(Mandatory=$true)][string]$CliName,
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$false)][string[]]$Args = @()
)
$ErrorActionPreference = 'Stop'

$repo = Resolve-Path -LiteralPath $RepoRoot
$probeHelper = Join-Path $repo 'scripts/common/resolve-repo-cli.ps1'

# Resolve the CLI path via helper
if (-not (Test-Path -LiteralPath $probeHelper -PathType Leaf)) {
    throw "Probe helper not found at $probeHelper"
}
$cliPath = & pwsh -NoProfile -File $probeHelper -CliName $CliName -RepoRoot $repo 2>$null
if (-not $cliPath -or -not (Test-Path -LiteralPath $cliPath)) {
    throw "Unable to resolve CLI path for $CliName via $probeHelper"
}

# If a DLL is resolved (published), run directly; otherwise dotnet run the project
if ($cliPath -like '*.dll') {
    & $cliPath @Args
} elseif ($cliPath -like '*.csproj') {
    dotnet run --project $cliPath -- @Args
} else {
    & $cliPath @Args
}
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
