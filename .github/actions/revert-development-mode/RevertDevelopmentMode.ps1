<#
.SYNOPSIS
    Reverts the repository from development mode.

.DESCRIPTION
    Restores the packaged LabVIEW sources for both 32-bit and 64-bit
    environments and closes any running LabVIEW instances.

.PARAMETER RepositoryPath
    Path to the repository root.

.EXAMPLE
    .\RevertDevelopmentMode.ps1 -RepositoryPath "C:\labview-icon-editor"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Information "Script Directory: $ScriptDirectory" -InformationAction Continue

# Helper function to execute scripts and stop on error
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, ($ArgumentList -join ' ')) -InformationAction Continue
    try {
        & $ScriptPath @ArgumentList
    } catch {
        Write-Error "Error occurred while executing: $ScriptPath $($ArgumentList -join ' '). Exiting."
        Write-Error $_.Exception.Message
        exit 1
    }
}

# Extract LabVIEW version from the repo's VIPB (Package_LabVIEW_Version)
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

# Sequential script execution with error handling
try {
    $MinimumSupportedLVVersion = Get-LabVIEWVersionFromVipb -RootPath $RepositoryPath
    Write-Information ("Detected LabVIEW version from VIPB: {0}" -f $MinimumSupportedLVVersion) -InformationAction Continue
    # Build the script paths
    $RestoreScript = Join-Path -Path $ScriptDirectory -ChildPath 'RestoreSetupLVSource.ps1'
    $CloseScript = Join-Path -Path $ScriptDirectory -ChildPath 'Close_LabVIEW.ps1'

    # Restore setup for LabVIEW (32-bit)
    Invoke-ScriptSafe -ScriptPath $RestoreScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','32','-RepositoryPath',$RepositoryPath,'-LabVIEW_Project',$LabVIEW_Project,'-Build_Spec','Editor Packed Library')

    # Close LabVIEW (32-bit)
    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','32')

    # Restore setup for LabVIEW (64-bit)
    Invoke-ScriptSafe -ScriptPath $RestoreScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','64','-RepositoryPath',$RepositoryPath,'-LabVIEW_Project',$LabVIEW_Project,'-Build_Spec','Editor Packed Library')

    # Close LabVIEW (64-bit)
    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','64')

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue

