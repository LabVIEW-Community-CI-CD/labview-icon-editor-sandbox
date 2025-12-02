[CmdletBinding()]
param(
    [string]$Host = $env:OLLAMA_HOST,
    [string]$ModelTag = $env:OLLAMA_MODEL_TAG
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Host)) { $Host = "http://localhost:11435" }
if ([string]::IsNullOrWhiteSpace($ModelTag)) { $ModelTag = "llama3-8b-local" }

$uri = "$($Host.TrimEnd('/'))/api/tags"
Write-Host "Checking Ollama endpoint at $uri for model '$ModelTag'"

try {
    $response = Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 10
}
catch {
    throw "Failed to reach Ollama at $uri. Ensure the container is running and OLLAMA_HOST is set. $_"
}

if (-not $response -or -not $response.models) {
    throw "Endpoint reachable but returned no models from $uri"
}

$found = $response.models | Where-Object { $_.name -eq $ModelTag }
if (-not $found) {
    $available = ($response.models.name) -join ', '
    throw "Model '$ModelTag' not found. Available: $available"
}

Write-Host "OK: Model '$ModelTag' is available at $Host"
