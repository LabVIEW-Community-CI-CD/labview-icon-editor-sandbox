[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$RequestPath,
    [switch]$ForceDryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Read-JsonFile {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Request file not found: $Path"
    }
    try {
        return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Failed to parse JSON at ${Path}: $($_.Exception.Message)"
    }
}

$request = Read-JsonFile -Path $RequestPath

$repoRoot = if ($request.repoRoot) {
    if ([System.IO.Path]::IsPathRooted($request.repoRoot)) { $request.repoRoot } else { Join-Path (Get-Location) $request.repoRoot }
} else {
    Get-Location
}
$repoRoot = (Resolve-Path -LiteralPath $repoRoot -ErrorAction Stop).ProviderPath

$label = if ($request.PSObject.Properties['label']) { $request.label } else { "vi-compare-sample" }
$outputRoot = if ($request.outputRoot) {
    if ([System.IO.Path]::IsPathRooted($request.outputRoot)) { $request.outputRoot } else { Join-Path $repoRoot $request.outputRoot }
} else {
    Join-Path $repoRoot ".tmp-tests/vi-compare-replays/$label"
}

$requestsPath = if ($request.scenarioPath) {
    if ([System.IO.Path]::IsPathRooted($request.scenarioPath)) { $request.scenarioPath } else { Join-Path $repoRoot $request.scenarioPath }
} else {
    throw "scenarioPath is required in the request payload."
}
$requestsPath = (Resolve-Path -LiteralPath $requestsPath -ErrorAction Stop).ProviderPath

$bundleRoot = if ($request.bundleOutputDirectory) {
    if ([System.IO.Path]::IsPathRooted($request.bundleOutputDirectory)) { $request.bundleOutputDirectory } else { Join-Path $repoRoot $request.bundleOutputDirectory }
} else {
    $null
}

$labviewExe = if ($request.labVIEWExePath) { $request.labVIEWExePath } else { 'C:/Program Files/National Instruments/LabVIEW 2025/LabVIEW.exe' }
$noiseProfile = if ($request.noiseProfile) { $request.noiseProfile } else { 'full' }

$dryRun = $true
if ($null -ne $request.dryRun) { $dryRun = [bool]$request.dryRun }
if ($ForceDryRun) { $dryRun = $true }

$cliScript = Join-Path $repoRoot 'local-ci/windows/scripts/Invoke-ViCompareLabVIEWCli.ps1'
if (-not (Test-Path -LiteralPath $cliScript -PathType Leaf)) {
    throw "Invoke-ViCompareLabVIEWCli.ps1 not found at $cliScript"
}

$splat = @{
    RepoRoot              = $repoRoot
    RequestsPath          = $requestsPath
    OutputRoot            = $outputRoot
    LabVIEWExePath        = $labviewExe
    NoiseProfile          = $noiseProfile
    DryRun                = [bool]$dryRun
    DisableCli            = $false
    DisableSessionCapture = [bool]$request.skipBundle
}

if ($bundleRoot) { $splat['SessionRoot'] = $bundleRoot }
if ($request.ignoreAttributes) { $splat['IgnoreAttributes'] = $true }
if ($request.ignoreFrontPanel) { $splat['IgnoreFrontPanel'] = $true }
if ($request.ignoreFrontPanelPosition) { $splat['IgnoreFrontPanelPosition'] = $true }
if ($request.ignoreBlockDiagram) { $splat['IgnoreBlockDiagram'] = $true }
if ($request.ignoreBlockDiagramCosmetics) { $splat['IgnoreBlockDiagramCosmetics'] = $true }
if ($request.PSObject.Properties['timeoutSeconds']) { $splat['TimeoutSeconds'] = [int]$request.timeoutSeconds }
if ($ForceDryRun) { $splat['DryRun'] = $true }

Write-Host ("[compare] Running VI History/Compare via LabVIEW CLI | label={0} | dryRun={1}" -f $label, $splat['DryRun'])
$summary = & $cliScript @splat

$summaryPath = Join-Path $outputRoot 'vi-comparison-summary.json'
if (-not (Test-Path -LiteralPath $summaryPath -PathType Leaf)) {
    Write-Warning "[compare] Summary file missing: $summaryPath"
    exit 99
}

if (-not $summary) {
    try {
        $summary = Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json -Depth 6
    } catch {
        Write-Warning "[compare] Unable to parse summary: $($_.Exception.Message)"
    }
}

if ($summary) {
    $counts = $summary.counts
    Write-Host ("[compare] Completed: total={0} same={1} different={2} dryRun={3} errors={4}" -f $counts.total, $counts.same, $counts.different, $counts.dryRun, $counts.errors)
}

$exitCode = 0
if ($summary -and $summary.labview.forceDryRun) { $exitCode = 2 }
if ($summary -and $summary.counts.errors -gt 0) { $exitCode = 1 }
if ($ForceDryRun) { $exitCode = 2 }

exit $exitCode
