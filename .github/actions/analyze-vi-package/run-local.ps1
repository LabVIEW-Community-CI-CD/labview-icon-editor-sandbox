param(
    [Parameter(Mandatory)][string]$VipPath,
    [Parameter(Mandatory)][string]$MinLabVIEW = "21.0"
)

$ErrorActionPreference = 'Stop'

# Ensure Pester 5.x (pin to 5.7.1 to avoid v6 alpha semantics)
$desiredVersion = '5.7.1'
Remove-Module Pester -ErrorAction SilentlyContinue
$pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq [version]$desiredVersion } | Select-Object -First 1
if (-not $pesterModule) {
    Install-Module -Name Pester -RequiredVersion $desiredVersion -Scope CurrentUser -Force -SkipPublisherCheck
    $pesterModule = Get-Module -ListAvailable -Name Pester | Where-Object { $_.Version -eq [version]$desiredVersion } | Select-Object -First 1
}
if (-not $pesterModule) {
    throw "Pester $desiredVersion not available even after installation."
}
Import-Module -Name $pesterModule.Path -Force

# Resolve VIP path; allow direct file, directory (pick newest .vip), or wildcard
 $vipResolved = $null
 if (Test-Path -LiteralPath $VipPath -PathType Leaf) {
     $vipResolved = (Resolve-Path -LiteralPath $VipPath).Path
 } elseif (Test-Path -LiteralPath $VipPath -PathType Container) {
     $candidates = Get-ChildItem -Path $VipPath -Filter *.vip -File -Recurse | Sort-Object LastWriteTime -Descending
     if ($candidates) {
         $vipResolved = $candidates[0].FullName
         Write-Host ("Using most recent .vip under {0}: {1}" -f $VipPath, $vipResolved)
     }
 } else {
     $candidates = Get-ChildItem -Path $VipPath -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Extension -ieq '.vip' } | Sort-Object LastWriteTime -Descending
     if ($candidates) {
         $vipResolved = $candidates[0].FullName
         Write-Host ("Using .vip matched by pattern {0}: {1}" -f $VipPath, $vipResolved)
     }
 }

if (-not $vipResolved) {
    throw "VIP not found. Provide a .vip path, a directory containing one, or a wildcard. Input was: $VipPath"
}

$tests = Join-Path $PSScriptRoot 'Analyze-VIP.Tests.ps1'
if (-not (Test-Path -LiteralPath $tests)) {
    throw "Test file not found at $tests"
}

Write-Host ("Running tests in {0} (VIP={1}, MinLV={2})" -f $tests, $vipResolved, $MinLabVIEW)
$testsResolved = (Resolve-Path -LiteralPath $tests).Path
$env:VIP_PATH = $vipResolved
$env:MIN_LV_VERSION = $MinLabVIEW
Invoke-Pester -Path $testsResolved -CI -Output Detailed | Out-Host
