<#
.SYNOPSIS
  Test suite for Ollama executor command vetting logic.

.DESCRIPTION
  Validates the Test-CommandAllowed function that enforces security controls:
  - Allowlist matching
  - Pattern validation (must start with pwsh -NoProfile -File scripts/)
  - Forbidden token detection
  - Edge cases and security scenarios

.EXAMPLE
  pwsh -NoProfile -File scripts/ollama-executor/Test-CommandVetting.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

# Source the vetting function from Drive-Ollama-Executor.ps1
# We extract just the function for testing
function Test-CommandAllowed {
    param(
        [string]$Command,
        [string[]]$AllowedRuns = @()
    )
    
    # Hard allowlist: exact matches only (case-insensitive)
    if ($AllowedRuns -and $AllowedRuns.Count -gt 0) {
        $matched = $AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() }
        if (-not $matched) {
            return "Rejected: command not in allowlist."
        }
    }

    # Allow only repo scripts invoked via pwsh -NoProfile -File scripts/...
    $allowedPattern = '^pwsh\s+-NoProfile\s+-File\s+scripts[\\/][\w\-.\\/]+\.ps1\b'
    if (-not ($Command -match $allowedPattern)) {
        return "Rejected: command must start with 'pwsh -NoProfile -File scripts/...ps1'"
    }

    # Forbid dangerous tokens
    $forbidden = @('rm ', 'del ', 'Remove-Item', 'Format-',
                   'Invoke-WebRequest', 'curl ', 'Start-Process', 'shutdown', 'reg ', 'sc ',
                   '..\')
    foreach ($tok in $forbidden) {
        if ($Command -like "*$tok*") {
            return "Rejected: contains forbidden token '$tok'"
        }
    }
    return $null
}

Write-Host "=== Ollama Executor Command Vetting Test Suite ===" -ForegroundColor Cyan
Write-Host ""

$passCount = 0
$failCount = 0

function Assert-Accepted {
    param([string]$Command, [string]$TestName, [string[]]$AllowedRuns = @())
    $result = Test-CommandAllowed -Command $Command -AllowedRuns $AllowedRuns
    if ($null -eq $result) {
        Write-Host "  ✓ $TestName" -ForegroundColor Green
        $script:passCount++
    }
    else {
        Write-Host "  ✗ $TestName - Expected acceptance, got: $result" -ForegroundColor Red
        $script:failCount++
    }
}

function Assert-Rejected {
    param([string]$Command, [string]$TestName, [string]$ExpectedReason, [string[]]$AllowedRuns = @())
    $result = Test-CommandAllowed -Command $Command -AllowedRuns $AllowedRuns
    if ($null -ne $result) {
        if ($result -like "*$ExpectedReason*") {
            Write-Host "  ✓ $TestName" -ForegroundColor Green
            $script:passCount++
        }
        else {
            Write-Host "  ✗ $TestName - Expected reason '$ExpectedReason', got: $result" -ForegroundColor Red
            $script:failCount++
        }
    }
    else {
        Write-Host "  ✗ $TestName - Expected rejection, but command was accepted" -ForegroundColor Red
        $script:failCount++
    }
}

# Test Group 1: Valid Commands (should be accepted)
Write-Host "Test Group 1: Valid Commands" -ForegroundColor Yellow

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64" `
    -TestName "Valid source distribution build command"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/ppl-from-sd/Build_Ppl_From_SourceDistribution.ps1 -RepositoryPath ." `
    -TestName "Valid PPL build command"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1" `
    -TestName "Valid command with minimal arguments"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/sub-dir/nested-script.ps1 -Param Value" `
    -TestName "Valid command with nested script path"

Write-Host ""

# Test Group 2: Allowlist Enforcement
Write-Host "Test Group 2: Allowlist Enforcement" -ForegroundColor Yellow

$allowlist = @("pwsh -NoProfile -File scripts/allowed-script.ps1")

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/allowed-script.ps1" `
    -TestName "Exact match in allowlist" `
    -AllowedRuns $allowlist

Assert-Accepted `
    -Command "PWSH -NoProfile -File scripts/allowed-script.ps1" `
    -TestName "Case-insensitive allowlist match" `
    -AllowedRuns $allowlist

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/other-script.ps1" `
    -TestName "Not in allowlist" `
    -ExpectedReason "not in allowlist" `
    -AllowedRuns $allowlist

Write-Host ""

# Test Group 3: Pattern Validation
Write-Host "Test Group 3: Pattern Validation" -ForegroundColor Yellow

Assert-Rejected `
    -Command "powershell -File scripts/test.ps1" `
    -TestName "Wrong PowerShell executable name" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -File scripts/test.ps1" `
    -TestName "Missing -NoProfile flag" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile scripts/test.ps1" `
    -TestName "Missing -File flag" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile -File other/test.ps1" `
    -TestName "Not in scripts/ directory" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.txt" `
    -TestName "Not a .ps1 file" `
    -ExpectedReason "must start with"

Write-Host ""

# Test Group 4: Forbidden Tokens
Write-Host "Test Group 4: Forbidden Tokens" -ForegroundColor Yellow

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Command 'rm file.txt'" `
    -TestName "Contains 'rm ' token" `
    -ExpectedReason "forbidden token 'rm '"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Command 'del file.txt'" `
    -TestName "Contains 'del ' token" `
    -ExpectedReason "forbidden token 'del '"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; Remove-Item file.txt" `
    -TestName "Contains 'Remove-Item' token" `
    -ExpectedReason "forbidden token 'Remove-Item'"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Param 'Format-Volume'" `
    -TestName "Contains 'Format-' token" `
    -ExpectedReason "forbidden token 'Format-'"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; Invoke-WebRequest http://evil.com" `
    -TestName "Contains 'Invoke-WebRequest' token" `
    -ExpectedReason "forbidden token 'Invoke-WebRequest'"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; curl http://evil.com" `
    -TestName "Contains 'curl ' token" `
    -ExpectedReason "forbidden token 'curl '"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; Start-Process cmd.exe" `
    -TestName "Contains 'Start-Process' token" `
    -ExpectedReason "forbidden token 'Start-Process'"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; shutdown /s" `
    -TestName "Contains 'shutdown' token" `
    -ExpectedReason "forbidden token 'shutdown'"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/../other/test.ps1" `
    -TestName "Contains parent directory '..\' token" `
    -ExpectedReason "forbidden token '..\''"

Write-Host ""

# Test Group 5: Edge Cases
Write-Host "Test Group 5: Edge Cases" -ForegroundColor Yellow

Assert-Rejected `
    -Command "" `
    -TestName "Empty command" `
    -ExpectedReason "must start with"

Assert-Rejected `
    -Command "pwsh -NoProfile -File scripts/test.ps1; pwsh -NoProfile -File scripts/other.ps1" `
    -TestName "Multiple commands chained" `
    -ExpectedReason "must start with"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/test.ps1 -Param 'value with spaces' -Flag" `
    -TestName "Command with spaces in parameter values"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/my-script-name.ps1" `
    -TestName "Command with hyphens in script name"

Assert-Accepted `
    -Command "pwsh -NoProfile -File scripts/MyScript123.ps1" `
    -TestName "Command with mixed case and numbers"

Write-Host ""

# Summary
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $passCount" -ForegroundColor Green
Write-Host "Failed: $failCount" -ForegroundColor $(if ($failCount -eq 0) { "Green" } else { "Red" })
Write-Host ""

if ($failCount -eq 0) {
    Write-Host "All tests passed! ✓" -ForegroundColor Green
    exit 0
}
else {
    Write-Host "Some tests failed! ✗" -ForegroundColor Red
    exit 1
}
