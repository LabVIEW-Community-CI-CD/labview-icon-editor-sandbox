# Helper functions to resolve LabVIEW ini locations and remove stale LocalHost.LibraryPaths entries.

function Resolve-LVIniPath {
    param(
        [string]$LvVersion,
        [string]$Arch
    )

    $allowCustom = [bool]$env:ALLOW_NONCANONICAL_LV_INI_PATH

    $canonical = if ($Arch -eq '64') {
        "C:\Program Files\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
    } else {
        "C:\Program Files (x86)\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
    }

    $candidates = @($canonical)
    if ($allowCustom -and $env:TEST_LV_INI_PATH) {
        $candidates = @($env:TEST_LV_INI_PATH) + $candidates
    }

    foreach ($path in $candidates) {
        if (Test-Path $path) {
            if (-not $allowCustom -and $path -ne $canonical) {
                throw "Non-canonical LabVIEW.ini path detected: $path. Expected: $canonical"
            }
            return $path
        }
    }

    throw "LabVIEW.ini not found at canonical path: $canonical"
}

function Clear-StaleLibraryPaths {
    param(
        [string]$LvVersion,
        [string]$Arch,
        [string]$RepositoryRoot
    )
    $lvIniPath = Resolve-LVIniPath -LvVersion $LvVersion -Arch $Arch
    if (-not $lvIniPath) { return }

    $ini     = Get-Content -LiteralPath $lvIniPath -Raw
    $pattern = 'LocalHost\.LibraryPaths\d+='
    $lines   = $ini -split "`r?`n"
    $cleaned = @()
    $removed = @()
    $seen    = @{}
    $repoNorm = [System.IO.Path]::GetFullPath($RepositoryRoot).TrimEnd('\','/').ToLowerInvariant()

    foreach ($line in $lines) {
        if (-not ($line -match $pattern)) {
            $cleaned += $line
            continue
        }

        $parts = $line -split '=',2
        $value = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        if ([string]::IsNullOrWhiteSpace($value)) {
            $removed += $line
            continue
        }
        $valNorm = ([System.IO.Path]::GetFullPath($value)).TrimEnd('\','/').ToLowerInvariant()

        $shouldRemove =
            ($line -like "*actions-runner*actions-runner*") -or
            ($valNorm -eq $repoNorm) -or
            ($seen.ContainsKey($valNorm))

        if ($shouldRemove) {
            $removed += $line
            continue
        }

        $seen[$valNorm] = $true
        $cleaned += $line
    }
    if ($removed.Count -gt 0) {
        Set-Content -LiteralPath $lvIniPath -Value ($cleaned -join "`r`n")
        $sample = $removed | Select-Object -First 1
        Write-Warning ("Removed {0} LocalHost.LibraryPaths entries from {1}. Example removed entry: {2}" -f $removed.Count, $lvIniPath, $sample)
    }
}
