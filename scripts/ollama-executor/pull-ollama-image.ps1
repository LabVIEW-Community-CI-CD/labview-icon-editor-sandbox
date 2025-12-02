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

Write-Host "Pulling $ref"
docker pull $ref
