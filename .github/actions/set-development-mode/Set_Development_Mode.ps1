<#
.SYNOPSIS
    Configures the repository for development mode.

.DESCRIPTION
    Removes existing packed libraries, adds INI tokens, prepares LabVIEW
    sources for both 32-bit and 64-bit environments, and closes LabVIEW.

.PARAMETER RelativePath
    Path to the repository root.

.EXAMPLE
    .\Set_Development_Mode.ps1 -RelativePath "C:\labview-icon-editor"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
)

# Define LabVIEW project name
$LabVIEW_Project = 'lv_icon_editor'

# Determine the directory where this script is located
$ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
Write-Host "Script Directory: $ScriptDirectory"

# Build paths to the helper scripts
$AddTokenScript = Join-Path -Path $ScriptDirectory -ChildPath '..\add-token-to-labview\AddTokenToLabVIEW.ps1'
$PrepareScript  = Join-Path -Path $ScriptDirectory -ChildPath '..\prepare-labview-source\Prepare_LabVIEW_source.ps1'
$CloseScript    = Join-Path -Path $ScriptDirectory -ChildPath '..\close-labview\Close_LabVIEW.ps1'

# Helper function to execute scripts and stop on error
function Execute-Script {
    param(
        [string]$ScriptCommand
    )
    Write-Host "Executing: $ScriptCommand"
    try {
        # Execute the command
        Invoke-Expression $ScriptCommand -ErrorAction Stop

        # Check for errors in the script execution
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error occurred while executing: $ScriptCommand. Exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    } catch {
        Write-Error "Error occurred while executing: $ScriptCommand. Exiting."
        Write-Error $_.Exception.Message
        exit 1
    }
}

try {
    # Remove existing packed libraries (if the folder exists)
    Execute-Script "Get-ChildItem -Path '$RelativePath\resource\plugins' -Filter '*.lvlibp' | Remove-Item -Force"

    #
    # 32-bit
    #
    $Command1 = "& `"$AddTokenScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`""
    Execute-Script $Command1

    $Command2 = "& `"$PrepareScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32 -RelativePath `"$RelativePath`" -LabVIEW_Project `"$LabVIEW_Project`" -Build_Spec `'Editor Packed Library`'"
    Execute-Script $Command2

    $Command3 = "& `"$CloseScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 32"
    Execute-Script $Command3

    #
    # 64-bit
    #
    $Command4 = "& `"$AddTokenScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`""
    Execute-Script $Command4

    $Command5 = "& `"$PrepareScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 64 -RelativePath `"$RelativePath`" -LabVIEW_Project `"$LabVIEW_Project`" -Build_Spec `'Editor Packed Library`'"
    Execute-Script $Command5

    $Command6 = "& `"$CloseScript`" -MinimumSupportedLVVersion 2021 -SupportedBitness 64"
    Execute-Script $Command6

} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

Write-Host "All scripts executed successfully." -ForegroundColor Green
