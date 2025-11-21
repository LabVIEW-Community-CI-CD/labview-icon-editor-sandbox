$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Get-ParamDefaults {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
    $params = @{}
    $paramBlock = $ast.ParamBlock
    if ($paramBlock) {
        foreach ($param in $paramBlock.Parameters) {
            $name = $param.Name.VariablePath.UserPath
            $default = $param.DefaultValue
            if ($default) {
                $params[$name] = $default.Extent.Text.Trim("'\"")
            } else {
                $params[$name] = $null
            }
        }
    }
    return $params
}

Describe "Dev mode scripts alignment" {
    $setPath = Join-Path $PSScriptRoot ".." ".github/actions/set-development-mode/Set_Development_Mode.ps1"
    $revertPath = Join-Path $PSScriptRoot ".." ".github/actions/revert-development-mode/RevertDevelopmentMode.ps1"

    It "Set_Development_Mode.ps1 declares MinimumSupportedLVVersion defaulting to 2021" {
        Test-Path $setPath | Should -BeTrue
        $params = Get-ParamDefaults -Path $setPath
        $params.Keys | Should -Contain 'MinimumSupportedLVVersion'
        $params['MinimumSupportedLVVersion'] | Should -Be '2021'
    }

    It "RevertDevelopmentMode.ps1 declares MinimumSupportedLVVersion defaulting to 2021" {
        Test-Path $revertPath | Should -BeTrue
        $params = Get-ParamDefaults -Path $revertPath
        $params.Keys | Should -Contain 'MinimumSupportedLVVersion'
        $params['MinimumSupportedLVVersion'] | Should -Be '2021'
    }
}
