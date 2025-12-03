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
}

if (-not $aliases.ContainsKey($Keyword.ToLower())) {
    $valid = ($aliases.Keys | Sort-Object) -join ', '
    throw "Unknown keyword '$Keyword'. Known keywords: $valid"
}

$aliases[$Keyword.ToLower()]
