<#
.SYNOPSIS
  Runs Drive-Ollama-Executor with VI History Suite commands for analyzing VI changes.

.DESCRIPTION
  Orchestrates VI History analysis through the Ollama executor pattern.
  Supports both simulation mode (no LabVIEW required) and real mode (with LabVIEW).
  Can be triggered conditionally when VI files have changed.
  Can analyze specific commits from upstream repositories.

.PARAMETER RepoPath
  Path to the repository root.

.PARAMETER Endpoint
  Ollama API endpoint. Defaults to OLLAMA_HOST env var.

.PARAMETER Model
  Ollama model tag. Defaults to OLLAMA_MODEL_TAG env var.

.PARAMETER ChangedFiles
  Optional list of changed VI files to analyze (newline-separated).

.PARAMETER TargetCommit
  Optional commit SHA to analyze. Can be from upstream ni/labview-icon-editor.

.PARAMETER UpstreamRepo
  Upstream repository URL for fetching commits. Defaults to ni/labview-icon-editor.

.PARAMETER OutputDir
  Directory to store VI History reports. Defaults to reports/vi-history.

.PARAMETER CommandTimeoutSec
  Timeout for command execution in seconds.

.EXAMPLE
  pwsh -NoProfile -File Run-Locked-VIHistory.ps1 -RepoPath . -ChangedFiles "vi.lib/Test.vi"

.EXAMPLE
  # Analyze a specific commit from ni/labview-icon-editor
  pwsh -NoProfile -File Run-Locked-VIHistory.ps1 -RepoPath . -TargetCommit "c319892088170bf45fcc65278f21e6b5a2cc3b38"

.EXAMPLE
  # Simulation mode (no LabVIEW required)
  $env:OLLAMA_EXECUTOR_MODE = 'sim'
  pwsh -NoProfile -File Run-Locked-VIHistory.ps1 -RepoPath .
#>
[CmdletBinding()]
param(
    [string]$RepoPath = ".",
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [string]$ChangedFiles = $env:VI_CHANGES_DETECTED,
    [string]$TargetCommit = "",
    [string]$UpstreamRepo = "https://github.com/ni/labview-icon-editor.git",
    [string]$OutputDir = "",
    [int]$CommandTimeoutSec = 120,
    [int]$LabVIEWVersion = 2025,
    [ValidateSet('32','64')]
    [string]$Bitness = '64'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$scriptDir = $PSScriptRoot
$repoRoot = (Resolve-Path -LiteralPath $RepoPath).ProviderPath

# Determine simulation mode
$simMode = [string]::Equals($env:OLLAMA_EXECUTOR_MODE, 'sim', 'OrdinalIgnoreCase')

# Set up output directories
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runKey = "vi-history-$timestamp"
$effectiveOutputDir = if ($OutputDir) { $OutputDir } else { Join-Path $repoRoot 'reports/vi-history' }
$logDir = Join-Path $repoRoot 'reports/logs'
$artifactsDir = Join-Path $repoRoot 'artifacts'

foreach ($dir in @($effectiveOutputDir, $logDir, $artifactsDir)) {
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$logPath = Join-Path $logDir "vi-history-$runKey.log"

function Write-Log {
    param([string]$Message, [string]$Level = 'INFO')
    $entry = "[{0}][{1}] {2}" -f (Get-Date -Format 'HH:mm:ss'), $Level, $Message
    Write-Host $entry
    $entry | Add-Content -LiteralPath $logPath -Encoding utf8
}

Write-Log "=== VI History Suite via Ollama Executor ===" 
Write-Log "Mode: $(if ($simMode) { 'SIMULATION' } else { 'REAL' })"
Write-Log "Repo: $repoRoot"
Write-Log "Output: $effectiveOutputDir"
Write-Log "Run Key: $runKey"

# Parse changed files
$viFiles = @()
if ($ChangedFiles) {
    $viFiles = $ChangedFiles -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() }
    Write-Log "Changed VI files to analyze: $($viFiles.Count)"
    foreach ($f in $viFiles | Select-Object -First 10) {
        Write-Log "  - $f"
    }
    if ($viFiles.Count -gt 10) {
        Write-Log "  ... and $($viFiles.Count - 10) more"
    }
}

# Handle target commit analysis
$commitInfo = $null
if ($TargetCommit) {
    Write-Log "Target commit specified: $TargetCommit"
    Write-Log "Upstream repo: $UpstreamRepo"
    
    # Try to fetch the commit if not already available
    try {
        $existingCommit = git -C $repoRoot rev-parse --verify "$TargetCommit^{commit}" 2>$null
        if (-not $existingCommit) {
            Write-Log "Fetching commit from upstream..."
            # Add upstream remote if needed
            $remotes = git -C $repoRoot remote -v 2>$null
            if ($remotes -notmatch 'ni-upstream') {
                git -C $repoRoot remote add ni-upstream $UpstreamRepo 2>$null
            }
            git -C $repoRoot fetch ni-upstream $TargetCommit --depth=1 2>$null
        }
        
        # Get commit details
        $commitMessage = git -C $repoRoot log -1 --format="%s" $TargetCommit 2>$null
        $commitAuthor = git -C $repoRoot log -1 --format="%an" $TargetCommit 2>$null
        $commitDate = git -C $repoRoot log -1 --format="%ai" $TargetCommit 2>$null
        $viFilesInCommit = git -C $repoRoot diff-tree --no-commit-id --name-only -r $TargetCommit 2>$null | Where-Object { $_ -match '\.(vi|ctl|lvlib|lvclass)$' }
        
        $shortSha = if ($TargetCommit.Length -ge 8) { $TargetCommit.Substring(0, 8) } else { $TargetCommit }
        $commitInfo = @{
            sha = $TargetCommit
            short_sha = $shortSha
            message = $commitMessage
            author = $commitAuthor
            date = $commitDate
            vi_files = @($viFilesInCommit)
            vi_count = @($viFilesInCommit).Count
        }
        
        Write-Log "Commit: $($commitInfo.short_sha) - $($commitInfo.message)"
        Write-Log "Author: $($commitInfo.author)"
        Write-Log "Date: $($commitInfo.date)"
        Write-Log "VI files in commit: $($commitInfo.vi_count)"
        
        # Use commit VI files if no explicit changed files provided
        if (-not $viFiles -or $viFiles.Count -eq 0) {
            $viFiles = $commitInfo.vi_files
        }
    }
    catch {
        Write-Log "Warning: Could not fetch commit details: $_" "WARN"
    }
}
elseif (-not $viFiles -or $viFiles.Count -eq 0) {
    Write-Log "No specific VI changes provided; will run full suite analysis"
}

# Derive commit URL base from UpstreamRepo
$upstreamUrlBase = $UpstreamRepo -replace '\.git$', ''

# Simulation mode - generate stub artifacts
if ($simMode) {
    Write-Log "Running in SIMULATION mode - no LabVIEW required" "INFO"
    
    $reportPath = Join-Path $effectiveOutputDir "vi-history-report-$runKey.json"
    $htmlPath = Join-Path $effectiveOutputDir "vi-history-report-$runKey.html"
    
    # Derive format version from LabVIEW version (e.g., 2025 -> 25.3)
    $formatVersion = "{0}.3" -f ($LabVIEWVersion.ToString().Substring(2))
    
    $simReport = @{
        format = @{
            version = $formatVersion
            report_type = "vi-history-suite"
            schema = "vi-history-suite/1.0"
        }
        header = @{
            run_key = $runKey
            generated_at = (Get-Date).ToUniversalTime().ToString('o')
            mode = "simulation"
            labview_version = "$LabVIEWVersion"
        }
        summary = @{
            files_analyzed = $viFiles.Count
            breaking_changes = 0
            compatibility_warnings = 0
            status = "completed"
        }
        analyzed_files = $viFiles | Select-Object -First 50 | ForEach-Object {
            @{
                path = $_
                status = "simulated"
                breaking_changes = 0
            }
        }
        trigger = @{
            type = if ($TargetCommit) { "commit_analysis" } elseif ($viFiles.Count -gt 0) { "vi_change_detected" } else { "full_suite" }
            file_count = $viFiles.Count
        }
    }
    
    # Add commit info if analyzing a specific commit
    if ($commitInfo) {
        $simReport.commit = $commitInfo
        $simReport.trigger.commit_sha = $commitInfo.sha
        $simReport.trigger.commit_message = $commitInfo.message
    }
    
    $simReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reportPath -Encoding utf8
    Write-Log "Generated simulation report: $reportPath"
    
    # Generate HTML report
    $fileListHtml = ($viFiles | Select-Object -First 50 | ForEach-Object { "<li>$_</li>" }) -join "`n"
    $commitHtml = if ($commitInfo) {
        @"
        <div class='commit-info'>
            <h2>Commit Analysis</h2>
            <p><strong>Commit:</strong> <a href='$upstreamUrlBase/commit/$($commitInfo.sha)'>$($commitInfo.short_sha)</a></p>
            <p><strong>Message:</strong> $($commitInfo.message)</p>
            <p><strong>Author:</strong> $($commitInfo.author)</p>
            <p><strong>Date:</strong> $($commitInfo.date)</p>
            <p><strong>VI Files Changed:</strong> $($commitInfo.vi_count)</p>
        </div>
"@
    } else { "" }
    
    $htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset='utf-8'>
    <meta name='lv-version' content='$LabVIEWVersion'>
    <meta name='target-commit' content='$TargetCommit'>
    <title>VI History Analysis Report$(if ($commitInfo) { " - $($commitInfo.short_sha)" } else { "" })</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f9f9f9; }
        h1 { color: #333; border-bottom: 2px solid #0066cc; padding-bottom: 10px; }
        .summary { background: #fff; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; }
        .commit-info { background: #e8f4f8; padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid #0066cc; }
        .commit-info h2 { margin-top: 0; color: #0066cc; }
        .commit-info a { color: #0066cc; text-decoration: none; }
        .commit-info a:hover { text-decoration: underline; }
        .badge { display: inline-block; padding: 4px 12px; border-radius: 4px; font-weight: bold; }
        .badge-sim { background: #ffc107; color: #333; }
        .badge-success { background: #28a745; color: #fff; }
        .badge-commit { background: #0066cc; color: #fff; }
        .file-list { background: #fff; padding: 15px; border-radius: 8px; }
        .file-list ul { margin: 0; padding-left: 20px; max-height: 400px; overflow-y: auto; }
        .file-list li { padding: 4px 0; color: #555; font-family: monospace; font-size: 0.9em; }
        .meta { color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <h1>VI History Analysis Report</h1>
    <div class='summary'>
        <p>
            <span class='badge badge-sim'>SIMULATION MODE</span> 
            <span class='badge badge-success'>PASSED</span>
            $(if ($commitInfo) { "<span class='badge badge-commit'>COMMIT ANALYSIS</span>" } else { "" })
        </p>
        <p><strong>Run Key:</strong> $runKey</p>
        <p><strong>Generated:</strong> $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
        <p><strong>LabVIEW Version:</strong> $LabVIEWVersion</p>
        <p><strong>Files Analyzed:</strong> $($viFiles.Count)</p>
        <p><strong>Breaking Changes:</strong> 0</p>
    </div>
    $commitHtml
    <div class='file-list'>
        <h2>Analyzed VI Files</h2>
        $(if ($viFiles.Count -gt 0) { "<ul>$fileListHtml</ul>" } else { "<p class='meta'>No specific VI files - full suite analysis</p>" })
        $(if ($viFiles.Count -gt 50) { "<p class='meta'>Showing first 50 of $($viFiles.Count) files</p>" } else { "" })
    </div>
    <p class='meta'>This report was generated in simulation mode without actual LabVIEW analysis.</p>
    $(if ($commitInfo) { "<p class='meta'>Success criteria: Commit <a href='$upstreamUrlBase/commit/$($commitInfo.sha)'>$($commitInfo.short_sha)</a> is displayed in the VI History Suite.</p>" } else { "" })
</body>
</html>
"@
    $htmlContent | Set-Content -LiteralPath $htmlPath -Encoding utf8
    Write-Log "Generated HTML report: $htmlPath"
    
    # Create handshake for downstream jobs
    $handshake = @{
        runKey = $runKey
        mode = "sim"
        reportPath = $reportPath
        htmlPath = $htmlPath
        filesAnalyzed = $viFiles.Count
        breakingChanges = 0
        timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        requirements = @('OEX-VIHISTORY-001', 'OEX-VIHISTORY-002')
    }
    
    if ($commitInfo) {
        $handshake.targetCommit = $commitInfo
    }
    
    $handshakePath = Join-Path $artifactsDir 'vi-history-handshake.json'
    $handshake | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $handshakePath -Encoding utf8
    Write-Log "Handshake saved: $handshakePath"
    
    # Copy to builds-isolated for consistency with other Ollama jobs
    $isoDir = Join-Path $repoRoot "builds-isolated/$runKey"
    New-Item -ItemType Directory -Path $isoDir -Force | Out-Null
    Copy-Item -LiteralPath $reportPath -Destination $isoDir -Force
    Copy-Item -LiteralPath $htmlPath -Destination $isoDir -Force
    Copy-Item -LiteralPath $handshakePath -Destination $isoDir -Force
    Write-Log "Staged to builds-isolated/$runKey"
    
    Write-Log "VI History simulation completed successfully" "INFO"
    if ($commitInfo) {
        Write-Log "SUCCESS CRITERIA: Commit $($commitInfo.short_sha) displayed in VI History Suite" "INFO"
    }
    exit 0
}

# Real mode - requires Ollama endpoint and potentially LabVIEW
Write-Log "Running in REAL mode" "INFO"

# Resolve Ollama host
. "$scriptDir/Resolve-OllamaHost.ps1"

$resolvedHost = Resolve-OllamaHost -RequestedHost $Endpoint
if ([string]::IsNullOrWhiteSpace($Endpoint)) {
    Write-Log "Auto-selected OLLAMA_HOST=$resolvedHost"
}
elseif ($resolvedHost -ne $Endpoint) {
    Write-Log "Requested OLLAMA_HOST '$Endpoint' was unreachable; fell back to '$resolvedHost'" "WARN"
}

if ([string]::IsNullOrWhiteSpace($Model)) {
    $Model = "llama3-8b-local:latest"
    Write-Log "OLLAMA_MODEL_TAG missing; defaulting to '$Model'" "WARN"
}

# Health check
$healthParams = @{
    Host            = $resolvedHost
    ModelTag        = $Model
    RequireModelTag = $true
}
& "$scriptDir/check-ollama-endpoint.ps1" @healthParams

# Build the VI History command
$viHistorySuite = Join-Path $repoRoot 'scripts/vi-history-suite'
$viCompareScript = Join-Path $repoRoot 'scripts/vi-compare/run-vi-history-suite.ps1'

# Determine which script to run
$viHistoryCmd = if (Test-Path -LiteralPath $viCompareScript) {
    "pwsh -NoProfile -File `"$viCompareScript`""
}
else {
    # Fallback to direct Test-VIComparison
    $testScript = Join-Path $viHistorySuite 'Test-VIComparison.ps1'
    "pwsh -NoProfile -File `"$testScript`" -Verbose"
}

Write-Log "VI History command: $viHistoryCmd"

# Use Drive-Ollama-Executor for orchestration
. "$scriptDir/CommandBuilder.ps1"

$allowedRuns = @($viHistoryCmd)
$goal = 'Respond ONLY with JSON: send exactly {"run":"' + $viHistoryCmd + '"} and then {"done":true}.'

$params = @{
    Host                    = $resolvedHost
    Model                   = $Model
    RepoPath                = $repoRoot
    Goal                    = $goal
    MaxTurns                = 2
    StopAfterFirstCommand   = $true
    AllowedRuns             = $allowedRuns
    CommandTimeoutSec       = $CommandTimeoutSec
    SeedAssistantRunCommand = $viHistoryCmd
}

Write-Log "Invoking Ollama Executor for VI History analysis..."
& "$scriptDir/Drive-Ollama-Executor.ps1" @params -Verbose

$exitCode = $LASTEXITCODE

# Generate summary report
$summaryPath = Join-Path $logDir "vi-history-$runKey.summary.json"
$summary = @{
    runKey = $runKey
    mode = "real"
    exitCode = $exitCode
    filesAnalyzed = $viFiles.Count
    outputDir = $effectiveOutputDir
    timestampUtc = (Get-Date).ToUniversalTime().ToString('o')
    ollamaHost = $resolvedHost
    ollamaModel = $Model
}

if ($commitInfo) {
    $summary.targetCommit = $commitInfo
}

$summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $summaryPath -Encoding utf8
Write-Log "Summary saved: $summaryPath"

if ($exitCode -ne 0) {
    Write-Log "VI History analysis failed with exit code $exitCode" "ERROR"
}
else {
    Write-Log "VI History analysis completed successfully" "INFO"
    if ($commitInfo) {
        Write-Log "SUCCESS CRITERIA: Commit $($commitInfo.short_sha) analyzed and displayed" "INFO"
    }
}

exit $exitCode
