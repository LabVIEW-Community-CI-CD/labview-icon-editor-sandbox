<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed local-sd-ppl orchestration command and a hard timeout.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [int]$CommandTimeoutSec = 60
)

. "$PSScriptRoot/Resolve-OllamaHost.ps1"

$resolvedHost = Resolve-OllamaHost -RequestedHost $Endpoint
if ([string]::IsNullOrWhiteSpace($Endpoint)) {
    Write-Host "[locked-local-sd-ppl] Auto-selected OLLAMA_HOST=$resolvedHost"
}
elseif ($resolvedHost -ne $Endpoint) {
    Write-Warning "Requested OLLAMA_HOST '$Endpoint' was unreachable; fell back to '$resolvedHost'."
}
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

$pplCmd = "pwsh -NoProfile -File scripts/orchestration/Run-LocalSd-Ppl.ps1 -Repo . -RunKey local-sd-ppl"
$allowedRuns = @($pplCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $pplCmd + '"} and then {"done":true}.'

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
