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
    [string]$RepositoryPath,

    # LabVIEW major.minor version to target (e.g., 2021, 2023)
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$MinimumSupportedLVVersion = '2021'
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

# Sequential script execution with error handling
try {
    # Build the script paths
    $RestoreScript = Join-Path -Path $ScriptDirectory -ChildPath 'RestoreSetupLVSource.ps1'
    $CloseScript = Join-Path -Path $ScriptDirectory -ChildPath 'Close_LabVIEW.ps1'

    # Restore setup for LabVIEW (32-bit)
    Invoke-ScriptSafe -ScriptPath $RestoreScript -ArgumentList @('-MinimumSupportedLVVersion', $MinimumSupportedLVVersion,'-SupportedBitness','32','-RepositoryPath',$RepositoryPath,'-LabVIEW_Project',$LabVIEW_Project,'-Build_Spec','Editor Packed Library')

    # Close LabVIEW (32-bit)
    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion', $MinimumSupportedLVVersion,'-SupportedBitness','32')

    # Restore setup for LabVIEW (64-bit)
    Invoke-ScriptSafe -ScriptPath $RestoreScript -ArgumentList @('-MinimumSupportedLVVersion', $MinimumSupportedLVVersion,'-SupportedBitness','64','-RepositoryPath',$RepositoryPath,'-LabVIEW_Project',$LabVIEW_Project,'-Build_Spec','Editor Packed Library')

    # Close LabVIEW (64-bit)
    Invoke-ScriptSafe -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion', $MinimumSupportedLVVersion,'-SupportedBitness','64')

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue

