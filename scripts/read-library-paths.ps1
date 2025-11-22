param(
    [string]$RepositoryPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('32','64')]
    [string]$SupportedBitness
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Resolve repository root (default: git top-level)
if (-not $RepositoryPath) {
    $repo = (git -C $PSScriptRoot rev-parse --show-toplevel 2>$null)
    if (-not $repo) { $repo = (Get-Location).ProviderPath }
    $RepositoryPath = $repo
}

$RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path

function Get-LabVIEWVersionFromVipb {
    param(
        [Parameter(Mandatory)][string]$RootPath
    )

    $vipb = Get-ChildItem -Path $RootPath -Filter *.vipb -File -Recurse | Select-Object -First 1
    if (-not $vipb) {
        throw "No .vipb file found under $RootPath"
    }

    $text = Get-Content -LiteralPath $vipb.FullName -Raw
    $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
    if (-not $match.Success) {
        throw "Unable to locate Package_LabVIEW_Version in $($vipb.FullName)"
    }

    $raw = $match.Groups['ver'].Value
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) {
        throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)"
    }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    $lvVersion = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
    return $lvVersion
}

$lvVersion = Get-LabVIEWVersionFromVipb -RootPath $RepositoryPath

$iniCandidates = if ($SupportedBitness -eq '64') {
    @(
        "C:\Program Files\National Instruments\LabVIEW $lvVersion\LabVIEW.ini",
        "$env:ProgramData\National Instruments\LabVIEW $lvVersion\LabVIEW.ini"
    )
} else {
    @(
        "C:\Program Files (x86)\National Instruments\LabVIEW $lvVersion\LabVIEW.ini",
        "$env:ProgramData\National Instruments\LabVIEW $lvVersion (32-bit)\LabVIEW.ini"
    )
}

$iniPath = $iniCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1

Write-Host "LabVIEW version : $lvVersion"
Write-Host "Bitness         : $SupportedBitness-bit"
Write-Host "INI candidates  : $($iniCandidates -join '; ')"
Write-Host "INI path        : $iniPath"

if (-not $iniPath) {
    Write-Warning "LabVIEW.ini not found in any candidate location."
    exit 1
}

$lines = Get-Content -LiteralPath $iniPath
$entries = $lines | Where-Object { $_ -match '^LocalHost\.LibraryPaths\d+=' }

if (-not $entries -or $entries.Count -eq 0) {
    Write-Warning "No LocalHost.LibraryPaths entries found in $iniPath"
    exit 0
}

$index = 1
foreach ($entry in $entries) {
    Write-Host ("[{0}] {1}" -f $index, $entry)
    $index++
}

exit 0
