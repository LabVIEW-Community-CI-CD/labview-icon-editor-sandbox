<#
.SYNOPSIS
    Build the "LabVIEWIconAPI" Source Distribution spec and emit a manifest/zip artifact.

.DESCRIPTION
    Invokes the LabVIEW build spec "LabVIEWIconAPI" via g-cli lvbuildspec,
    then produces a manifest mapping each built file to the last git commit
    touching the corresponding source path, and zips the output folder.

.PARAMETER RepositoryPath
    Path to the repository root containing lv_icon_editor.lvproj.

.PARAMETER Package_LabVIEW_Version
    LabVIEW version to use (e.g., 2021). If omitted, resolves from VIPB.

.PARAMETER SupportedBitness
    Bitness to use (32 or 64). If omitted, resolves from VIPB and defaults
    to 64 when VIPB reports "both".
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [string]$Package_LabVIEW_Version,

    [ValidateSet('32','64','both')]
    [string]$SupportedBitness,

    [string]$CommitIndexPath,

    [switch]$VerboseGit
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$script:StartTime = Get-Date
$script:CurrentPhase = "init"
$script:HeartbeatTimer = $null
$script:HeartbeatSource = $null
$script:PhaseStartTime = $script:StartTime
$script:PhaseWarned = $false
$script:IdleWarnThresholdSec = 240
$tempHelper = Join-Path $PSScriptRoot '..\common\Ensure-StandardTempPath.ps1'
if (-not (Test-Path -LiteralPath $tempHelper)) {
    throw "Missing temp helper at $tempHelper"
}
. $tempHelper
try { Ensure-StandardTempPath -Label 'labview-icon-editor' | Out-Null } catch { throw }

function Get-Elapsed {
    param([datetime]$StartTime = $script:StartTime)
    $elapsed = (Get-Date) - $StartTime
    return "[T+{0:N1}s]" -f $elapsed.TotalSeconds
}
function Write-Stamp {
    param([string]$Level = "INFO", [string]$Message, [datetime]$StartTime = $script:StartTime)
    Write-Host ("[{0}] {1} {2}" -f $Level, (Get-Elapsed -StartTime $StartTime), $Message)
}

function New-IconApiPayload {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$ManifestPath,
        [Parameter(Mandatory)][string]$ZipPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Container)) {
        throw "Icon API payload folder not found at $SourcePath"
    }
    $files = Get-ChildItem -Path $SourcePath -File -Recurse | Sort-Object FullName
    if ($files.Count -eq 0) {
        throw "Icon API payload is empty at $SourcePath"
    }

    $entries = foreach ($f in $files) {
        $rel = [IO.Path]::GetRelativePath($SourcePath, $f.FullName).Replace('\','/')
        $hash = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        [pscustomobject]@{
            path      = $rel
            size_bytes= $f.Length
            sha256    = $hash
        }
    }

    $manifestDir = Split-Path -Parent $ManifestPath
    if (-not (Test-Path -LiteralPath $manifestDir)) {
        New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
    }
    $entries | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ManifestPath -Encoding utf8

    $zipDir = Split-Path -Parent $ZipPath
    if (-not (Test-Path -LiteralPath $zipDir)) {
        New-Item -ItemType Directory -Path $zipDir -Force | Out-Null
    }
    if (Test-Path -LiteralPath $ZipPath) { Remove-Item -LiteralPath $ZipPath -Force }
    Compress-Archive -Path (Join-Path $SourcePath '*') -DestinationPath $ZipPath -Force
    $zipHash = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash

    return @{
        manifest_path = $ManifestPath
        zip_path      = $ZipPath
        zip_hash      = $zipHash
        entries_count = $entries.Count
    }
}

function Sync-IconEditorAssets {
    param(
        [Parameter(Mandatory)][string]$RepoRoot,
        [Parameter(Mandatory)][string]$LabVIEWVersion
    )
    # g-cli builds look for Icon Editor assets under the LabVIEW install; populate them from the repo if missing.
    $lvRoot = Join-Path 'C:\Program Files\National Instruments' ("LabVIEW {0}" -f $LabVIEWVersion)
    if (-not (Test-Path -LiteralPath $lvRoot -PathType Container)) {
        Write-Stamp -Level "WARN" -Message ("LabVIEW root not found at {0}; skipping Icon Editor asset sync." -f $lvRoot)
        return
    }

    $pairs = @(
        @{
            Label  = 'Icon Editor plugins'
            Source = Join-Path $RepoRoot 'resource\plugins'
            Dest   = Join-Path $lvRoot 'resource\plugins'
        },
        @{
            Label  = 'LabVIEW Icon API'
            Source = Join-Path $RepoRoot 'vi.lib\LabVIEW Icon API'
            Dest   = Join-Path $lvRoot 'vi.lib\LabVIEW Icon API'
        }
    )

    foreach ($p in $pairs) {
        if (-not (Test-Path -LiteralPath $p.Source -PathType Container)) {
            Write-Stamp -Level "WARN" -Message ("[{0}] Source missing; skipping copy: {1}" -f $p.Label, $p.Source)
            continue
        }
        Write-Stamp -Level "INFO" -Message ("[{0}] Syncing assets -> {1}" -f $p.Label, $p.Dest)
        $args = @(
            $p.Source,
            $p.Dest,
            '/E', '/COPY:DAT', '/R:1', '/W:1',
            '/NFL', '/NDL', '/NJH', '/NJS'
        )
        & robocopy @args | Out-Null
        $rc = $LASTEXITCODE
        # Robocopy returns 0–7 for success / minor issues; anything higher is failure.
        if ($rc -gt 7) {
            throw ("Robocopy failed ({0}) while syncing {1} -> {2}" -f $rc, $p.Source, $p.Dest)
        }
    }
}

function Start-Heartbeat {
    try {
        $script:HeartbeatTimer = New-Object System.Timers.Timer
        $script:HeartbeatTimer.Interval = 60000
        $script:HeartbeatTimer.AutoReset = $true
        $action = {
            if ($script:CurrentPhase) {
                Write-Host ("[HB] {0} phase={1}" -f (Get-Elapsed), $script:CurrentPhase)
                $phaseElapsed = (Get-Date) - $script:PhaseStartTime
                if (-not $script:PhaseWarned -and $phaseElapsed.TotalSeconds -ge $script:IdleWarnThresholdSec) {
                    Write-Host ("[WARN] {0} phase={1} idle for ~{2:N0}s. If LabVIEW/g-cli is showing a dialog or prompt, please close it." -f (Get-Elapsed), $script:CurrentPhase, $phaseElapsed.TotalSeconds)
                    $script:PhaseWarned = $true
                }
            }
        }
        $script:HeartbeatSource = Register-ObjectEvent -InputObject $script:HeartbeatTimer -EventName Elapsed -Action $action
        $script:HeartbeatTimer.Start() | Out-Null
    }
    catch {
        # best-effort; ignore heartbeat failures
    }
}

function Stop-Heartbeat {
    try {
        if ($script:HeartbeatTimer) {
            $script:HeartbeatTimer.Stop()
            $script:HeartbeatTimer.Dispose()
        }
        if ($script:HeartbeatSource) {
            Unregister-Event -SourceIdentifier $script:HeartbeatSource.Name -ErrorAction SilentlyContinue
        }
    }
    catch { }
}

function Set-Phase {
    param([string]$Name)
    $script:CurrentPhase = $Name
    $script:PhaseStartTime = Get-Date
    $script:PhaseWarned = $false
}

function Resolve-VipbVersion {
    param([string]$Repo)
    $script = Join-Path $Repo 'scripts/get-package-lv-version.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Missing get-package-lv-version.ps1 at $script"
    }
    return & $script -RepositoryPath $Repo
}

function Resolve-VipbBitness {
    param([string]$Repo)
    $script = Join-Path $Repo 'scripts/get-package-lv-bitness.ps1'
    if (-not (Test-Path -LiteralPath $script)) {
        throw "Missing get-package-lv-bitness.ps1 at $script"
    }
    $b = & $script -RepositoryPath $Repo
    if ($b -eq 'both') { return '64' }
    return $b
}

function Get-DistRoot {
    param([string]$Repo)
    $default = Join-Path $Repo 'builds/LabVIEWIconAPI'
    if (Test-Path -LiteralPath $default -PathType Container) { return $default }
    $candidates = Get-ChildItem -Path (Join-Path $Repo 'builds') -Directory -Filter '*LabVIEWIconAPI*' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($candidates) { return $candidates[0].FullName }
    throw "Could not locate LabVIEWIconAPI Source Distribution output folder under $(Join-Path $Repo 'builds')"
}

function Get-LastCommitForPath {
    param(
        [string]$Repo,
        [string]$RelativePath
    )
    # Normalize to POSIX-style separators for git
    $normalized = $RelativePath.Replace('\','/')
    try {
        $res = git -C $Repo log -1 --format=%H --full-history --all -- $normalized 2>$null
        if ($LASTEXITCODE -eq 0 -and $res) { return $res.Trim() }
    }
    catch { }
    return $null
}

function Get-LastCommitInfo {
    param(
        [string]$Repo,
        [string]$RelativePath
    )
    $normalized = $RelativePath.Replace('\','/')
    try {
        $res = git -C $Repo log -1 --format='%H|%an|%ai' --full-history --all -- $normalized 2>$null
        if ($LASTEXITCODE -eq 0 -and $res) {
            $parts = $res.Trim().Split('|')
            if ($parts.Count -ge 3) {
                return [pscustomobject]@{
                    Commit = $parts[0]
                    Author = $parts[1]
                    Date   = $parts[2]
                }
            }
        }
    }
    catch { }
    return $null
}

function Get-HeadCommitInfo {
    param([string]$Repo)
    try {
        $res = git -C $Repo log -1 --format='%H|%an|%ai' 2>$null
        if ($LASTEXITCODE -eq 0 -and $res) {
            $parts = $res.Trim().Split('|')
            if ($parts.Count -ge 3) {
                return [pscustomobject]@{
                    Commit = $parts[0]
                    Author = $parts[1]
                    Date   = $parts[2]
                }
            }
        }
    }
    catch { }
    return $null
}

function Get-LlbContainerPath {
    param([string]$RelativePath)
    $p = $RelativePath.Replace('\','/')
    $idx = $p.IndexOf('.llb/')
    if ($idx -ge 0) {
        return $p.Substring(0, $idx + 4) # include ".llb"
    }
    return $null
}

function Map-RelativePath {
    param(
        [string]$RelativePath,
        [string]$RepoName
    )
    $p = $RelativePath.Replace('\','/')
    $rewrites = @(
        @{ from = ("repos/{0}/" -f $RepoName); to = '' },
        @{ from = 'Program Files/National Instruments/LabVIEW 2021/resource/'; to = 'resource/' }
    )
    foreach ($rule in $rewrites) {
        if ($p.StartsWith($rule.from, [StringComparison]::OrdinalIgnoreCase)) {
            $p = $rule.to + $p.Substring($rule.from.Length)
            break
        }
    }
    return $p.TrimStart('/')
}

function Get-RelativePathSafe {
    param([string]$Base,[string]$Target)
    try {
        return [System.IO.Path]::GetRelativePath($Base, $Target)
    }
    catch {
        return $Target
    }
}

function Load-CommitIndex {
    param([string]$Path, [datetime]$StartTime)
    if (-not $Path) { return $null }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Commit index not found at $Path; supply --CommitIndexPath or generate the index before building."
    }
    try {
        $raw = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $entries = $raw
        if ($raw.PSObject.Properties.Name -contains 'entries') {
            $entries = $raw.entries
        }
        $map = @{}
        $llbMap = @{}
        foreach ($e in $entries) {
            if (-not $e.path) { continue }
            $key = $e.path.ToString().ToLowerInvariant()
            $map[$key] = $e
            if ($e.isContainer) {
                $llbMap[$key] = $e
            }
        }
        Write-Stamp -Level "INFO" -Message ("Loaded commit index with {0} entries from {1}" -f $map.Count, $Path) -Start $StartTime
        return @{ map = $map; llb = $llbMap; metadata = $raw.metadata }
    }
    catch {
        throw ("Failed to load commit index at {0}: {1}" -f $Path, $_.Exception.Message)
    }
}

$repoRoot = (Resolve-Path -LiteralPath $RepositoryPath).Path
if (-not $Package_LabVIEW_Version) {
    $Package_LabVIEW_Version = Resolve-VipbVersion -Repo $repoRoot
}
if (-not $SupportedBitness) {
    $SupportedBitness = Resolve-VipbBitness -Repo $repoRoot
}
  if (-not $CommitIndexPath) {
      $defaultCommitIndex = Join-Path $repoRoot 'builds/cache/commit-index.json'
      if (Test-Path -LiteralPath $defaultCommitIndex -PathType Leaf) {
          $CommitIndexPath = $defaultCommitIndex
          Write-Stamp -Level "INFO" -Message ("Using default commit index: {0}" -f $CommitIndexPath)
      }
      else {
          throw "Commit index path not supplied and default not found; provide --CommitIndexPath or create builds/cache/commit-index.json via scripts/build-source-distribution/New-CommitIndex.ps1."
      }
  }

$projectPath = Join-Path $repoRoot 'lv_icon_editor.lvproj'
if (-not (Test-Path -LiteralPath $projectPath -PathType Leaf)) {
    throw "Project not found: $projectPath"
}

$gcli = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcli) { throw "g-cli is required but was not found on PATH." }

$script:AssetBackups = @()
function Disable-LabVIEWAssets {
    param([string[]]$Paths)
    foreach ($p in $Paths) {
        if (-not (Test-Path -LiteralPath $p)) { continue }
        $backup = "$p.disabled"
        if (Test-Path -LiteralPath $backup) {
            Remove-Item -LiteralPath $backup -Recurse -Force -ErrorAction SilentlyContinue
        }
        Move-Item -LiteralPath $p -Destination $backup -Force
        $script:AssetBackups += @{ Original = $p; Backup = $backup }
    }
}

function Restore-LabVIEWAssets {
    foreach ($b in $script:AssetBackups) {
        if (-not $b.Backup) { continue }
        if (Test-Path -LiteralPath $b.Original) {
            Remove-Item -LiteralPath $b.Original -Recurse -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path -LiteralPath $b.Backup) {
            Move-Item -LiteralPath $b.Backup -Destination $b.Original -Force
        }
    }
}

# Build a manifest/zip of the repo-staged Icon API payload for traceability and to detect drift.
$iconApiSource   = Join-Path $repoRoot 'vi.lib\LabVIEW Icon API'
$iconCacheRoot   = Join-Path $repoRoot 'builds/cache/icon-api'
$iconManifest    = Join-Path $iconCacheRoot 'icon-api-manifest.json'
$iconZip         = Join-Path $iconCacheRoot 'icon-api.zip'
$iconPayloadInfo = New-IconApiPayload -SourcePath $iconApiSource -ManifestPath $iconManifest -ZipPath $iconZip
Write-Stamp -Level "INFO" -Message ("Icon API payload: {0} files, zip SHA256={1}" -f $iconPayloadInfo.entries_count, $iconPayloadInfo.zip_hash)

# Ensure LabVIEW has the Icon Editor assets that the build depends on (copied from the repo payload).
Sync-IconEditorAssets -RepoRoot $repoRoot -LabVIEWVersion $Package_LabVIEW_Version

Start-Heartbeat
try {
    Write-Stamp -Level "INFO" -Message "Expected durations: build ~60-120s depending on LabVIEW startup; manifest/zip ~10-30s."

$lvRootIsolation = Join-Path 'C:\\Program Files\\National Instruments' ("LabVIEW {0}" -f $Package_LabVIEW_Version)
$isolationTargets = @(
    Join-Path $lvRootIsolation 'resource\\plugins\\NIIconEditor'
    Join-Path $lvRootIsolation 'vi.lib\\LabVIEW Icon API'
)
Disable-LabVIEWAssets -Paths $isolationTargets

try {
# Build the Icon API Source Distribution
Set-Phase -Name "g-cli build"
$buildStart = Get-Date
$buildArgs = @(
    '--lv-ver', $Package_LabVIEW_Version,
    '--arch', $SupportedBitness,
    'lvbuildspec',
    '--',
    '-p', $projectPath,
    '-b', 'LabVIEWIconAPI'
)
Write-Stamp -Level "STEP" -Message ("Building LabVIEWIconAPI Source Distribution via g-cli: {0}" -f ($buildArgs -join ' '))
$buildArgsEscaped = $buildArgs | ForEach-Object {
    if ($_ -match '\s') { '"' + $_.Replace('"','\"') + '"' } else { $_ }
}
$buildProc = Start-Process -FilePath "g-cli" -ArgumentList $buildArgsEscaped -PassThru -NoNewWindow
if (-not $buildProc) {
    throw "Failed to start g-cli process."
}
Write-Stamp -Level "INFO" -Message ("g-cli pid={0} started; waiting for completion..." -f $buildProc.Id)
Wait-Process -Id $buildProc.Id
$buildExit = 0
try { $buildExit = $buildProc.ExitCode } catch { $buildExit = $LASTEXITCODE }
if ($buildExit -ne 0) {
    throw "lvbuildspec failed with exit code $buildExit"
}
$buildEnd = Get-Elapsed
$buildDuration = ((Get-Date) - $buildStart).TotalSeconds
Write-Stamp -Level "INFO" -Message ("g-cli build completed (duration={0:N1}s)" -f $buildDuration)
Write-Stamp -Level "STEP" -Message "Source Distribution built; generating manifest and zip next..."
Write-Stamp -Level "INFO" -Message "Build spec succeeded (pre-manifest/zip); locating distribution folder..."

}
finally {
    Restore-LabVIEWAssets
}

$distRoot = Get-DistRoot -Repo $repoRoot
Write-Stamp -Level "INFO" -Message ("Using Source Distribution folder: {0}" -f $distRoot)

# Create manifest
$manifestPath = Join-Path $distRoot 'manifest.json'
$manifestStartTime = Get-Date
$files = Get-ChildItem -Path $distRoot -File -Recurse
$totalFiles = $files.Count
$processed = 0
$repoRootResolved = (Resolve-Path -LiteralPath $repoRoot).Path
$repoName = Split-Path -Leaf $repoRootResolved
$manifest = @()
$pathsForIndex = New-Object System.Collections.Generic.List[string]
$headCommitInfo = Get-HeadCommitInfo -Repo $repoRootResolved

  # Build a commit index based on the actual built files (post-build) only if one does not already exist.
    $commitIndexMap = @{}
    $commitIndexLlbMap = @{}
    $commitIndexScript = Join-Path $repoRoot 'scripts/build-source-distribution/New-CommitIndex.ps1'
    if ($CommitIndexPath -and (Test-Path -LiteralPath $commitIndexScript -PathType Leaf)) {
      if (Test-Path -LiteralPath $CommitIndexPath -PathType Leaf) {
        Write-Stamp -Level "INFO" -Message ("Using existing commit index at {0}" -f $CommitIndexPath)
      }
      else {
        $script:CurrentPhase = "commit-index"
        foreach ($f in $files) {
            $relDist = [IO.Path]::GetRelativePath($distRoot, $f.FullName)
            $mappedRel = Map-RelativePath -RelativePath $relDist -RepoName $repoName
            if ($mappedRel) { $pathsForIndex.Add($mappedRel) | Out-Null }
        }
        $uniquePaths = $pathsForIndex | Where-Object { $_ } | Sort-Object -Unique
        if ($uniquePaths.Count -gt 0) {
          Write-Stamp -Level "STEP" -Message ("Generating commit index from built files ({0} paths)..." -f $uniquePaths.Count)
          $pathsArray = @($uniquePaths)
          $commitIndexParams = @{
              RepositoryPath = $repoRoot
              OutputPath     = $CommitIndexPath
              InputPaths     = $pathsArray
              AllowDirty     = $true
          }
          & pwsh -NoProfile -File $commitIndexScript @commitIndexParams | Out-Null
          Write-Stamp -Level "INFO" -Message ("Commit index generated at {0}" -f $CommitIndexPath)
        }
      }
    }

# Load commit index if available
$commitIndex = $null
if ($CommitIndexPath) {
    $commitIndex = Load-CommitIndex -Path $CommitIndexPath -StartTime $script:StartTime
    if ($commitIndex) {
        $commitIndexMap = $commitIndex.map
        $commitIndexLlbMap = $commitIndex.llb
    }
}

$script:CurrentPhase = "manifest"
Write-Stamp -Level "STEP" -Message ("Creating manifest for {0} files..." -f $totalFiles)
foreach ($f in $files) {
    $processed++
    $relDist = [IO.Path]::GetRelativePath($distRoot, $f.FullName)
    $sourceRel = $relDist.Replace('\','/')
    $mappedRel = Map-RelativePath -RelativePath $relDist -RepoName $repoName
    $sourceCandidate = if ($mappedRel) { Join-Path $repoRootResolved $mappedRel } else { $null }
    $commitInfo = $headCommitInfo
    $commitSource = 'repo_head'
    $indexKey = ($mappedRel ? $mappedRel : $relDist).Replace('\','/').ToLowerInvariant()
    if ($commitIndexMap.Count -gt 0 -and $indexKey) {
        if ($commitIndexMap.ContainsKey($indexKey)) {
            $entry = $commitIndexMap[$indexKey]
            if ($entry.commit) {
                $commitInfo = [pscustomobject]@{
                    Commit = $entry.commit
                    Author = $entry.author
                    Date   = $entry.date
                }
                $commitSource = 'index'
            }
        }
        if ($commitSource -eq 'repo_head') {
            $llbPath = Get-LlbContainerPath -RelativePath ($mappedRel ? $mappedRel : $relDist)
            if ($llbPath) {
                $llbKey = $llbPath.ToLowerInvariant()
                if ($commitIndexLlbMap.ContainsKey($llbKey)) {
                    $entry = $commitIndexLlbMap[$llbKey]
                    $commitInfo = [pscustomobject]@{
                        Commit = $entry.commit
                        Author = $entry.author
                        Date   = $entry.date
                    }
                    $commitSource = 'llb_container'
                }
            }
        }
    }
    # Generated files (manifest/icon-api artifacts) are tagged as generated to avoid repo_head guard.
    if ($sourceRel -in @('manifest.json','manifest.csv','icon-api-manifest.json','icon-api.zip')) {
        $commitSource = 'generated'
        $commitInfo = $null
    }

    $manifest += [pscustomobject]@{
        path          = $sourceRel
        last_commit   = if ($commitInfo) { $commitInfo.Commit } else { $null }
        commit_author = if ($commitInfo) { $commitInfo.Author } else { $null }
        commit_date   = if ($commitInfo) { $commitInfo.Date } else { $null }
        size_bytes    = $f.Length
        commit_source = $commitSource
    }

    if ($VerboseGit) {
        Write-Stamp -Level "INFO" -Message ("[git] {0}/{1} {2} -> {3}" -f $processed, $totalFiles, ($mappedRel ? $mappedRel : $relDist), ($manifest[-1].last_commit ?? 'null'))
    } elseif ($processed % 50 -eq 0) {
        Write-Stamp -Level "INFO" -Message ("Processed {0}/{1} files for manifest..." -f $processed, $totalFiles)
    }
}

# Guard: commit_source must never fall back to repo_head and content must stay within the allowed scope.
$badCommit = $manifest | Where-Object { $_.commit_source -eq 'repo_head' }
if ($badCommit.Count -gt 0) {
    $sample = $badCommit[0].path
    throw "Manifest commit_source must not be repo_head (example path: $sample). Supply a commit index that covers all built files."
}
$allowedPrefixes = @(
    'resource/',
    'vi.lib/LabVIEW Icon API/',
    'Test/Unit tests/'
)
$generatedFiles = @('manifest.json', 'manifest.csv', 'icon-api-manifest.json', 'icon-api.zip')
$nonAllowed = $manifest | Where-Object {
    $p = $_.path
    if ($generatedFiles -contains $p) { return $false }
    -not ($allowedPrefixes | Where-Object { $p.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) })
}
if ($nonAllowed.Count -gt 0) {
    $sample = $nonAllowed[0].path
    throw "Manifest contains paths outside allowed scope (resource/, vi.lib/LabVIEW Icon API/, Test/Unit tests/): $sample"
}

$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding utf8
# Also emit CSV for spreadsheet/requirements ingestion.
$manifestCsvPath = Join-Path $distRoot 'manifest.csv'
$manifest | Select-Object path,last_commit,commit_author,commit_date,commit_source,size_bytes |
    ConvertTo-Csv -NoTypeInformation |
    Set-Content -LiteralPath $manifestCsvPath -Encoding utf8
Write-Host ("Manifest written: {0}" -f $manifestPath)
$manifestEndTime = Get-Date
$manifestDuration = ($manifestEndTime - $manifestStartTime).TotalSeconds
Write-Stamp -Level "INFO" -Message ("Manifest complete (files={0}, duration={1:N1}s)" -f $totalFiles, $manifestDuration)

# Publish Icon API payload/manifest alongside the SD output for traceability.
try {
    Copy-Item -LiteralPath $iconManifest -Destination (Join-Path $distRoot 'icon-api-manifest.json') -Force
    Copy-Item -LiteralPath $iconZip -Destination (Join-Path $distRoot 'icon-api.zip') -Force
} catch {
    Write-Warning ("[icon-api] Failed to copy payload artifacts into Source Distribution: {0}" -f $_.Exception.Message)
}

# Zip the distribution (including manifest)
Set-Phase -Name "zip"
$zipStartTime = Get-Date
$artifactDir = Join-Path $repoRoot 'builds/artifacts'
if (-not (Test-Path -LiteralPath $artifactDir)) {
    New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
}
$zipPath = Join-Path $artifactDir 'labview-icon-api.zip'
Write-Stamp -Level "STEP" -Message "Zipping LabVIEWIconAPI Source Distribution..."
Compress-Archive -Path (Join-Path $distRoot '*') -DestinationPath $zipPath -Force
    $zipEndTime = Get-Date
    $zipDuration = ($zipEndTime - $zipStartTime).TotalSeconds
    Write-Stamp -Level "INFO" -Message ("Zipped LabVIEWIconAPI Source Distribution: {0}" -f $zipPath)

    # Mirror artifacts into builds-isolated/ for CI publish steps.
    $isoRoot    = Join-Path $repoRoot 'builds-isolated'
    $isoBuilds  = Join-Path $isoRoot 'builds'
    $isoDist    = Join-Path $isoBuilds 'LabVIEWIconAPI'
    $isoArtifacts = Join-Path $isoBuilds 'artifacts'
    foreach ($dir in @($isoDist, $isoArtifacts)) {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    }
    # Copy the distribution folder (manifests + payload).
    $copyDistArgs = @(
        $distRoot,
        $isoDist,
        '/E', '/COPY:DAT', '/R:1', '/W:1',
        '/NFL', '/NDL', '/NJH', '/NJS'
    )
    & robocopy @copyDistArgs | Out-Null
    $rcDist = $LASTEXITCODE
    if ($rcDist -gt 7) {
        Write-Warning ("[info] Mirror to builds-isolated failed for dist (rc={0}); continuing with primary artifacts." -f $rcDist)
    }
    # Copy the zip
    try {
        Copy-Item -LiteralPath $zipPath -Destination (Join-Path $isoArtifacts 'labview-icon-api.zip') -Force
    }
    catch {
        Write-Warning ("[info] Failed to copy zip to builds-isolated: {0}" -f $_.Exception.Message)
    }
    # Mirror Icon API payload artifacts into artifacts folder as well.
    foreach ($pair in @(@{Src=$iconManifest; Dest='icon-api-manifest.json'}, @{Src=$iconZip; Dest='icon-api.zip'})) {
        try {
            Copy-Item -LiteralPath $pair.Src -Destination (Join-Path $artifactDir $pair.Dest) -Force
            Copy-Item -LiteralPath $pair.Src -Destination (Join-Path $isoArtifacts $pair.Dest) -Force
        }
        catch {
            Write-Warning ("[icon-api] Failed to publish {0}: {1}" -f $pair.Dest, $_.Exception.Message)
        }
    }

    $relJson = Get-RelativePathSafe -Base $repoRoot -Target $manifestPath
    $relCsv = Get-RelativePathSafe -Base $repoRoot -Target $manifestCsvPath
    $relZip = Get-RelativePathSafe -Base $repoRoot -Target $zipPath
    Write-Host ("[artifact][labview-icon-api] manifest.json: {0}" -f $relJson)
    Write-Host ("[artifact][labview-icon-api] manifest.csv: {0}" -f $relCsv)
Write-Host ("[artifact][labview-icon-api] zip: {0}" -f $relZip)
    Write-Host ("[artifact][labview-icon-api] icon-api manifest: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target (Join-Path $artifactDir 'icon-api-manifest.json')))
    Write-Host ("[artifact][labview-icon-api] icon-api zip: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target (Join-Path $artifactDir 'icon-api.zip')))
Write-Host ("[info] Built with LabVIEW {0} ({1}-bit) based on VIPB." -f $Package_LabVIEW_Version, $SupportedBitness)
Write-Host ("[info] Next steps: run task 21 (Verify: Source Distribution) to validate the manifest; or task 22 (Build PPL from Source Distribution) to produce the PPL from this zip.")
Write-Host ("[info] Extracted contents: {0}" -f (Get-RelativePathSafe -Base $repoRoot -Target $distRoot))
Write-Host ("[info] Log-stash bundles (if enabled) are under builds/log-stash/.")
Write-Host ("[info] Re-run will overwrite artifacts; delete the dist folder for a clean extract if needed.")
Write-Stamp -Level "INFO" -Message ("Phase summary: build {0:N1}s, manifest {1:N1}s, zip {2:N1}s" -f $buildDuration, $manifestDuration, $zipDuration)

# Best-effort: close LabVIEW used for this build to avoid leaving it running.
$closeScript = Join-Path $repoRoot 'scripts\close-labview\Close_LabVIEW.ps1'
if (Test-Path -LiteralPath $closeScript -PathType Leaf) {
    try {
        Write-Host ("[info] Closing LabVIEW {0} ({1}-bit) after build..." -f $Package_LabVIEW_Version, $SupportedBitness)
        & pwsh -NoProfile -File $closeScript -Package_LabVIEW_Version $Package_LabVIEW_Version -SupportedBitness $SupportedBitness | Out-Null
    }
    catch {
        Write-Warning ("[info] Failed to close LabVIEW after build: {0}" -f $_.Exception.Message)
    }
}

$logStashScript = Join-Path $repoRoot 'scripts/log-stash/Write-LogStashEntry.ps1'
if (Test-Path -LiteralPath $logStashScript -PathType Leaf) {
    try {
        $durationMs = [int][Math]::Round(((Get-Date) - $script:StartTime).TotalMilliseconds,0)
        $attachments = @($manifestPath, $manifestCsvPath, $zipPath) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
        & $logStashScript `
            -RepositoryPath $repoRoot `
            -Category 'source-distribution' `
            -Label 'Build_Source_Distribution' `
            -LogPaths @() `
            -AttachmentPaths $attachments `
            -Status 'success' `
            -ProducerScript $PSCommandPath `
            -ProducerTask 'Build_Source_Distribution' `
            -ProducerArgs @{ RepositoryPath = $repoRoot; Package_LabVIEW_Version = $Package_LabVIEW_Version; SupportedBitness = $SupportedBitness } `
            -StartedAtUtc $script:StartTime.ToUniversalTime() `
            -DurationMs $durationMs | Out-Null
    }
    catch {
        Write-Warning ("[lvsd] Failed to write log-stash bundle: {0}" -f $_.Exception.Message)
    }
}

}
finally {
    Stop-Heartbeat
}
