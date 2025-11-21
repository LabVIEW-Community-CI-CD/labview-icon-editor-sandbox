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
