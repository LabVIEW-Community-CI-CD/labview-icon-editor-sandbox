<#
.SYNOPSIS
    Reverts the repository from development mode.

.DESCRIPTION
    Restores the packaged LabVIEW sources for both 32-bit and 64-bit
    environments and closes any running LabVIEW instances.

.PARAMETER RelativePath
    Path to the repository root.

.EXAMPLE
    .\RevertDevelopmentMode.ps1 -RelativePath "C:\labview-icon-editor"
#>

param(
    [Parameter(Mandatory = $true)]
    [Alias('RelativePath')]
    [string]$RepositoryPath
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Information "Script Directory: $ScriptDirectory" -InformationAction Continue

# Helper function to execute scripts and stop on error
function Execute-Script {
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

    # Restore setup for LabVIEW 2021 (32-bit)
    Execute-Script -ScriptPath $RestoreScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','32','-RepositoryPath',$RepositoryPath,'-LabVIEW_Project',$LabVIEW_Project,'-Build_Spec','Editor Packed Library')

    # Close LabVIEW 2021 (32-bit)
    Execute-Script -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','32')

    # Restore setup for LabVIEW 2021 (64-bit)
    Execute-Script -ScriptPath $RestoreScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','64','-RepositoryPath',$RepositoryPath,'-LabVIEW_Project',$LabVIEW_Project,'-Build_Spec','Editor Packed Library')

    # Close LabVIEW 2021 (64-bit)
    Execute-Script -ScriptPath $CloseScript -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','64')

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Information "All scripts executed successfully." -InformationAction Continue

