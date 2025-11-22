$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VIPB LabVIEW version parsing" {
    It "detects Package_LabVIEW_Version and derives the 4-digit year" {
        $vipb = Get-ChildItem -Path $PSScriptRoot/.. -Filter *.vipb -File -Recurse | Select-Object -First 1
        $vipb | Should -Not -BeNullOrEmpty

        $text = Get-Content -LiteralPath $vipb.FullName -Raw
        $match = [regex]::Match($text, '<Package_LabVIEW_Version>(?<ver>[^<]+)</Package_LabVIEW_Version>', 'IgnoreCase')
        $match.Success | Should -BeTrue

        $raw = $match.Groups['ver'].Value
        $raw | Should -Match '^\d{2}\.\d'

        $verMatch = [regex]::Match($raw, '^(?<majmin>\d{2}\.\d)')
        $verMatch.Success | Should -BeTrue

        $maj = [int]($verMatch.Groups['majmin'].Value.Split('.')[0])
        $derived = if ($maj -ge 20) { "20$maj" } else { $maj.ToString() }

        # Current VIPB targets LabVIEW 2021 (21.x) for dev-mode prep.
        $derived | Should -Be '2021'
    }
}

Describe "run-dev-mode.ps1" {
    $scriptPath = (Resolve-Path (Join-Path $PSScriptRoot '..\.github\actions\set-development-mode\run-dev-mode.ps1')).Path
    $repoRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

    It "fails fast and surfaces g-cli --help errors" {
        function global:g-cli { }
        Mock -CommandName Get-Command -MockWith { [pscustomobject]@{ Name = 'g-cli'; Source = 'mock://g-cli' } }
        Mock -CommandName g-cli -MockWith { $global:LASTEXITCODE = 99 }
        $ex = $null
        try {
            & $scriptPath -RepositoryPath $repoRoot
        } catch {
            $ex = $_
        }

        $ex | Should -Not -BeNullOrEmpty
        $ex.Exception.Message | Should -Match 'exit code 99|pipeline element'
        Remove-Item function:g-cli -ErrorAction SilentlyContinue
    }
}

Describe "AddTokenToLabVIEW guard" {
    It "removes stale double-rooted LocalHost.LibraryPaths entries and warns" {
        $helperPath = (Resolve-Path (Join-Path $PSScriptRoot '..\.github\actions\add-token-to-labview\LocalhostLibraryPaths.ps1')).Path
        . $helperPath

        $iniPath = Join-Path $TestDrive 'LabVIEW.ini'
        $iniContent = @(
            'LocalHost.LibraryPaths1=C:\actions-runner\_work\actions-runner\_work\labview-icon-editor\labview-icon-editor',
            'LocalHost.LibraryPaths2=C:\valid\repo',
            'Other=keep'
        )
        Set-Content -LiteralPath $iniPath -Value $iniContent
        $env:LV_INI_OVERRIDE_PATH = $iniPath
        try {
            $warnings = & { Clear-StaleLibraryPaths -LvVersion '2021' -Arch '64' -RepositoryRoot 'C:\repo' } 3>&1
        }
        finally {
            Remove-Item Env:LV_INI_OVERRIDE_PATH -ErrorAction SilentlyContinue
        }

        $updated = Get-Content -LiteralPath $iniPath
        ($updated -join "`n") | Should -Not -Match 'actions-runner\\_work\\actions-runner\\_work'
        $updated | Should -Contain 'LocalHost.LibraryPaths2=C:\valid\repo'
        $updated | Should -Contain 'Other=keep'
        $warnings | Where-Object { $_ -like '*Removed*stale LocalHost.LibraryPaths*' } | Should -Not -BeNullOrEmpty
    }
}
