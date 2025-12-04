<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed package-build command and a hard timeout.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [int]$CommandTimeoutSec = 60
)

$resolvedHost = if ([string]::IsNullOrWhiteSpace($Endpoint)) { "http://localhost:11435" } else { $Endpoint }
if ([string]::IsNullOrWhiteSpace($Model)) {
    $Model = "llama3-8b-local:latest"
    Write-Warning "OLLAMA_MODEL_TAG missing; defaulting to '$Model'. Override with -Model or set the env var."
}

$healthParams = @{
    Host            = $resolvedHost
    ModelTag        = $Model
    RequireModelTag = $true
}
& "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams

$pkgCmd = 'pwsh -NoProfile -File scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- package-build --repo . --bitness 64 --lvlibp-bitness both --major 0 --minor 1 --patch 0 --build 1 --company LabVIEW-Community-CI-CD --author "Local Developer"'
$allowedRuns = @($pkgCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $pkgCmd + '"} and then {"done":true}.'

$params = @{
    Host                 = $resolvedHost
    Model                 = $Model
    RepoPath              = $RepoPath
    Goal                  = $goal
    MaxTurns              = 2
    StopAfterFirstCommand = $true
    AllowedRuns           = $allowedRuns
    CommandTimeoutSec     = $CommandTimeoutSec
}

& "$PSScriptRoot/Drive-Ollama-Executor.ps1" @params -Verbose

# Explicit exit code for CI/CD
exit $LASTEXITCODE
