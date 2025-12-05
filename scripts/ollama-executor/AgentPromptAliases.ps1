[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Keyword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Map single-word keywords to full agent prompts.
$aliases = @{
    sd2025 = @"
Run the locked Source Distribution build via the Ollama executor (sim or real).
- Preferred: simulation (OLLAMA_EXECUTOR_MODE=sim) with mock host http://localhost:11436.
- Command (sim):
  pwsh -NoProfile -File scripts/ollama-executor/Run-Locked-SourceDistribution.ps1 -RepoPath . -Endpoint http://localhost:11436 -Model llama3-8b-local -LabVIEWVersion 2025 -Bitness 64 -CommandTimeoutSec 900
- Real: switch Endpoint to http://localhost:11435 and clear OLLAMA_EXECUTOR_MODE.
- Handshake: artifacts/labview-icon-api-handshake.json (validated by workflow action).
"@

    pkgbuild = @"
Run the locked Package Build via the Ollama executor (sim or real).
- Preferred: simulation first (mock host http://localhost:11436).
- Command (sim):
  pwsh -NoProfile -File scripts/ollama-executor/Run-Locked-PackageBuild.ps1 -RepoPath . -Endpoint http://localhost:11436 -Model llama3-8b-local -CommandTimeoutSec 600
- Real: use http://localhost:11435 and clear OLLAMA_EXECUTOR_MODE.
- Handshake: artifacts/labview-icon-api-handshake.json.
"@

    localsdppl = @"
Run the locked Local SD → PPL pipeline via the Ollama executor.
- Command (sim):
  pwsh -NoProfile -File scripts/ollama-executor/Run-Locked-LocalSdPpl.ps1 -RepoPath . -Endpoint http://localhost:11436 -Model llama3-8b-local -CommandTimeoutSec 1800
- Real: use http://localhost:11435 and clear OLLAMA_EXECUTOR_MODE.
- Produces Source Distribution + PPL artifacts; handshake emitted.
"@

    reset_sd = @"
Reset the Source Distribution workspace via the locked executor (orchestration reset-source-dist).
- Command (sim):
  pwsh -NoProfile -File scripts/ollama-executor/Run-Locked-ResetSourceDistribution.ps1 -RepoPath . -Endpoint http://localhost:11436 -Model llama3-8b-local -CommandTimeoutSec 600
- Real: http://localhost:11435 with OLLAMA_EXECUTOR_MODE cleared; requires seed image.
- Emits reset summary to builds/reports/source-dist-reset.json and archives existing outputs.
"@

    seed2021 = @"
Create a seeded branch targeting LabVIEW 2021 Q1 64-bit using the vendored Seed image.
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From develop, run:
  pwsh -NoProfile -File scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2021 -LabVIEWMinor 0 -Bitness 64 -BaseBranch develop
- Push the resulting branch (seed/lv2021q1-64bit-<timestamp>) to origin.
- Report the branch name and commit that bumped the VIPB.
"@

    seed2024q3 = @"
Create a seeded branch targeting LabVIEW 2024 Q3 64-bit using the vendored Seed image.
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From develop, run:
  pwsh -NoProfile -File scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2024 -LabVIEWMinor 3 -Bitness 64 -BaseBranch develop
- Push the resulting branch (seed/lv2024q3-64bit-<timestamp>) to origin.
- Report the branch name and commit that bumped the VIPB.
"@

    seedlatest = @"
Create a seeded branch for the latest LabVIEW version we support (update the parameters as needed).
- Default: LabVIEW 2025 Q3 64-bit.
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From develop, run:
  pwsh -NoProfile -File scripts/labview/create-seeded-branch.ps1 -LabVIEWVersion 2025 -LabVIEWMinor 3 -Bitness 64 -BaseBranch develop
- Push the resulting branch (seed/lv2025q3-64bit-<timestamp>) to origin.
- Report the branch name and commit that bumped the VIPB.
"@

    vipbparse = @"
Parse and round-trip the VIPB using the Seed container (for troubleshooting).
- Ensure SEED_IMAGE is set (defaults to seed:latest; build locally if missing).
- From repo root:
  docker run --rm --entrypoint /usr/local/bin/vipb2json -v ""${PWD}:/repo"" -w /repo $env:SEED_IMAGE --input Tooling/deployment/seed.vipb --output Tooling/deployment/seed.vipb.json
  docker run --rm --entrypoint /usr/local/bin/json2vipb -v ""${PWD}:/repo"" -w /repo $env:SEED_IMAGE --input Tooling/deployment/seed.vipb.json --output Tooling/deployment/seed.vipb
- Report success or any errors.
"@

    vihistory = @"
Run the VI History Suite via the locked executor to analyze VI changes.
- Command (sim):
  pwsh -NoProfile -File scripts/ollama-executor/Run-Locked-VIHistory.ps1 -RepoPath . -Endpoint http://localhost:11436 -Model llama3-8b-local -CommandTimeoutSec 180
- Real: switch to http://localhost:11435 and clear OLLAMA_EXECUTOR_MODE.
- Outputs reports to reports/vi-history/ and writes artifacts/vi-history-handshake.json.
- Supports changed-file input via VI_CHANGES_DETECTED env or -ChangedFiles.
"@

    vicompare = @"
Compare two VI files and generate a breaking-change analysis report.
- Uses Compare-VIHistory.ps1 from the VI History Suite.
- Detects connector pane changes, dependency changes, and deprecated API usage.
- Generates LV 2025.3-compatible comparison payloads.
- Command:
  pwsh -NoProfile -File scripts/vi-history-suite/Compare-VIHistory.ps1 -BaseVI "path/to/base.vi" -CompareVI "path/to/compare.vi" -OutputFormat lv2025
- Output formats: json, html, lv2025.
"@

    vianalyze = @"
Analyze VI files for compatibility across LabVIEW versions.
- Uses Analyze-VICompatibility.ps1 from the VI History Suite.
- Checks compatibility matrix against lv2021, lv2023, lv2024, lv2025.
- Reports deprecated API usage and breaking changes.
- Command:
  pwsh -NoProfile -File scripts/vi-history-suite/Analyze-VICompatibility.ps1 -VIPath "path/to/vi.vi"
"@
}

if (-not $aliases.ContainsKey($Keyword.ToLower())) {
    $valid = ($aliases.Keys | Sort-Object) -join ', '
    throw "Unknown keyword '$Keyword'. Known keywords: $valid"
}

$aliases[$Keyword.ToLower()]
