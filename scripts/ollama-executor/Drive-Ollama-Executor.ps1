<#
.SYNOPSIS
  Drives a lightweight Ollama executor loop: Ollama proposes PowerShell commands as JSON, this script runs them and feeds results back.

.USAGE
  pwsh -NoProfile -File scripts/ollama-executor/Drive-Ollama-Executor.ps1 `
    -Model llama3-8b-local `
    -RepoPath . `
    -Goal "Build Source Distribution LV2025 64-bit" `
    -MaxTurns 10

.NOTES
  - Ollama must be reachable at OLLAMA_HOST (defaults to http://localhost:11435)
  - Commands are executed with PowerShell from RepoPath
  - Ollama responses must be JSON: {"run":"<cmd>"} or {"done":true,"summary":"..."}
#>
[CmdletBinding()]
param(
    [Alias('Host')]
    [string]$Endpoint = $env:OLLAMA_HOST,
    [string]$Model = $env:OLLAMA_MODEL_TAG,
    [string]$RepoPath = ".",
    [string]$Goal = "Build Source Distribution LV2025 64-bit",
    [int]$MaxTurns = 10,
    [switch]$StopAfterFirstCommand,
    [string[]]$AllowedRuns = @("pwsh -NoProfile -File scripts/build-source-distribution/Build_Source_Distribution.ps1 -RepositoryPath . -Package_LabVIEW_Version 2025 -SupportedBitness 64"),
    [int]$CommandTimeoutSec = 0
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$repoFull = (Resolve-Path -LiteralPath $RepoPath).Path
$ollamaHost = if ([string]::IsNullOrWhiteSpace($Endpoint)) { "http://localhost:11435" } else { $Endpoint }
if ([string]::IsNullOrWhiteSpace($Model)) { throw "Model tag is required. Set OLLAMA_MODEL_TAG or pass -Model." }

$healthParams = @{
    Host            = $ollamaHost
    ModelTag        = $Model
    RequireModelTag = $true
}
& "$PSScriptRoot/check-ollama-endpoint.ps1" @healthParams
Write-Host ("Executor targeting {0} with model {1}" -f $ollamaHost, $Model)

$systemPrompt = @"
You are an executor agent. Always respond with JSON only.
Schema:
- To run a PowerShell command: {"run": "<command>"}
- To finish: {"done": true, "summary": "<short status>"}
Use PowerShell syntax. Keep commands short and safe. No prose.
After each run you will receive: {"result":{"exit":<int>,"stdout":"...","stderr":"..."}}
Respond again with either {"run":"..."} or {"done":true,"summary":"..."}.
"@

$messages = @(
    @{ role = "system"; content = $systemPrompt },
    @{ role = "user"; content = "Goal: $Goal" }
)

function Test-CommandAllowed {
    param([string]$Command)
    # Hard allowlist: exact matches only (case-insensitive)
    if ($AllowedRuns -and -not ($AllowedRuns | Where-Object { $_.ToLower() -eq $Command.ToLower() })) {
        return "Rejected: command not in allowlist."
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

function Invoke-Ollama {
    param([array]$Msgs)
    $body = @{
        model    = $Model
        messages = $Msgs
        stream   = $false
    } | ConvertTo-Json -Depth 6
    return Invoke-RestMethod -Uri "$($ollamaHost.TrimEnd('/'))/api/chat" -Method Post -ContentType "application/json" -Body $body
}

for ($turn = 1; $turn -le $MaxTurns; $turn++) {
    $resp = Invoke-Ollama -Msgs $messages
    $content = $resp.message.content
    $messages += @{ role = "assistant"; content = $content }

    $action = $null
    try {
        $action = $content | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        $messages += @{ role = "user"; content = 'Invalid JSON; respond with {"run":"cmd"} or {"done":true}' }
        continue
    }

    $hasDone = ($action -is [psobject] -and $action.PSObject.Properties['done'])
    if ($hasDone -and $action.done) {
        Write-Host ("[executor] Done: {0}" -f ($action.summary ?? "")) -ForegroundColor Green
        break
    }

    $hasRun = ($action -is [psobject] -and $action.PSObject.Properties['run'])
    if (-not $hasRun) {
        $messages += @{ role = "user"; content = 'Missing run field; respond with {"run":"cmd"}.' }
        continue
    }

    $cmd = $action.run
    Write-Host ("[executor] Turn {0}: {1}" -f $turn, $cmd)

    $vet = Test-CommandAllowed -Command $cmd
    if ($vet) {
        Write-Host ("[executor] {0}" -f $vet) -ForegroundColor Yellow
        $messages += @{ role = "user"; content = ("Command vetoed: {0}" -f $vet) }
        continue
    }

    $stdoutPath = Join-Path $env:TEMP "ollama-exec-out.txt"
    $stderrPath = Join-Path $env:TEMP "ollama-exec-err.txt"
    Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

    try {
        $proc = Start-Process -FilePath "pwsh" `
            -ArgumentList @("-NoProfile", "-Command", $cmd) `
            -WorkingDirectory $repoFull `
            -RedirectStandardOutput $stdoutPath `
            -RedirectStandardError $stderrPath `
            -NoNewWindow -PassThru

        $timedOut = $false
        if ($CommandTimeoutSec -gt 0) {
            $finished = $proc.WaitForExit($CommandTimeoutSec * 1000)
            if (-not $finished) {
                $timedOut = $true
                try { $proc.Kill() } catch {}
            }
        }
        else {
            $proc.WaitForExit() | Out-Null
        }

        $exitCode = if ($timedOut) { -1 } else { $proc.ExitCode }
    }
    catch {
        $exitCode = -1
        Set-Content -LiteralPath $stderrPath -Value $_.Exception.Message
    }

    $stdout = if (Test-Path $stdoutPath) { Get-Content -LiteralPath $stdoutPath -Raw } else { "" }
    $stderr = if (Test-Path $stderrPath) { Get-Content -LiteralPath $stderrPath -Raw } else { "" }
    if ($timedOut) {
        $stderr = "Timed out after ${CommandTimeoutSec}s`r`n$stderr"
    }
    Remove-Item $stdoutPath, $stderrPath -ErrorAction SilentlyContinue

    $result = @{
        result = @{
            exit   = $exitCode
            stdout = $stdout
            stderr = $stderr
        }
    } | ConvertTo-Json -Depth 5

    Write-Host ("[executor] Exit={0}" -f $exitCode)
    if ($stdout) { Write-Host "[stdout]" ; Write-Host $stdout }
    if ($stderr) { Write-Host "[stderr]" ; Write-Host $stderr }

    $messages += @{ role = "user"; content = $result }

    if ($StopAfterFirstCommand) {
        Write-Host "[executor] StopAfterFirstCommand set; exiting loop." -ForegroundColor Yellow
        break
    }
}

if ($turn -gt $MaxTurns) {
    Write-Host "[executor] Max turns reached without completion." -ForegroundColor Yellow
}
