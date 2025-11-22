<#
.SYNOPSIS
    Runs MissingInProjectCLI.vi via G-CLI and streams the VI's output.

.PARAMETER LVVersion
    LabVIEW version (e.g. "2021").

.PARAMETER Arch
    Bitness ("32" or "64").

.PARAMETER ProjectFile
    Full path to the .lvproj that should be inspected.

.NOTES
    - Leaves exit status in $LASTEXITCODE for the caller.
    - Does NOT call 'exit' to avoid terminating a parent session.
#>
#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$LVVersion,
    [Parameter(Mandatory)][ValidateSet('32','64')][string]$Arch,
    [Parameter(Mandatory)][string]$ProjectFile
)
$ErrorActionPreference = 'Stop'
Write-Information "[GCLI] Starting Missing-in-Project check ..." -InformationAction Continue

# ---------- sanity checks ----------
$gcliCmd = Get-Command g-cli -ErrorAction SilentlyContinue
if (-not $gcliCmd) {
    Write-Warning "g-cli executable not found in PATH."
    $global:LASTEXITCODE = 127
    return
}

$viPath = Join-Path -Path $PSScriptRoot -ChildPath 'MissingInProjectCLI.vi'
if (-not (Test-Path $viPath)) {
    Write-Warning "VI not found: $viPath"
    $global:LASTEXITCODE = 2
    return
}
if (-not (Test-Path $ProjectFile)) {
    Write-Warning "Project file not found: $ProjectFile"
    $global:LASTEXITCODE = 3
    return
}

# ---------- diagnostics snapshot ----------
$gcliVersion = ""
try {
    $gcliVersion = (& g-cli --version) -join ' '
}
catch {
    $gcliVersion = $_.Exception.Message
}
$gcliLogPath = Join-Path -Path $PSScriptRoot -ChildPath 'missing_in_project_gcli.log'
Remove-Item $gcliLogPath -ErrorAction SilentlyContinue

Write-Information "VI path      : $viPath" -InformationAction Continue
Write-Information "Project file : $ProjectFile" -InformationAction Continue
Write-Information "LabVIEW ver  : $LVVersion  ($Arch-bit)" -InformationAction Continue
Write-Information "g-cli path   : $($gcliCmd.Source)" -InformationAction Continue
Write-Information "g-cli ver    : $gcliVersion" -InformationAction Continue
Write-Information "Working dir  : $(Get-Location)" -InformationAction Continue

# ---------- build argument list & invoke ----------
$gcliArgs = @(
    '--lv-ver', $LVVersion,
    '--arch',   $Arch,
    $viPath,
    '--',
    $ProjectFile
)
$commandPreview = "g-cli " + ($gcliArgs -join ' ')
Write-Information "Command      : $commandPreview" -InformationAction Continue
Write-Information "--------------------------------------------------" -InformationAction Continue

$gcliOutput = & g-cli @gcliArgs 2>&1 | Tee-Object -Variable _outLines -FilePath $gcliLogPath
$exitCode   = $LASTEXITCODE

# relay all output so the wrapper can capture & parse
$gcliOutput | ForEach-Object { Write-Output $_ }

if ($exitCode -eq 0) {
    Write-Information "Missing-in-Project check passed (no missing files)." -InformationAction Continue
    Remove-Item $gcliLogPath -ErrorAction SilentlyContinue
} else {
    Write-Warning "Missing-in-Project check FAILED - exit code $exitCode"
    Write-Warning ("g-cli output saved to {0}" -f $gcliLogPath)

    $firstLines = $gcliOutput | Select-Object -First 5
    $lastLines  = $gcliOutput | Select-Object -Last 5
    if ($firstLines) {
        Write-Warning ("Output (first 5 lines):`n{0}" -f ($firstLines -join [Environment]::NewLine))
    }
    if ($lastLines) {
        Write-Warning ("Output (last 5 lines):`n{0}" -f ($lastLines -join [Environment]::NewLine))
    }
}

# close LabVIEW if still running (harmless if not)
& g-cli --lv-ver $LVVersion --arch $Arch QuitLabVIEW | Out-Null

$global:LASTEXITCODE = $exitCode
return
