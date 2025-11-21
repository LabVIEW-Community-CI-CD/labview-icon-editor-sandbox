<#
.SYNOPSIS
  This script automates the build process for the LabVIEW Icon Editor project.
  It performs the following tasks:
    1. Cleans up old .lvlibp files in the plugins folder.
    2. Applies VIPC (32-bit and 64-bit).
    3. Builds the LabVIEW library (32-bit and 64-bit).
    4. Closes LabVIEW (32-bit and 64-bit).
    5. Renames the built files.
    6. Builds the VI package (64-bit) with DisplayInformationJSON fields.
    7. Closes LabVIEW (64-bit).

  Example usage:
    .\Build.ps1 `
      -RepositoryPath "C:\release\labview-icon-editor-fork" `
      -Major 1 -Minor 0 -Patch 0 -Build 3 -Commit "Placeholder" `
      -CompanyName "Acme Corporation" `
      -AuthorName "John Doe (Acme Corp)" `
      -Verbose
#>

[CmdletBinding()]  # Enables -Verbose, -Debug, etc.
param(
    [Parameter(Mandatory = $true)]
    [string]$RepositoryPath,

    [int]$Major = 1,
    [int]$Minor = 0,
    [int]$Patch = 0,
    [int]$Build = 1,
    [string]$Commit,
    # LabVIEW "minor" revision (0 or 3)
    [Parameter(Mandatory = $false)]
    [int]$LabVIEWMinorRevision = 3,

    # New parameters that will populate the JSON fields
    [Parameter(Mandatory = $true)]
    [string]$CompanyName,

    [Parameter(Mandatory = $true)]
    [string]$AuthorName
)

# Helper function to verify a file/folder path exists
function Test-PathExistence {
    param(
        [string]$Path,
        [string]$Description
    )
    Write-Verbose "Checking if '$Description' exists at path: $Path"
    if (-not (Test-Path -Path $Path)) {
        Write-Error "The '$Description' does not exist: $Path"
        exit 1
    }
    Write-Verbose "Confirmed '$Description' exists at path: $Path"
}

# Helper function to run another script with arguments safely
function Invoke-ScriptSafe {
    param(
        [string]$ScriptPath,
        [string[]]$ArgumentList
    )
    Write-Information ("Executing: {0} {1}" -f $ScriptPath, ($ArgumentList -join ' ')) -InformationAction Continue
    try {
        & $ScriptPath @ArgumentList
        Write-Verbose "Command completed. Checking exit code..."
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Error occurred while executing `"$ScriptPath`" with arguments: $($ArgumentList -join ' '). Exit code: $LASTEXITCODE"
            exit $LASTEXITCODE
        }
    }
    catch {
        Write-Error "Error occurred while executing `"$ScriptPath`" with arguments: $($ArgumentList -join ' '). Exiting. Details: $($_.Exception.Message)"
        exit 1
    }
}

try {
    Write-Verbose "Script: Build.ps1 starting."
    Write-Verbose "Parameters received:"
    Write-Verbose " - RepositoryPath: $RepositoryPath"
    Write-Verbose " - Major: $Major"
    Write-Verbose " - Minor: $Minor"
    Write-Verbose " - Patch: $Patch"
    Write-Verbose " - Build: $Build"
    Write-Verbose " - Commit: $Commit"
    Write-Verbose " - LabVIEWMinorRevision: $LabVIEWMinorRevision"
    Write-Verbose " - CompanyName: $CompanyName"
    Write-Verbose " - AuthorName: $AuthorName"

    # Validate needed folders
    Test-PathExistence $RepositoryPath "RepositoryPath"
    Test-PathExistence "$RepositoryPath\resource\plugins" "Plugins folder"
    Test-PathExistence "$RepositoryPath\lv_icon_editor.lvproj" "LabVIEW project"

    $ActionsPath = Split-Path -Parent $PSScriptRoot
    Test-PathExistence $ActionsPath "Actions folder"

    # Ensure VIPC dependencies exist (mirrors CI prep)
    $vipcPath = Join-Path $RepositoryPath "Tooling\deployment\runner_dependencies.vipc"
    if (-not (Test-Path -LiteralPath $vipcPath)) {
        Write-Error "Missing runner_dependencies.vipc at $vipcPath. Cannot apply dependencies; run packaging prep or fetch the VIPC."
        exit 1
    }

    # 1) Clean up old .lvlibp in the plugins folder
    Write-Information "Cleaning up old .lvlibp files in plugins folder..." -InformationAction Continue
    Write-Verbose "Looking for .lvlibp files in $($RepositoryPath)\resource\plugins..."
    try {
        $PluginFiles = Get-ChildItem -Path "$RepositoryPath\resource\plugins" -Filter '*.lvlibp' -ErrorAction Stop
        if ($PluginFiles) {
            $pluginNames = $PluginFiles | ForEach-Object { $_.Name }
            Write-Verbose "Found $($PluginFiles.Count) file(s): $($pluginNames -join ', ')"
            $PluginFiles | Remove-Item -Force
            Write-Information "Deleted .lvlibp files from plugins folder." -InformationAction Continue
        }
        else {
            Write-Information "No .lvlibp files found to delete." -InformationAction Continue
        }
    }
    catch {
        Write-Error "Error occurred while retrieving .lvlibp files: $($_.Exception.Message)"
        Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    }

    # 2) Apply VIPC (32-bit)
    Write-Information "Applying VIPC (dependencies) for 32-bit..." -InformationAction Continue
    $ApplyVIPC = Join-Path $ActionsPath "apply-vipc/ApplyVIPC.ps1"
    Invoke-ScriptSafe -ScriptPath $ApplyVIPC -ArgumentList @(
        '-MinimumSupportedLVVersion','2021',
        '-VIP_LVVersion','2021',
        '-SupportedBitness','32',
        '-RepositoryPath', $RepositoryPath,
        '-VIPCPath','Tooling\deployment\runner_dependencies.vipc'
    )

    # 3) Build LV Library (32-bit)
    Write-Verbose "Building LV library (32-bit)..."
    $BuildLvlibp = Join-Path $ActionsPath "build-lvlibp/Build_lvlibp.ps1"
    $argsLvlibp32 = @{
        MinimumSupportedLVVersion = '2021'
        SupportedBitness          = '32'
        RepositoryPath            = $RepositoryPath
        Major                     = $Major
        Minor                     = $Minor
        Patch                     = $Patch
        Build                     = $Build
        Commit                    = $Commit
    }
    & $BuildLvlibp @argsLvlibp32

    # 4) Close LabVIEW (32-bit)
    Write-Verbose "Closing LabVIEW (32-bit)..."
    $CloseLabVIEW = Join-Path $ActionsPath "close-labview/Close_LabVIEW.ps1"
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','32')

    # 5) Rename .lvlibp -> lv_icon_x86.lvlibp
    Write-Verbose "Renaming .lvlibp file to lv_icon_x86.lvlibp..."
    $RenameFile = Join-Path $ActionsPath "rename-file/Rename-file.ps1"
    Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentList @('-CurrentFilename', "$RepositoryPath\resource\plugins\lv_icon.lvlibp", '-NewFilename', 'lv_icon_x86.lvlibp')

    # 6) Apply VIPC (64-bit)
    Write-Information "Applying VIPC (dependencies) for 64-bit..." -InformationAction Continue
    Invoke-ScriptSafe -ScriptPath $ApplyVIPC -ArgumentList @(
        '-MinimumSupportedLVVersion','2021',
        '-VIP_LVVersion','2021',
        '-SupportedBitness','64',
        '-RepositoryPath', $RepositoryPath,
        '-VIPCPath','Tooling\deployment\runner_dependencies.vipc'
    )

    # 7) Build LV Library (64-bit)
    Write-Verbose "Building LV library (64-bit)..."
    $argsLvlibp64 = @{
        MinimumSupportedLVVersion = '2021'
        SupportedBitness          = '64'
        RepositoryPath            = $RepositoryPath
        Major                     = $Major
        Minor                     = $Minor
        Patch                     = $Patch
        Build                     = $Build
        Commit                    = $Commit
    }
    & $BuildLvlibp @argsLvlibp64

    # 7.1) Close LabVIEW (64-bit)
    Write-Verbose "Closing LabVIEW (64-bit)..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentList @('-MinimumSupportedLVVersion','2021','-SupportedBitness','64')

    # Rename .lvlibp -> lv_icon_x64.lvlibp
    Write-Verbose "Renaming .lvlibp file to lv_icon_x64.lvlibp..."
    Invoke-ScriptSafe -ScriptPath $RenameFile -ArgumentList @('-CurrentFilename', "$RepositoryPath\resource\plugins\lv_icon.lvlibp", '-NewFilename', 'lv_icon_x64.lvlibp')

    # -------------------------------------------------------------------------
    # 8) Construct the JSON for "Company Name" & "Author Name", plus version
    # -------------------------------------------------------------------------
    # We include "Package Version" with your script parameters.
    # The rest of the fields remain empty or default as needed.
    $jsonObject = @{
        "Package Version" = @{
            "major" = $Major
            "minor" = $Minor
            "patch" = $Patch
            "build" = $Build
        }
        "Product Name"                  = ""
        "Company Name"                  = $CompanyName
        "Author Name (Person or Company)" = $AuthorName
        "Product Homepage (URL)"        = ""
        "Legal Copyright"               = ""
        "License Agreement Name"        = ""
        "Product Description Summary"   = ""
        "Product Description"           = ""
        "Release Notes - Change Log"    = ""
    }

    $DisplayInformationJSON = $jsonObject | ConvertTo-Json -Depth 3

    # 9) Modify VIPB Display Information
    Write-Verbose "Modify VIPB Display Information (64-bit)..."
    $ModifyVIPB = Join-Path $ActionsPath "modify-vipb-display-info/ModifyVIPBDisplayInfo.ps1"
    Invoke-ScriptSafe $ModifyVIPB `
        (
            # Use single-dash for all recognized parameters
            "-SupportedBitness 64 " +
            "-RepositoryPath `"$RepositoryPath`" " +
            "-VIPBPath `"Tooling\deployment\NI Icon editor.vipb`" " +
            "-MinimumSupportedLVVersion 2023 " +
            "-LabVIEWMinorRevision $LabVIEWMinorRevision " +
            "-Major $Major -Minor $Minor -Patch $Patch -Build $Build " +
            "-Commit `"$Commit`" " +
            "-ReleaseNotesFile `"$RepositoryPath\Tooling\deployment\release_notes.md`" " +
            # Pass our JSON
            "-DisplayInformationJSON '$DisplayInformationJSON' " +
            "-Verbose"
        )

    # 11) Build VI Package (64-bit) 2023
    Write-Verbose "Building VI Package (64-bit)..."
    $BuildVip = Join-Path $ActionsPath "build-vip/build_vip.ps1"
    Invoke-ScriptSafe $BuildVip `
        (
            # Use single-dash for all recognized parameters
            "-SupportedBitness 64 " +
            "-RepositoryPath `"$RepositoryPath`" " +
            "-VIPBPath `"Tooling\deployment\NI Icon editor.vipb`" " +
            "-MinimumSupportedLVVersion 2023 " +
            "-LabVIEWMinorRevision $LabVIEWMinorRevision " +
            "-Major $Major -Minor $Minor -Patch $Patch -Build $Build " +
            "-Commit `"$Commit`" " +
            "-ReleaseNotesFile `"$RepositoryPath\Tooling\deployment\release_notes.md`" " +
            # Pass our JSON
            "-DisplayInformationJSON '$DisplayInformationJSON' " +
            "-Verbose"
        )

    # 12) Close LabVIEW (64-bit)
    Write-Verbose "Closing LabVIEW (64-bit)..."
    Invoke-ScriptSafe -ScriptPath $CloseLabVIEW -ArgumentList @('-MinimumSupportedLVVersion','2023','-SupportedBitness','64')

    Write-Information "All scripts executed successfully!" -InformationAction Continue
    Write-Verbose "Script: Build.ps1 completed without errors."
}
catch {
    Write-Error "An unexpected error occurred during script execution: $($_.Exception.Message)"
    Write-Verbose "Stack Trace: $($_.Exception.StackTrace)"
    exit 1
}
