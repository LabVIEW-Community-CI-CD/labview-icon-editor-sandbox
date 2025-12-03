<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with a single allowed Source Distribution command and a hard timeout.

.PARAMETER LabVIEWVersion
  The LabVIEW major version year (e.g., 2021, 2024, 2025). Default: 2025.

.PARAMETER LabVIEWMinor
  The LabVIEW minor version for Q1 (0) or Q3 (3) releases. Default: 3 for Q3.
  Examples: 2025.0 = LabVIEW 2025 Q1, 2025.3 = LabVIEW 2025 Q3

.PARAMETER Bitness
  Target bitness: 32 or 64. Default: 64.
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [int]$CommandTimeoutSec = 60,
    [int]$LabVIEWVersion = 2025,
    [ValidateSet('0', '3')]
    [string]$LabVIEWMinor = '3',
    [ValidateSet('32', '64')]
    [string]$Bitness = '64'
)

$resolvedHost = if ([string]::IsNullOrWhiteSpace($Endpoint)) { "http://localhost:11435" } else { $Endpoint }
if ([string]::IsNullOrWhiteSpace($Model)) { throw "OLLAMA_MODEL_TAG is required. Set the env var or pass -Model." }

$healthParams = @{
    Host            = $resolvedHost
    ModelTag        = $Model
    RequireModelTag = $true
}
& "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams

# Build version string: e.g., "2025" with minor "3" for Q3, or "0" for Q1
Write-Host "[locked-sd] Target: LabVIEW $LabVIEWVersion Q$(if ($LabVIEWMinor -eq '3') { '3' } else { '1' }) ${Bitness}-bit"

$sdCmd = "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version $LabVIEWVersion -SupportedBitness $Bitness"
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

# Explicit exit code for CI/CD
exit $LASTEXITCODE
