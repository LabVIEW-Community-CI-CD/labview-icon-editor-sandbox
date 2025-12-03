<#
.SYNOPSIS
  Test suite for Ollama executor timeout and failure handling.

.DESCRIPTION
  Tests error scenarios including timeouts, network failures, malformed responses,
  and command execution failures.

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-TimeoutAndFailures.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

Write-Host "=== Ollama Executor Timeout and Failure Tests ===" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0

function Test-CommandTimeout {
    Write-Host "Test: Command Timeout" -ForegroundColor Yellow
    
    # Enable simulation mode with a delay longer than timeout
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "3000"  # 3 seconds
    $env:OLLAMA_HOST = "http://localhost:11436"
    
    # Start mock server
    $mockJob = Start-Job -ScriptBlock {
        & "$using:PSScriptRoot/MockOllamaServer.ps1" -Port 11436 -MaxRequests 10
    }
    
    try {
        Start-Sleep -Seconds 2  # Wait for server
        
        $tempRepo = if ($env:TEMP) { Join-Path $env:TEMP "timeout-test" } else { "/tmp/timeout-test" }
        New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
        
        # Run with very short timeout
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11436" `
            -Model "llama3-8b-local" `
            -RepoPath $tempRepo `
            -Goal "Test timeout" `
            -MaxTurns 2 `
            -CommandTimeoutSec 1 `
            -StopAfterFirstCommand `
            2>&1
        
        Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
        
        $outputStr = $output | Out-String
        
        # Should see timeout message or exit code -1
        if ($outputStr -match 'Timed out|Exit=-1') {
            Write-Host "  ✓ PASS - Timeout detected" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Timeout not detected" -ForegroundColor Red
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

function Test-OllamaUnreachable {
    Write-Host "Test: Ollama Server Unreachable" -ForegroundColor Yellow
    
    # Point to non-existent server
    $env:OLLAMA_HOST = "http://localhost:65432"  # Unlikely to be in use
    
    try {
        # Run executor - should fail fast
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:65432" `
            -Model "llama3-8b-local" `
            -RepoPath "." `
            -Goal "Test unreachable" `
            -MaxTurns 1 `
            2>&1
        
        $outputStr = $output | Out-String
        
        # Should fail during health check
        if ($outputStr -match 'Failed to reach Ollama|Connection refused|unreachable') {
            Write-Host "  ✓ PASS - Unreachable server detected" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Should have failed to connect" -ForegroundColor Red
            $script:failCount++
        }
    }
    catch {
        # Exception is acceptable for this test
        if ($_.Exception.Message -match 'Failed to reach|Connection|unreachable') {
            Write-Host "  ✓ PASS - Exception thrown as expected" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Unexpected exception: $_" -ForegroundColor Red
            $script:failCount++
        }
    }
    
    Write-Host ""
}

function Test-SimulatedCommandFailure {
    Write-Host "Test: Simulated Command Failure" -ForegroundColor Yellow
    
    # Enable simulation with forced failure
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_FAIL = "true"
    $env:OLLAMA_SIM_EXIT = "42"
    $env:OLLAMA_SIM_DELAY_MS = "10"
    $env:OLLAMA_HOST = "http://localhost:11436"
    
    $mockJob = Start-Job -ScriptBlock {
        & "$using:PSScriptRoot/MockOllamaServer.ps1" -Port 11436 -MaxRequests 10
    }
    
    try {
        Start-Sleep -Seconds 2
        
        $tempRepo = if ($env:TEMP) { Join-Path $env:TEMP "fail-test" } else { "/tmp/fail-test" }
        New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
        
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11436" `
            -Model "llama3-8b-local" `
            -RepoPath $tempRepo `
            -Goal "Test failure" `
            -MaxTurns 2 `
            -StopAfterFirstCommand `
            2>&1
        
        Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
        
        $outputStr = $output | Out-String
        
        # Should see exit code 42
        if ($outputStr -match 'Exit=42') {
            Write-Host "  ✓ PASS - Command failure detected with correct exit code" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Expected exit code 42 not found" -ForegroundColor Red
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_FAIL -ErrorAction SilentlyContinue
        Remove-Item Env:\OLLAMA_SIM_EXIT -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

function Test-StopAfterFirstCommand {
    Write-Host "Test: StopAfterFirstCommand Flag" -ForegroundColor Yellow
    
    $env:OLLAMA_EXECUTOR_MODE = "sim"
    $env:OLLAMA_SIM_DELAY_MS = "10"
    $env:OLLAMA_HOST = "http://localhost:11436"
    
    $mockJob = Start-Job -ScriptBlock {
        & "$using:PSScriptRoot/MockOllamaServer.ps1" -Port 11436 -MaxRequests 10
    }
    
    try {
        Start-Sleep -Seconds 2
        
        $tempRepo = if ($env:TEMP) { Join-Path $env:TEMP "stop-test" } else { "/tmp/stop-test" }
        New-Item -ItemType Directory -Path $tempRepo -Force | Out-Null
        
        $output = & "$PSScriptRoot/Drive-Ollama-Executor.ps1" `
            -Endpoint "http://localhost:11436" `
            -Model "llama3-8b-local" `
            -RepoPath $tempRepo `
            -Goal "Test stop after first" `
            -MaxTurns 10 `
            -StopAfterFirstCommand `
            2>&1
        
        Remove-Item $tempRepo -Recurse -Force -ErrorAction SilentlyContinue
        
        $outputStr = $output | Out-String
        
        # Should stop after first command
        $commandMatches = [regex]::Matches($outputStr, '\[executor\] Exit=')
        if ($commandMatches.Count -eq 1 -and $outputStr -match 'StopAfterFirstCommand') {
            Write-Host "  ✓ PASS - Stopped after first command" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ FAIL - Did not stop correctly (commands: $($commandMatches.Count))" -ForegroundColor Red
            $script:failCount++
        }
    }
    finally {
        Stop-Job $mockJob -ErrorAction SilentlyContinue
        Remove-Job $mockJob -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host ""
}

# Run all tests
Test-OllamaUnreachable
Test-SimulatedCommandFailure
Test-StopAfterFirstCommand
Test-CommandTimeout

# Clean up environment
Remove-Item Env:\OLLAMA_EXECUTOR_MODE -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_SIM_DELAY_MS -ErrorAction SilentlyContinue
Remove-Item Env:\OLLAMA_HOST -ErrorAction SilentlyContinue

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All timeout/failure tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some timeout/failure tests failed! ✗" -ForegroundColor Red
    exit 1
}
