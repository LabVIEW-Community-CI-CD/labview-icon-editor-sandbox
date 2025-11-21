<#
.SYNOPSIS
    Runs a suite of PowerShell test scripts for the repository.

.DESCRIPTION
    Validates that required paths exist and sequentially executes supporting
    scripts to prepare and test the LabVIEW icon editor project.

.PARAMETER RelativePath
    Path to the repository root.

.EXAMPLE
    .\unit_tests.ps1 -RelativePath "C:\labview-icon-editor"
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
)

# Helper function to check for file or directory existence
function Assert-PathExists {
    param(
        [string]$Path,
        [string]$Description
    )
    if (-Not (Test-Path -Path $Path)) {
        Write-Error "The $Description does not exist: $Path"
        exit 1
    }
}

# Helper function to execute scripts sequentially
function Execute-Script {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, ($ArgumentList -join ' ')) -InformationAction Continue
    try {
        & $ScriptPath @ArgumentList

    } catch {
        Write-Error "Error occurred while executing: $ScriptPath with arguments: $($ArgumentList -join ' '). Exiting."
        exit 1
    }
}

# Main script logic
try {
    # Validate required paths
    Assert-PathExists $RelativePath "RelativePath"
    if (-not (Test-Path "$RelativePath\resource\plugins")) {
        Write-Information "Plugins folder missing; creating $RelativePath\resource\plugins" -InformationAction Continue
        New-Item -ItemType Directory -Path "$RelativePath\resource\plugins" -Force | Out-Null
    }

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Assert-PathExists $ActionsPath "Actions folder"

    # Clean up .lvlibp files in the plugins folder
    Write-Information "Cleaning up old .lvlibp files in plugins folder..." -InformationAction Continue
    $PluginFiles = Get-ChildItem -Path "$RelativePath\resource\plugins" -Filter '*.lvlibp' -ErrorAction SilentlyContinue
    if ($PluginFiles) {
        foreach ($file in $PluginFiles) {
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            }
            catch {
                Write-Warning ("Failed to delete {0}: {1}" -f $file.FullName, $_.Exception.Message)
            }
        }
        Write-Information "Deleted .lvlibp files from plugins folder." -InformationAction Continue
    } else {
        Write-Information "No .lvlibp files found to delete." -InformationAction Continue
    }
    
    # Run Unit Tests
    $RunUnitTests = Join-Path $ActionsPath "run-unit-tests/RunUnitTests.ps1"
    Execute-Script -ScriptPath $RunUnitTests -ArgumentList @(
        '-MinimumSupportedLVVersion','2021',
        '-SupportedBitness','32',
        '-RelativePath', $RelativePath
    )

    # Close LabVIEW
    $CloseLabVIEW = Join-Path $ActionsPath "close-labview/Close_LabVIEW.ps1"
    Execute-Script -ScriptPath $CloseLabVIEW -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','32')

    # Run Unit Tests
    Execute-Script -ScriptPath $RunUnitTests -ArgumentList @(
        '-MinimumSupportedLVVersion','2021',
        '-SupportedBitness','64',
        '-RelativePath', $RelativePath
    )

	# Close LabVIEW
    Execute-Script -ScriptPath $CloseLabVIEW -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','64')
		
    Write-Information "All scripts executed successfully!" -InformationAction Continue
} catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    exit 1
}

