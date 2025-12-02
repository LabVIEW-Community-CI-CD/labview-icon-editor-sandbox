[CmdletBinding()]
param(
    [string]$Image,
    [string]$Owner = "svelderrainruiz",
    [string]$Tag = "cpu-latest"
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

Write-Host "Pulling $ref"
& docker pull $ref
if ($LASTEXITCODE -ne 0) {
    throw "docker pull failed with exit code $LASTEXITCODE for $ref"
}
