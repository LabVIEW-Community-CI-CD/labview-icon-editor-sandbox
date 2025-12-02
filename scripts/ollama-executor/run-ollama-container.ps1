[CmdletBinding()]
param(
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-latest"
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = "svelderrainruiz" }
if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "cpu-latest" }
$ownerLc = $Owner.Trim().ToLowerInvariant()
$tagTrim = $Tag.Trim()
$ref = "ghcr.io/$ownerLc/ollama-local:$tagTrim"

$existing = docker ps -aq -f name=^ollama-local$
if ($existing) {
    Write-Host "Removing existing ollama-local container"
    docker rm -f $existing | Out-Null
}

Write-Host "Starting $ref on localhost:11435"
docker run -d --name ollama-local -p 11435:11435 -e OLLAMA_HOST=0.0.0.0:11435 -v ollama:/root/.ollama $ref serve
