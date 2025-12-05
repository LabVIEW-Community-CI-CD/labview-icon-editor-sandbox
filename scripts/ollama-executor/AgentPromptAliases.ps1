[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$Keyword
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Map single-word keywords to full agent prompts.
$aliases = @{
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
Run the VI History Suite to analyze VI file changes and generate compatibility reports.
- Use Run-Locked-VIHistory.ps1 for orchestrated execution via Ollama executor.
- In simulation mode (OLLAMA_EXECUTOR_MODE=sim), generates stub reports without LabVIEW.
- In real mode, invokes VI History Suite scripts with actual VI analysis.
- Command:
  pwsh -NoProfile -File scripts/ollama-executor/Run-Locked-VIHistory.ps1 -RepoPath .
- Outputs VI comparison reports to reports/vi-history/.
- Creates handshake at artifacts/vi-history-handshake.json.
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
