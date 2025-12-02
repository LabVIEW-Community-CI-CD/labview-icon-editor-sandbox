<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed Source Distribution command and a hard timeout.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [string]$Model = "llama3-8b-local",
    [int]$CommandTimeoutSec = 60
)

$sdCmd = "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"
$allowedRuns = @($sdCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $sdCmd + '"} and then {"done":true}.'

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
