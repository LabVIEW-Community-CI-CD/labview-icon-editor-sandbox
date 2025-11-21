<#
#    .SYNOPSIS
#        Configures the repository for development mode.
#
#    .DESCRIPTION
#        Removes existing packed libraries, adds INI tokens, prepares LabVIEW
#        sources for both 32-bit and 64-bit environments, and closes LabVIEW.
#
#    .PARAMETER RepositoryPath
#        Path to the repository root.
#
#    .EXAMPLE
#        .\Set_Development_Mode.ps1 -RepositoryPath "C:\\labview-icon-editor"
#
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({ Test-Path $_ })]
    [string]$RepositoryPath,

    # Optional override; if not provided we read Package_LabVIEW_Version from the repo .vipb
    [Parameter(Mandatory = $false)]
    [string]$Package_LabVIEW_Version
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Information "Script Directory: $ScriptDirectory" -InformationAction Continue

# Build paths to the helper scripts
$AddTokenScript = Join-Path -Path $ScriptDirectory -ChildPath '..\add-token-to-labview\AddTokenToLabVIEW.ps1'
$PrepareScript  = Join-Path -Path $ScriptDirectory -ChildPath '..\prepare-labview-source\Prepare_LabVIEW_source.ps1'
$CloseScript    = Join-Path -Path $ScriptDirectory -ChildPath '..\close-labview\Close_LabVIEW.ps1'

Write-Information "AddTokenToLabVIEW script: $AddTokenScript" -InformationAction Continue
Write-Information "Prepare_LabVIEW_source script: $PrepareScript" -InformationAction Continue
Write-Information "Close_LabVIEW script: $CloseScript" -InformationAction Continue

# Helper function to execute scripts and stop on error
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, ($ArgumentList -join ' ')) -InformationAction Continue
    try {
        & $ScriptPath @ArgumentList
    }
    catch {
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
    # Expect formats like '21.0 (64-bit)'
    $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
    if (-not $verMatch.Success) {
        throw "Unable to parse LabVIEW version from '$raw' in $($vipb.FullName)"
    }
    $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
    # Convert 21 -> 2021, 23 -> 2023, etc.
    $lvVersion = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }
    return $lvVersion
}

try {
    if (-not $Package_LabVIEW_Version) {
        $Package_LabVIEW_Version = Get-LabVIEWVersionFromVipb -RootPath $RepositoryPath
        Write-Information ("Detected LabVIEW version from VIPB: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue
    } else {
        Write-Information ("Using explicit LabVIEW version: {0}" -f $Package_LabVIEW_Version) -InformationAction Continue
    }

    # Remove existing packed libraries (if the folder exists)
    $PluginsPath = Join-Path -Path $RepositoryPath -ChildPath 'resource\plugins'
    if (Test-Path $PluginsPath) {
        # Build and execute the removal command only if the plugins folder exists
        # Remove via pipeline to avoid IE
        Get-ChildItem -Path $PluginsPath -Filter '*.lvlibp' -ErrorAction SilentlyContinue | Remove-Item -Force
    }
    else {
        Write-Information "No 'resource\plugins' directory found at $PluginsPath; skipping removal of packed libraries." -InformationAction Continue
    }

    # 32-bit actions
    Invoke-ScriptSafe -ScriptPath $AddTokenScript -ArgumentList @('-MinimumSupportedLVVersion',$Package_LabVIEW_Version,'-SupportedBitness','32','-RepositoryPath', $RepositoryPath)

    Invoke-ScriptSafe -ScriptPath $PrepareScript -ArgumentList @('-MinimumSupportedLVVersion',$Package_LabVIEW_Version,'-SupportedBitness','32','-RepositoryPath', $RepositoryPath,'-LabVIEW_Project', $LabVIEW_Project, '-Build_Spec', 'Editor Packed Library')

    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion',$Package_LabVIEW_Version,'-SupportedBitness','32')

    # 64-bit actions
    Invoke-ScriptSafe -ScriptPath $AddTokenScript -ArgumentList @('-MinimumSupportedLVVersion',$Package_LabVIEW_Version,'-SupportedBitness','64','-RepositoryPath', $RepositoryPath)

    Invoke-ScriptSafe -ScriptPath $PrepareScript -ArgumentList @('-MinimumSupportedLVVersion',$Package_LabVIEW_Version,'-SupportedBitness','64','-RepositoryPath', $RepositoryPath,'-LabVIEW_Project', $LabVIEW_Project, '-Build_Spec', 'Editor Packed Library')

    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion',$Package_LabVIEW_Version,'-SupportedBitness','64')

}
catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue
