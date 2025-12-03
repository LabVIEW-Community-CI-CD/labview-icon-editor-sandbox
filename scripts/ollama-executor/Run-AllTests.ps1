<#
.SYNOPSIS
  Master test orchestrator for running all Ollama executor tests.

.DESCRIPTION
  Unified test runner that executes all test suites in the correct order and generates
  comprehensive test reports. Supports fast mode for quick feedback and full mode for
  complete coverage.

.PARAMETER Mode
  Test mode: 'fast' (quick essential tests), 'full' (all tests), 'security' (security-focused),
  'performance' (benchmarks only)

.PARAMETER GenerateReport
  Generate HTML test report

.PARAMETER CI
  CI/CD mode - generates JUnit XML output and returns appropriate exit codes

.EXAMPLE
  # Quick test run
  pwsh -NoProfile -File scripts/ollama-executor/Run-AllTests.ps1 -Mode fast

  # Full test suite with report
  pwsh -NoProfile -File scripts/ollama-executor/Run-AllTests.ps1 -Mode full -GenerateReport

  # CI/CD mode
  pwsh -NoProfile -File scripts/ollama-executor/Run-AllTests.ps1 -Mode full -CI
#>

[CmdletBinding()]
param(
    [ValidateSet('fast', 'full', 'security', 'performance')]
    [string]$Mode = 'fast',
    
    [switch]$GenerateReport,
    
    [switch]$CI
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$startTime = Get-Date

Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Ollama Executor Test Orchestrator" -ForegroundColor Cyan
Write-Host "Mode: $Mode" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$testResults = @{
    mode = $Mode
    timestamp = $startTime.ToString('o')
    suites = @()
    summary = @{
        total = 0
        passed = 0
        failed = 0
        skipped = 0
        duration_seconds = 0
    }
}

function Invoke-TestSuite {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [switch]$Required,
        [string[]]$Modes = @('full')
    )
    
    # Check if test should run in current mode
    if ($Mode -ne 'full' -and $Modes -notcontains $Mode) {
        Write-Host "[$Name] Skipped (not in $Mode mode)" -ForegroundColor Gray
        $script:testResults.summary.skipped++
        return
    }
    
    Write-Host "[$Name] Running..." -ForegroundColor Yellow
    $suiteStart = Get-Date
    
    try {
        $output = & $ScriptPath 2>&1
        $exitCode = $LASTEXITCODE
        $suiteEnd = Get-Date
        $duration = ($suiteEnd - $suiteStart).TotalSeconds
        
        $passed = $exitCode -eq 0
        
        $suite = @{
            name = $Name
            script = $ScriptPath
            passed = $passed
            exit_code = $exitCode
            duration_seconds = [math]::Round($duration, 2)
            output = ($output | Out-String)
        }
        
        $script:testResults.suites += $suite
        $script:testResults.summary.total++
        
        if ($passed) {
            Write-Host "[$Name] ✓ PASSED ($([math]::Round($duration, 1))s)" -ForegroundColor Green
            $script:testResults.summary.passed++
        }
        else {
            Write-Host "[$Name] ✗ FAILED (exit code: $exitCode)" -ForegroundColor Red
            $script:testResults.summary.failed++
            
            if ($Required) {
                Write-Host "CRITICAL: Required test suite failed!" -ForegroundColor Red
            }
        }
    }
    catch {
        Write-Host "[$Name] ✗ ERROR: $_" -ForegroundColor Red
        $script:testResults.summary.failed++
        $script:testResults.summary.total++
        
        $suite = @{
            name = $Name
            script = $ScriptPath
            passed = $false
            exit_code = -1
            duration_seconds = 0
            error = $_.Exception.Message
        }
        $script:testResults.suites += $suite
    }
    
    Write-Host ""
}

# Test Suite Execution Plan

# Phase 1: Unit Tests (Always run, fast)
Invoke-TestSuite `
    -Name "Command Vetting" `
    -ScriptPath "$PSScriptRoot/Test-CommandVetting.ps1" `
    -Required `
    -Modes @('fast', 'full', 'security')

Invoke-TestSuite `
    -Name "Simulation Mode" `
    -ScriptPath "$PSScriptRoot/Test-SimulationMode.ps1" `
    -Required `
    -Modes @('fast', 'full')

# Phase 2: Security Tests (Important, run in security and full modes)
Invoke-TestSuite `
    -Name "Security Fuzzing" `
    -ScriptPath "$PSScriptRoot/Test-SecurityFuzzing.ps1" `
    -Modes @('full', 'security')

# Phase 3: Failure Tests (Medium duration, works in simulation mode)
if ($Mode -in @('full', 'fast')) {
    Invoke-TestSuite `
        -Name "Failure Handling" `
        -ScriptPath "$PSScriptRoot/Test-Failures.ps1" `
        -Modes @('fast', 'full')
}

# Phase 3b: Timeout Tests (Skip in fast mode - requires real execution)
if ($Mode -eq 'full') {
    Invoke-TestSuite `
        -Name "Timeout Handling" `
        -ScriptPath "$PSScriptRoot/Test-Timeout.ps1" `
        -Modes @('full')
}

# Phase 4: Conversation Scenarios (Can be slow)
if ($Mode -eq 'full') {
    Invoke-TestSuite `
        -Name "Conversation Scenarios" `
        -ScriptPath "$PSScriptRoot/Test-ConversationScenarios.ps1" `
        -Modes @('full')
}

# Phase 5: Full Integration (Slowest, only in full mode)
if ($Mode -eq 'full') {
    Invoke-TestSuite `
        -Name "Integration Tests" `
        -ScriptPath "$PSScriptRoot/Test-Integration.ps1" `
        -Modes @('full')
}

# Phase 6: Performance Benchmarks (Only in performance or full mode)
if ($Mode -in @('performance', 'full')) {
    Invoke-TestSuite `
        -Name "Performance Benchmarks" `
        -ScriptPath "$PSScriptRoot/Test-Performance.ps1" `
        -Modes @('performance', 'full')
}

$endTime = Get-Date
$testResults.summary.duration_seconds = [math]::Round(($endTime - $startTime).TotalSeconds, 2)

# Summary
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "Total Suites: $($testResults.summary.total)" -ForegroundColor White
Write-Host "Passed: $($testResults.summary.passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.summary.failed)" -ForegroundColor $(if ($testResults.summary.failed -eq 0) { "Green" } else { "Red" })
Write-Host "Skipped: $($testResults.summary.skipped)" -ForegroundColor Gray
Write-Host "Duration: $($testResults.summary.duration_seconds)s" -ForegroundColor White
Write-Host ""

# Generate Report
if ($GenerateReport -or $CI) {
    $reportDir = "reports/test-results"
    if (-not (Test-Path $reportDir)) {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    }
    
    # JSON Report
    $jsonReport = Join-Path $reportDir "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $testResults | ConvertTo-Json -Depth 10 | Set-Content $jsonReport
    Write-Host "JSON report saved: $jsonReport" -ForegroundColor Green
    
    # HTML Report (if not CI mode)
    if ($GenerateReport -and -not $CI) {
        $htmlReport = Join-Path $reportDir "test-results-$(Get-Date -Format 'yyyyMMdd-HHmmss').html"
        $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>Ollama Executor Test Results</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #333; }
        .summary { display: flex; gap: 20px; margin: 20px 0; }
        .metric { padding: 15px; background: #f0f0f0; border-radius: 5px; flex: 1; }
        .metric-value { font-size: 24px; font-weight: bold; }
        .passed { color: green; }
        .failed { color: red; }
        .suite { margin: 20px 0; padding: 15px; border: 1px solid #ddd; border-radius: 5px; }
        .suite.pass { border-left: 4px solid green; }
        .suite.fail { border-left: 4px solid red; }
        .suite-header { font-weight: bold; margin-bottom: 10px; }
        .output { background: #f9f9f9; padding: 10px; font-family: monospace; font-size: 12px; max-height: 300px; overflow-y: auto; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Ollama Executor Test Results</h1>
        <p>Mode: <strong>$Mode</strong> | Generated: $($startTime.ToString('yyyy-MM-dd HH:mm:ss'))</p>
        
        <div class="summary">
            <div class="metric">
                <div>Total Suites</div>
                <div class="metric-value">$($testResults.summary.total)</div>
            </div>
            <div class="metric">
                <div>Passed</div>
                <div class="metric-value passed">$($testResults.summary.passed)</div>
            </div>
            <div class="metric">
                <div>Failed</div>
                <div class="metric-value failed">$($testResults.summary.failed)</div>
            </div>
            <div class="metric">
                <div>Duration</div>
                <div class="metric-value">$($testResults.summary.duration_seconds)s</div>
            </div>
        </div>
        
        <h2>Test Suites</h2>
"@
        foreach ($suite in $testResults.suites) {
            $status = if ($suite.passed) { "pass" } else { "fail" }
            $statusIcon = if ($suite.passed) { "✓" } else { "✗" }
            $html += @"
        <div class="suite $status">
            <div class="suite-header">$statusIcon $($suite.name) ($($suite.duration_seconds)s)</div>
            <div>Script: $($suite.script)</div>
            <div>Exit Code: $($suite.exit_code)</div>
        </div>
"@
        }
        
        $html += @"
    </div>
</body>
</html>
"@
        $html | Set-Content $htmlReport
        Write-Host "HTML report saved: $htmlReport" -ForegroundColor Green
    }
    
    # JUnit XML for CI/CD
    if ($CI) {
        $junitXml = Join-Path $reportDir "junit-results.xml"
        $xml = "<?xml version='1.0' encoding='UTF-8'?>`n"
        $xml += "<testsuites tests='$($testResults.summary.total)' failures='$($testResults.summary.failed)' time='$($testResults.summary.duration_seconds)'>`n"
        $xml += "  <testsuite name='OllamaExecutorTests' tests='$($testResults.summary.total)' failures='$($testResults.summary.failed)' time='$($testResults.summary.duration_seconds)'>`n"
        
        foreach ($suite in $testResults.suites) {
            $xml += "    <testcase name='$($suite.name)' time='$($suite.duration_seconds)'>`n"
            if (-not $suite.passed) {
                $xml += "      <failure message='Test suite failed' type='TestFailure'>Exit code: $($suite.exit_code)</failure>`n"
            }
            $xml += "    </testcase>`n"
        }
        
        $xml += "  </testsuite>`n"
        $xml += "</testsuites>`n"
        $xml | Set-Content $junitXml
        Write-Host "JUnit XML saved: $junitXml" -ForegroundColor Green
    }
}

Write-Host ""

# Exit with appropriate code
if ($testResults.summary.failed -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "$($testResults.summary.failed) test suite(s) failed! ✗" -ForegroundColor Red
    exit 1
}
