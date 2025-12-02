[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$existing = docker ps -aq -f name=^ollama-local$
if ($existing) {
    Write-Host "Stopping and removing ollama-local"
    docker rm -f $existing | Out-Null
    Write-Host "Removed ollama-local"
}
else {
    Write-Host "No ollama-local container running"
}
