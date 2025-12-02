[CmdletBinding()]
param(
    [string]$Repo = '.',
    [string]$RunKey,
    [int]$LockTtlSec = 900,
    [switch]$ForceLock,
    [ValidateSet('32','64')][string]$SupportedBitness = '64',
    [int]$PackageLabVIEWVersion = 2021,
    [int]$Major = 0,
    [int]$Minor = 1,
    [int]$Patch = 0,
    [int]$Build = 0
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = (Resolve-Path -LiteralPath $Repo).ProviderPath
$runKey = if ($RunKey) { $RunKey } else { "sd-ppl-$((Get-Date).ToString('yyyyMMdd-HHmmss'))" }
$lockPath = Join-Path $repoRoot '.locks/orchestration.lock'
$lockDir = Split-Path -Parent $lockPath
if (-not (Test-Path -LiteralPath $lockDir)) { New-Item -ItemType Directory -Path $lockDir -Force | Out-Null }

# Create an isolated worktree for the PPL build to keep it separate from the SD build.
$worktreeRoot = Join-Path $repoRoot "builds/worktrees/ppl-$runKey"
if (Test-Path -LiteralPath $worktreeRoot) {
    git -C $repoRoot worktree remove -f $worktreeRoot 2>$null | Out-Null
}
git -C $repoRoot worktree add $worktreeRoot HEAD | Out-Null

$orchArgs = @('local-sd', '--repo', $repoRoot, '--run-key', $runKey, '--lock-path', $lockPath, '--lock-ttl-sec', $LockTtlSec)
if ($ForceLock) { $orchArgs += '--force-lock' }

$invoker = Join-Path $repoRoot 'scripts/common/invoke-repo-cli.ps1'
if (-not (Test-Path -LiteralPath $invoker)) { throw "CLI invoker missing at $invoker" }

Write-Host "[orchestration] runKey=$runKey lock=$lockPath ttl=${LockTtlSec}s force=$ForceLock"
& $invoker -CliName 'OrchestrationCli' -RepoRoot $repoRoot -Args $orchArgs
if ($LASTEXITCODE -ne 0) { throw "OrchestrationCli local-sd failed with exit code $LASTEXITCODE" }

$zipPath = Join-Path $repoRoot 'builds/artifacts/labview-icon-api.zip'
if (-not (Test-Path -LiteralPath $zipPath -PathType Leaf)) { throw "labview-icon-api.zip missing; expected at $zipPath" }

$extractRoot = Join-Path $worktreeRoot 'sd-extract'
if (Test-Path -LiteralPath $extractRoot) { Remove-Item -LiteralPath $extractRoot -Recurse -Force }
New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
Write-Host "[sequence] prepare extract at $extractRoot from $zipPath"
Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force

$projectPath = Join-Path $extractRoot 'lv_icon_editor.lvproj'
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "Extracted SD missing project at $projectPath"
}
Write-Host "[sequence] extracted lvproj: $projectPath"

# Copy supporting scripts/Tooling into the extracted SD so dev-mode bind/tests can run in isolation.
$scriptSrc = Join-Path $repoRoot 'scripts'
$scriptDest = Join-Path $extractRoot 'scripts'
if (Test-Path -LiteralPath $scriptSrc) {
    Copy-Item -Path (Join-Path $scriptSrc '*') -Destination $scriptDest -Recurse -Force
}
$toolingSrc = Join-Path $repoRoot 'Tooling'
$toolingDest = Join-Path $extractRoot 'Tooling'
if (Test-Path -LiteralPath $toolingSrc) {
    Copy-Item -LiteralPath $toolingSrc -Destination $toolingDest -Recurse -Force
}

# Bind dev-mode to the extracted SD root for the target bitness.
$bindScriptCandidates = @(
    (Join-Path $extractRoot 'scripts/task-devmode-bind.ps1'),
    (Join-Path $extractRoot 'scripts/scripts/task-devmode-bind.ps1')
)
$bindScript = $bindScriptCandidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
if (-not $bindScript) {
    throw "Dev-mode bind script not found under $extractRoot (looked in scripts/ and scripts/scripts/)"
}
Write-Host ("[sequence] dev-mode bind start (bitness={0})" -f $SupportedBitness)
& pwsh -NoProfile -File $bindScript -RepositoryPath $extractRoot -Mode bind -Bitness $SupportedBitness -UseWorktree:$false -Preclear
if ($LASTEXITCODE -ne 0) { throw "Dev-mode bind failed (exit $LASTEXITCODE)" }
Write-Host "[sequence] dev-mode bind complete"

Write-Host "[sequence] missing-check -> unit-tests -> PPL using runKey=$runKey worktree=$worktreeRoot"

Write-Host "[sequence] missing-check start"
$missingScript = Join-Path $repoRoot 'scripts/missing-in-project/RunMissingCheckWithGCLI.ps1'
& pwsh -NoProfile -File $missingScript -LVVersion $PackageLabVIEWVersion -Arch $SupportedBitness -ProjectFile $projectPath
if ($LASTEXITCODE -ne 0) { throw "missing-check failed (exit $LASTEXITCODE); aborting before PPL" }
Write-Host "[sequence] missing-check complete"

Write-Host "[sequence] unit-tests start"
$unitScript = Join-Path $repoRoot 'scripts/run-unit-tests/RunUnitTests.ps1'
& pwsh -NoProfile -File $unitScript -SupportedBitness $SupportedBitness -Package_LabVIEW_Version $PackageLabVIEWVersion -AbsoluteProjectPath $projectPath
if ($LASTEXITCODE -ne 0) { throw "unit-tests failed (exit $LASTEXITCODE); aborting before PPL" }
Write-Host "[sequence] unit-tests complete; starting PPL build"

$pplBuilder = Join-Path $repoRoot 'scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1'
Write-Host "[ppl-from-sd] Building PPL for ${PackageLabVIEWVersion}/${SupportedBitness} using worktree $worktreeRoot extract=$extractRoot"
& pwsh -NoProfile -ExecutionPolicy Bypass -File $pplBuilder `
    -RepositoryPath $worktreeRoot `
    -SourceDistZip $zipPath `
    -ExtractRoot $extractRoot `
    -UseExistingExtract `
    -Package_LabVIEW_Version $PackageLabVIEWVersion `
    -SupportedBitness $SupportedBitness `
    -Major $Major -Minor $Minor -Patch $Patch -Build $Build
if ($LASTEXITCODE -ne 0) { throw "PPL build failed with exit code $LASTEXITCODE" }

$pplSource = Join-Path $extractRoot 'resource/plugins/lv_icon.lvlibp'
if (-not (Test-Path -LiteralPath $pplSource)) { throw "Expected PPL not found at $pplSource" }

$artifactsDir = Join-Path $repoRoot 'artifacts'
New-Item -ItemType Directory -Path $artifactsDir -Force | Out-Null

$zipStaged = Join-Path $artifactsDir 'labview-icon-api.zip'
Copy-Item -LiteralPath $zipPath -Destination $zipStaged -Force

$pplStaged = Join-Path $artifactsDir 'labview-icon-api.ppl'
Copy-Item -LiteralPath $pplSource -Destination $pplStaged -Force

function Get-RelativePath {
    param([string]$Path)
    return [System.IO.Path]::GetRelativePath($repoRoot, $Path)
}

$handshakeEntries = @(
    @{Label='labview-icon-api.zip'; Path=$zipStaged},
    @{Label='labview-icon-api.ppl'; Path=$pplStaged}
)

$hashData = @{}
foreach ($entry in $handshakeEntries) {
    $hash = (Get-FileHash -LiteralPath $entry.Path -Algorithm SHA256).Hash
    $rel = Get-RelativePath -Path $entry.Path
    $hashData[$entry.Label] = @{path=$rel; sha256=$hash}
    Write-Host "[artifact][$($entry.Label)] $rel ($hash)"
}

$handshake = @{
    runKey = $runKey
    lockPath = (Resolve-Path -LiteralPath $lockPath).Path
    lockTtlSec = $LockTtlSec
    forceLock = $ForceLock.IsPresent
    zipRelPath = $hashData['labview-icon-api.zip'].path
    zipSha256 = $hashData['labview-icon-api.zip'].sha256
    pplRelPath = $hashData['labview-icon-api.ppl'].path
    pplSha256 = $hashData['labview-icon-api.ppl'].sha256
    timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
}

$handshakePath = Join-Path $artifactsDir 'labview-icon-api-handshake.json'
ConvertTo-Json $handshake -Depth 5 | Set-Content -LiteralPath $handshakePath -Encoding utf8
Write-Host "[handoff] handshake saved at $(Get-RelativePath -Path $handshakePath)"

$isoRoot = Join-Path $repoRoot 'builds-isolated'
$runDir = Join-Path $isoRoot $runKey
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
Copy-Item -Path $artifactsDir -Destination $runDir -Recurse -Force
Write-Host "[handoff] staged under $runDir"

Write-Host "[summary] zip=$(Get-RelativePath -Path $zipStaged) SHA=$($hashData['labview-icon-api.zip'].sha256)"
Write-Host "[summary] ppl=$(Get-RelativePath -Path $pplStaged) SHA=$($hashData['labview-icon-api.ppl'].sha256)"
Write-Host "[summary] runKey=$runKey lockPath=$lockPath lockTtl=$LockTtlSec force=$ForceLock"
