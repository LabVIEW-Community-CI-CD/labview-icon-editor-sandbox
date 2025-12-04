<#
.SYNOPSIS
    Generate a LabVIEW 2025.3-compatible VI Comparison report from comparison data.
#>
param(
    [Parameter(Mandatory=$true)]
    [string]$ComparisonDataPath,

    [Parameter(Mandatory=$true)]
    [string]$OutputPath,

    [ValidateSet('lv2025','custom')]
    [string]$TemplateFormat = 'lv2025'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ComparisonDataPath)) {
    throw "Comparison data not found at $ComparisonDataPath"
}

$data = Get-Content -LiteralPath $ComparisonDataPath -Raw | ConvertFrom-Json
$templatePath = Join-Path $PSScriptRoot 'templates/lv2025-report.template.html'
if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Report template missing at $templatePath"
}
$template = Get-Content -LiteralPath $templatePath -Raw

$totalBreaks = $data.breaking_changes.Count
$summary = @"
<ul>
    <li>Base VI: $($data.base.vi_name)</li>
    <li>Compare VI: $($data.compare.vi_name)</li>
    <li>Breaking changes detected: $totalBreaks</li>
    <li>Recommendation: $($data.recommendation)</li>
</ul>
"@

$comparisonEntries = @()
if ($data.differences.version_change) {
    $comparisonEntries += '<li>Version change: ' + $data.differences.version_change.from + ' → ' + $data.differences.version_change.to + '</li>'
}
foreach ($change in $data.differences.connector_pane_changes) {
    $comparisonEntries += '<li>Connector change: ' + $change.type + '</li>'
}
foreach ($change in $data.differences.dependency_changes) {
    $comparisonEntries += '<li>Dependency change: ' + $change.vi + ' (' + $change.type + ')</li>'
}
foreach ($change in $data.differences.deprecated_api_changes) {
    $comparisonEntries += '<li>Deprecated API: ' + $change.api + '</li>'
}
$comparison = '<ul>' + ($comparisonEntries -join "") + '</ul>'

$colors = @{ compatible = 'compatible'; incompatible = 'incompatible'; warnings = 'warnings' }
$matrixRows = @()
foreach ($kvp in ($data.compatibility_impact.GetEnumerator() | Sort-Object Name)) {
    $state = $kvp.Value
    $class = $colors[$state] ?? 'warnings'
    $matrixRows += "<tr><td>$($kvp.Name)</td><td class='$class'>$state</td></tr>"
}
$matrix = "<table><thead><tr><th>Version/Platform</th><th>Status</th></tr></thead><tbody>$($matrixRows -join '')</tbody></table>"

$detailsList = @()
if ($data.differences.connector_pane_changes.Count -gt 0) {
    $detailsList += '<h3>Connector Pane</h3><ul>' + ($data.differences.connector_pane_changes | ForEach-Object { "<li>$($_.type): $($_.terminal ?? 'count change')</li>" } -join '') + '</ul>'
}
if ($data.differences.dependency_changes.Count -gt 0) {
    $detailsList += '<h3>Dependencies</h3><ul>' + ($data.differences.dependency_changes | ForEach-Object { "<li>$($_.vi) $($_.type) (from: $($_.from) to: $($_.to))</li>" } -join '') + '</ul>'
}
if ($data.differences.deprecated_api_changes.Count -gt 0) {
    $detailsList += '<h3>Deprecated APIs</h3><ul>' + ($data.differences.deprecated_api_changes | ForEach-Object { "<li>$($_.api) ($($_.type))</li>" } -join '') + '</ul>'
}
$details = $detailsList -join ''

$html = $template.Replace('{{SUMMARY}}', $summary)
$html = $html.Replace('{{COMPARISON}}', $comparison)
$html = $html.Replace('{{MATRIX}}', $matrix)
$html = $html.Replace('{{DETAILS}}', $details)

$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
Set-Content -LiteralPath $OutputPath -Value $html -Encoding utf8

Write-Host "VI Comparison report written to $OutputPath" -ForegroundColor Green
