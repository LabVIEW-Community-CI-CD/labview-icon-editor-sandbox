<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed Source Distribution command and a hard timeout.
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
if ([string]::IsNullOrWhiteSpace($Model)) { throw "OLLAMA_MODEL_TAG is required. Set the env var or pass -Model." }

$healthParams = @{
    Host            = $resolvedHost
    ModelTag        = $Model
    RequireModelTag = $true
}
& "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams

$sdCmd = "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"
$allowedRuns = @($sdCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $sdCmd + '"} and then {"done":true}.'

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
