[CmdletBinding()]
param(
    [string]$Image,
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-latest",
    [int]$Port = 11435
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

if ([string]::IsNullOrWhiteSpace($Image)) {
    if ([string]::IsNullOrWhiteSpace($Owner)) { $Owner = "svelderrainruiz" }
    if ([string]::IsNullOrWhiteSpace($Tag)) { $Tag = "cpu-latest" }
    $ref = "ghcr.io/$($Owner.Trim().ToLowerInvariant())/ollama-local:$($Tag.Trim())"
}
else {
    $ref = $Image.Trim()
}

if (-not $ref) { throw "Image reference is empty; specify Image or Owner/Tag." }

$existing = docker ps -aq -f name=^ollama-local$
if ($existing) {
    Write-Host "Removing existing ollama-local container"
    docker rm -f $existing | Out-Null
}

Write-Host "Starting $ref on localhost:$Port"
& docker run -d --name ollama-local -p ${Port}:${Port} -e OLLAMA_HOST=0.0.0.0:${Port} -v ollama:/root/.ollama $ref serve
if ($LASTEXITCODE -ne 0) {
    throw "docker run failed with exit code $LASTEXITCODE for $ref"
}
