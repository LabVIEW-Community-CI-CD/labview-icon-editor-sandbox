[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$BundlePath,
    [string]$Host = "http://localhost:11435",
    [string]$ModelTag = "llama3-8b-local",
    [string]$Image = $env:OLLAMA_IMAGE,
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-latest",
    [int]$Port = 11435,
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

. "$PSScriptRoot/ollama-common.ps1"
Assert-DockerReady -Purpose "verify bundle import"

if (-not (Test-Path -LiteralPath $BundlePath)) {
    throw "BundlePath not found: $BundlePath"
}
$bundleResolved = (Resolve-Path -LiteralPath $BundlePath).Path

Write-Host "Starting ollama-local with bundle $bundleResolved on port $Port"
$args = @{
    Image             = $Image
    Owner             = $Owner
    Tag               = $Tag
    Port              = $Port
    ModelBundlePath   = $bundleResolved
    BundleTargetTag   = $ModelTag
}

& "$PSScriptRoot/run-ollama-container.ps1" @args

Write-Host "Running health check at $Host for model $ModelTag"
& "$PSScriptRoot/check-ollama-endpoint.ps1" -Endpoint $Host -ModelTag $ModelTag -RequireModelTag

if (-not $SkipCleanup) {
    Write-Host "Stopping test container"
    & "$PSScriptRoot/stop-ollama-container.ps1"
}

Write-Host "Bundle import verification completed successfully."
