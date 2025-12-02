<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed local-sd-ppl orchestration command and a hard timeout.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [string]$Model = "llama3-8b-local",
    [int]$CommandTimeoutSec = 60,
    [int]$PwshTimeoutSec = 7200
)

$pplCmd = "pwsh -NoProfile -File scripts/orchestration/Run-LocalSd-Ppl.ps1 -Repo . -RunKey local-sd-ppl -PwshTimeoutSec $PwshTimeoutSec"
$allowedRuns = @($pplCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $pplCmd + '"} and then {"done":true}.'

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
