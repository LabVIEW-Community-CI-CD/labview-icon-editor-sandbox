# Helper to scrub stale LocalHost.LibraryPaths entries from LabVIEW INI
function Clear-StaleLibraryPaths {
    param(
        [string]$LvVersion,
        [string]$Arch,
        [string]$RepositoryRoot
    )
    $overrideIni = $env:LV_INI_OVERRIDE_PATH
    $lvIniPath = if ($overrideIni) {
        $overrideIni
    } elseif ($Arch -eq '64') {
        "$env:ProgramData\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
    } else {
        "$env:ProgramData\National Instruments\LabVIEW $LvVersion (32-bit)\LabVIEW.ini"
    }
    if (-not (Test-Path $lvIniPath)) { return }

    $ini     = Get-Content -LiteralPath $lvIniPath -Raw
    $pattern = 'LocalHost\.LibraryPaths\d+='
    $lines   = $ini -split "`r?`n"
    $cleaned = @()
    $removed = @()
    foreach ($line in $lines) {
        if ($line -match $pattern -and $line -like "*actions-runner*actions-runner*") {
            $removed += $line
            continue
        }
        $cleaned += $line
    }
    if ($removed.Count -gt 0) {
        Set-Content -LiteralPath $lvIniPath -Value ($cleaned -join "`r`n")
        $sample = $removed | Select-Object -First 1
        Write-Warning ("Removed {0} stale LocalHost.LibraryPaths entries from {1}. Example removed entry: {2}" -f $removed.Count, $lvIniPath, $sample)
    }
}
