param(
    [Parameter(Mandatory=$true)][string]$CliName,
    [Parameter(Mandatory=$true)][string]$RepoRoot,
    [Parameter(Mandatory=$false)][string[]]$Args = @()
)
$ErrorActionPreference = 'Stop'

$repo = Resolve-Path -LiteralPath $RepoRoot
$probeHelper = Join-Path $repo 'scripts/common/resolve-repo-cli.ps1'

# Resolve the CLI via helper (returns provenance object with Command array)
if (-not (Test-Path -LiteralPath $probeHelper -PathType Leaf)) {
    throw "Probe helper not found at $probeHelper"
}
$provOutput = & $probeHelper -CliName $CliName -RepoPath $repo 2>$null
$prov = $provOutput | Where-Object { $_ -is [psobject] -and $_.PSObject.Properties['Command'] } | Select-Object -Last 1
if (-not $prov) {
    throw "Unable to resolve CLI $CliName via $probeHelper (no provenance returned)"
}

# The helper returns a PSCustomObject; pull the Command array
$cmd = @()
if ($prov.PSObject.Properties['Command'] -and $prov.Command) {
    $cmd = @($prov.Command)
} elseif ($prov.PSObject.Properties['BinaryPath'] -and $prov.BinaryPath) {
    $cmd = @($prov.BinaryPath)
}
if (-not $cmd -or $cmd.Count -eq 0) {
    throw "Unable to resolve CLI $CliName command from $probeHelper (missing Command/BinaryPath)"
}

# Append caller-supplied arguments
$exec = $cmd[0]
$rest = if ($cmd.Count -gt 1) { $cmd[1..($cmd.Count-1)] } else { @() }
$rest += $Args

& $exec @rest
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
