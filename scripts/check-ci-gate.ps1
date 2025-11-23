[CmdletBinding()]
param(
    [string]$WorkflowFile = ".github/workflows/ci.yml",
    [string]$RepositoryPath,
    [switch]$Quiet,
    [switch]$ReturnRunId
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info($msg) { if (-not $Quiet) { Write-Host $msg } }

# Resolve repo path and SHA
$repo = if ($RepositoryPath) { $RepositoryPath } else { (Get-Location).ProviderPath }
try { $repo = (Resolve-Path -LiteralPath $repo -ErrorAction Stop).ProviderPath } catch {}

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw "git not found on PATH." }

try {
    $sha = git -C $repo rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($sha)) { throw "Unable to resolve HEAD SHA." }
    $sha = $sha.Trim()
} catch {
    throw "Unable to resolve HEAD SHA: $($_.Exception.Message)"
}

Write-Info "Checking CI gate for commit: $sha"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found. Install gh and ensure GH_TOKEN/GITHUB_TOKEN is available."
}

# Ensure gh has a token; prefer GH_TOKEN, fall back to GITHUB_TOKEN
if (-not $env:GH_TOKEN -and $env:GITHUB_TOKEN) {
    $env:GH_TOKEN = $env:GITHUB_TOKEN
}

try {
    gh auth status -h github.com 2>$null | Out-Null
}
catch {
    throw "gh auth status failed. Login with 'gh auth login' or set GH_TOKEN/GITHUB_TOKEN with repo access."
}

# Determine repo owner/name
try {
    $remoteUrl = git -C $repo remote get-url origin 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($remoteUrl)) { throw "No origin remote found." }
    $remoteUrl = $remoteUrl.Trim()
    if ($remoteUrl -match 'github\.com[:/](?<owner>[^/]+)/(?<name>[^/.]+)') {
        $owner = $Matches['owner']
        $name  = $Matches['name']
    } else {
        throw "Unable to parse owner/repo from origin URL: $remoteUrl"
    }
} catch {
    throw "Unable to determine repository owner/name: $($_.Exception.Message)"
}

$workflowPath = if ([System.IO.Path]::IsPathRooted($WorkflowFile)) { $WorkflowFile } else { (Join-Path $repo $WorkflowFile) }
if (-not (Test-Path -LiteralPath $workflowPath)) {
    throw "Workflow file not found: $workflowPath"
}

$workflowName = [System.IO.Path]::GetFileName($workflowPath)

# Query workflow runs for this SHA
Write-Info "Querying GitHub Actions for workflow '$workflowName' on $owner/$name..."
$json = gh api "/repos/$owner/$name/actions/workflows/$workflowName/runs" -f head_sha=$sha -F per_page=1 -q '.' 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($json)) {
    throw "Unable to query workflow runs via gh api. Ensure GH_TOKEN/GITHUB_TOKEN is set and gh is authenticated."
}

try {
    $data = $json | ConvertFrom-Json
} catch {
    throw "Failed to parse gh api response: $($_.Exception.Message)"
}

$runs = @($data.workflow_runs)
if (-not $runs -or $runs.Count -eq 0) {
    throw "No runs found for workflow '$workflowName' at commit $sha."
}

$run = $runs | Sort-Object created_at -Descending | Select-Object -First 1
Write-Info ("Found workflow run: id={0}, status={1}, conclusion={2}, event={3}" -f $run.id, $run.status, $run.conclusion, $run.event)

if ($run.status -ne 'completed' -or $run.conclusion -ne 'success') {
    throw ("CI gate failed: latest run for {0} is status={1}, conclusion={2} (run id {3}). Wait for a successful run before proceeding." -f $sha, $run.status, $run.conclusion, $run.id)
}

Write-Info "CI gate passed for commit $sha."
if ($ReturnRunId) {
    Write-Output $run.id
}
exit 0
