$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "AgentPromptAliases.ps1" {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:Subject = Join-Path $script:RepoRoot 'scripts/ollama-executor/AgentPromptAliases.ps1'
    }

    It "script exists" {
        Test-Path $script:Subject | Should -BeTrue
    }

    It "has valid PowerShell syntax" {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:Subject, [ref]$null, [ref]$errors) | Out-Null
        $errors.Count | Should -Be 0
    }

    Context "seed2021 alias" {
        It "returns expected prompt for seed2021 keyword" {
            $result = & $script:Subject -Keyword 'seed2021'
            $result | Should -Match 'LabVIEW 2021 Q1 64-bit'
            $result | Should -Match 'create-seeded-branch\.ps1'
            $result | Should -Match '-LabVIEWVersion 2021'
            $result | Should -Match '-LabVIEWMinor 0'
            $result | Should -Match '-Bitness 64'
        }

        It "is case insensitive" {
            $lower = & $script:Subject -Keyword 'seed2021'
            $upper = & $script:Subject -Keyword 'SEED2021'
            $mixed = & $script:Subject -Keyword 'Seed2021'
            $lower | Should -Be $upper
            $lower | Should -Be $mixed
        }

        It "references correct branch pattern" {
            $result = & $script:Subject -Keyword 'seed2021'
            $result | Should -Match 'seed/lv2021q1-64bit'
        }
    }

    Context "error handling" {
        It "throws for unknown keyword" {
            { & $script:Subject -Keyword 'unknown_keyword' } | Should -Throw "*Unknown keyword*"
        }

        It "lists valid keywords in error message" {
            try {
                & $script:Subject -Keyword 'invalid' 2>$null
            } catch {
                $_.Exception.Message | Should -Match 'seed2021'
            }
        }
    }
}
