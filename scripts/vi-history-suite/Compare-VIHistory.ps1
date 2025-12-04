<#
.SYNOPSIS
    Compare two VI versions and identify differences.

.DESCRIPTION
    Compares two VI files and generates a detailed comparison report including
    breaking changes, deprecated APIs, and compatibility impacts.

.PARAMETER BaseVI
    Path to the baseline VI file.

.PARAMETER CompareVI
    Path to the comparison VI file.

.PARAMETER OutputFormat
    Output format: json, html, lv2025. Default: json.

.PARAMETER OutputPath
    Path to save the comparison report. If not specified, outputs to console.

.EXAMPLE
    pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi"

.EXAMPLE
    pwsh -NoProfile -File Compare-VIHistory.ps1 -BaseVI "v1/MyVI.vi" -CompareVI "v2/MyVI.vi" -OutputFormat html -OutputPath "report.html"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$BaseVI,
    
    [Parameter(Mandatory=$true)]
    [string]$CompareVI,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("json", "html", "lv2025")]
    [string]$OutputFormat = "json",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$metadataScript = Join-Path $scriptDir "SimulateVIMetadata.ps1"

function Get-VIMetadataWrapper {
    param([string]$VIPath)
    
    $output = & $metadataScript -VIPath $VIPath -OutputFormat json 2>&1 | Where-Object { $_ -match '^\s*{' } | Out-String
    return $output | ConvertFrom-Json
}

function Compare-VIVersions {
    param($Base, $Compare)
    
    $versionChange = $null
    if ($Base.lv_version -ne $Compare.lv_version) {
        $versionChange = @{
            from = $Base.lv_version
            to = $Compare.lv_version
            from_normalized = $Base.lv_version_normalized
            to_normalized = $Compare.lv_version_normalized
        }
    }
    
    return $versionChange
}

function Compare-ConnectorPanes {
    param($Base, $Compare)

    $changes = @()
    $basePane = $Base.connector_pane
    $comparePane = $Compare.connector_pane
    if (-not $basePane) {
        $basePane = [pscustomobject]@{ input_count = 0; output_count = 0; terminals = @(); has_error_terminals = $false }
    }
    if (-not $comparePane) {
        $comparePane = [pscustomobject]@{ input_count = 0; output_count = 0; terminals = @(); has_error_terminals = $false }
    }

    $baseInputs = $basePane.input_count
    $compareInputs = $comparePane.input_count
    if ($baseInputs -ne $compareInputs) {
        $changes += @{
            type = "input_count_changed"
            from = $baseInputs
            to = $compareInputs
            severity = "high"
        }
    }

    $baseOutputs = $basePane.output_count
    $compareOutputs = $comparePane.output_count
    if ($baseOutputs -ne $compareOutputs) {
        $changes += @{
            type = "output_count_changed"
            from = $baseOutputs
            to = $compareOutputs
            severity = "high"
        }
    }

    $baseTerminals = @($basePane.terminals)
    $compareTerminals = @($comparePane.terminals)
    $baseKeys = @{}
    $compareKeys = @{}

    foreach ($term in $baseTerminals) {
        $key = "{0}:{1}" -f $term.direction, $term.name
        $baseKeys[$key] = $term
    }
    foreach ($term in $compareTerminals) {
        $key = "{0}:{1}" -f $term.direction, $term.name
        $compareKeys[$key] = $term
    }

    foreach ($key in $compareKeys.Keys) {
        if (-not $baseKeys.ContainsKey($key)) {
            $parts = $key.Split(':')
            $changes += @{
                type = "terminal_added"
                direction = $parts[0]
                terminal = $parts[1]
                severity = "high"
            }
        }
    }

    foreach ($key in $baseKeys.Keys) {
        if (-not $compareKeys.ContainsKey($key)) {
            $parts = $key.Split(':')
            $changes += @{
                type = "terminal_removed"
                direction = $parts[0]
                terminal = $parts[1]
                severity = "high"
            }
        }
    }

    return $changes
}

function Compare-Dependencies {
    param($Base, $Compare)

    $changes = @()
    $baseDeps = @{ }
    $compareDeps = @{ }

    foreach ($dep in @($Base.dependencies)) {
        if ($dep.vi) { $baseDeps[$dep.vi] = $dep }
    }
    foreach ($dep in @($Compare.dependencies)) {
        if ($dep.vi) { $compareDeps[$dep.vi] = $dep }
    }

    foreach ($vi in $baseDeps.Keys) {
        if (-not $compareDeps.ContainsKey($vi)) {
            $changes += @{
                type = "dependency_removed"
                vi = $vi
                version = $baseDeps[$vi].version
                severity = "medium"
            }
        }
    }

    foreach ($vi in $compareDeps.Keys) {
        if (-not $baseDeps.ContainsKey($vi)) {
            $changes += @{
                type = "dependency_added"
                vi = $vi
                version = $compareDeps[$vi].version
                severity = "medium"
            }
            continue
        }

        $baseVersion = $baseDeps[$vi].version
        $compareVersion = $compareDeps[$vi].version
        if ($baseVersion -and $compareVersion -and $baseVersion -ne $compareVersion) {
            $changes += @{
                type = "dependency_version_changed"
                vi = $vi
                from = $baseVersion
                to = $compareVersion
                severity = "medium"
            }
        }
    }

    return $changes
}

function Compare-DeprecatedApis {
    param($Base, $Compare)

    $changes = @()
    $baseSet = @($Base.deprecated_apis)
    $compareSet = @($Compare.deprecated_apis)

    foreach ($api in $compareSet) {
        if (-not ($baseSet -contains $api)) {
            $changes += @{
                type = "deprecated_api_introduced"
                api = $api
                severity = "medium"
            }
        }
    }

    foreach ($api in $baseSet) {
        if (-not ($compareSet -contains $api)) {
            $changes += @{
                type = "deprecated_api_removed"
                api = $api
                severity = "low"
            }
        }
    }

    return $changes
}

function Detect-BreakingChanges {
    param($Differences)
    
    $breakingChanges = @()
    
    # Version downgrade is always breaking
    if ($Differences.version_change -and 
        $Differences.version_change.to_normalized -lt $Differences.version_change.from_normalized) {
        $breakingChanges += @{
            type = "version_downgrade"
            severity = "high"
            description = "VI version downgraded from $($Differences.version_change.from) to $($Differences.version_change.to)"
        }
    }
    
    # Connector pane changes are breaking
    foreach ($change in $Differences.connector_pane_changes) {
        if ($change.severity -eq "high") {
            $breakingChanges += @{
                type = "connector_pane_modified"
                severity = "high"
                description = "Connector pane $($change.type)"
            }
        }
    }

    foreach ($change in $Differences.dependency_changes) {
        if ($change.severity -in @("high","medium")) {
            $breakingChanges += @{
                type = "dependency_issue"
                severity = $change.severity
                description = "Dependency $($change.vi) change: $($change.type)"
            }
        }
    }

    foreach ($change in $Differences.deprecated_api_changes) {
        if ($change.severity -ne "low") {
            $breakingChanges += @{
                type = "deprecated_api_usage"
                severity = $change.severity
                description = "Deprecated API detected: $($change.api)"
            }
        }
    }
    
    return $breakingChanges
}

function Get-CompatibilityImpact {
    param($Base, $Compare)
    
    $impact = @{}
    
    $versions = @("lv2021", "lv2023", "lv2024", "lv2025")
    foreach ($version in $versions) {
        $baseCompat = $Base.compatibility.$version
        $compareCompat = $Compare.compatibility.$version
        
        if ($baseCompat -and -not $compareCompat) {
            $impact.$version = "incompatible"
        }
        elseif ($compareCompat) {
            $impact.$version = "compatible"
        }
        else {
            $impact.$version = "incompatible"
        }
    }
    
    return $impact
}

function Get-Recommendation {
    param($BreakingChanges, $Impact)
    
    if ($BreakingChanges.Count -gt 0) {
        return "Breaking changes detected ($($BreakingChanges.Count)) - Review required before upgrade"
    }
    
    $incompatibleCount = ($Impact.GetEnumerator() | Where-Object { $_.Value -eq "incompatible" }).Count
    if ($incompatibleCount -gt 0) {
        return "Compatibility warnings - $incompatibleCount version(s) incompatible"
    }
    
    return "No breaking changes detected - Upgrade recommended"
}

function Main {
    Write-Host "=== VI Comparison Engine ===" -ForegroundColor Cyan
    Write-Host "Base VI:    $BaseVI"
    Write-Host "Compare VI: $CompareVI"
    Write-Host "Format:     $OutputFormat"
    Write-Host ""
    
    try {
        # Extract metadata from both VIs
        Write-Host "Extracting metadata from base VI..." -ForegroundColor Yellow
        $baseMeta = Get-VIMetadataWrapper -VIPath $BaseVI
        
        Write-Host "Extracting metadata from compare VI..." -ForegroundColor Yellow
        $compareMeta = Get-VIMetadataWrapper -VIPath $CompareVI
        
        # Perform comparison
        Write-Host "Comparing VIs..." -ForegroundColor Yellow
        $versionChange = Compare-VIVersions -Base $baseMeta -Compare $compareMeta
        $connectorChanges = Compare-ConnectorPanes -Base $baseMeta -Compare $compareMeta
        $dependencyChanges = Compare-Dependencies -Base $baseMeta -Compare $compareMeta
        $deprecatedChanges = Compare-DeprecatedApis -Base $baseMeta -Compare $compareMeta
        
        $differences = @{
            version_change = $versionChange
            connector_pane_changes = $connectorChanges
            dependency_changes = $dependencyChanges
            deprecated_api_changes = $deprecatedChanges
        }
        
        $breakingChanges = Detect-BreakingChanges -Differences $differences
        $compatImpact = Get-CompatibilityImpact -Base $baseMeta -Compare $compareMeta
        $recommendation = Get-Recommendation -BreakingChanges $breakingChanges -Impact $compatImpact
        
        # Build comparison report
        $report = @{
            base = $baseMeta
            compare = $compareMeta
            differences = $differences
            breaking_changes = $breakingChanges
            compatibility_impact = $compatImpact
            recommendation = $recommendation
            generated_at = (Get-Date).ToString("o")
            tool_version = "1.0"
        }
        
        # Output report
        if ($OutputFormat -eq "json" -or $OutputFormat -eq "lv2025") {
            $json = $report | ConvertTo-Json -Depth 10
            
            if ($OutputPath) {
                $json | Set-Content -Path $OutputPath
                Write-Host "✓ Report saved to: $OutputPath" -ForegroundColor Green
            }
            else {
                Write-Output $json
            }
        }
        elseif ($OutputFormat -eq "html") {
            # HTML generation would go here
            Write-Host "HTML format not yet implemented" -ForegroundColor Yellow
        }
        
        Write-Host ""
        Write-Host "✓ Comparison completed successfully" -ForegroundColor Green
        Write-Host "Breaking changes: $($breakingChanges.Count)" -ForegroundColor $(if ($breakingChanges.Count -eq 0) { "Green" } else { "Red" })
        Write-Host "Recommendation: $recommendation" -ForegroundColor Cyan
        
        exit 0
    }
    catch {
        Write-Host "✗ Error: $_" -ForegroundColor Red
        exit 1
    }
}

Main
