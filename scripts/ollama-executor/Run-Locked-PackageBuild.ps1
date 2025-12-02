<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed package-build command and a hard timeout.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [string]$Model = "llama3-8b-local",
    [int]$CommandTimeoutSec = 60
)

$pkgCmd = 'pwsh -NoProfile -File scripts/common/invoke-repo-cli.ps1 -Cli OrchestrationCli -- package-build --repo . --bitness 64 --lvlibp-bitness both --major 0 --minor 1 --patch 0 --build 1 --company LabVIEW-Community-CI-CD --author "Local Developer"'
$allowedRuns = @($pkgCmd)
$goal = "Respond ONLY with JSON: send exactly {\"run\":\"$pkgCmd\"} and then {\"done\":true}."

$params = @{
    Model                 = $Model
    RepoPath              = $RepoPath
    Goal                  = $goal
    MaxTurns              = 2
    StopAfterFirstCommand = $true
    AllowedRuns           = $allowedRuns
    CommandTimeoutSec     = $CommandTimeoutSec
}

& "$PSScriptRoot/Drive-Ollama-Executor.ps1" @params -Verbose
