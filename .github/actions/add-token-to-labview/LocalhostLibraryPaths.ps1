# Helper functions to resolve LabVIEW ini locations and remove stale LocalHost.LibraryPaths entries.

function Resolve-LVIniPath {
    param(
        [string]$LvVersion,
        [string]$Arch
    )

    if ($Arch -eq '64') {
        $candidates = @(
            "C:\Program Files\National Instruments\LabVIEW $LvVersion\LabVIEW.ini",
            "$env:ProgramData\National Instruments\LabVIEW $LvVersion\LabVIEW.ini"
        )
    } else {
        $candidates = @(
            "C:\Program Files (x86)\National Instruments\LabVIEW $LvVersion\LabVIEW.ini",
            "$env:ProgramData\National Instruments\LabVIEW $LvVersion (32-bit)\LabVIEW.ini"
        )
    }

    foreach ($path in $candidates) {
        if (Test-Path $path) { return $path }
    }
    return $null
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
