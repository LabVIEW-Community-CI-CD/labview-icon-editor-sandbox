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
