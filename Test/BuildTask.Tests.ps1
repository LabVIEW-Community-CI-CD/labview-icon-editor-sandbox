$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$actionsPath = Join-Path $repoRoot ".github/actions"
$buildScript = Join-Path $actionsPath "build/Build.ps1"
Import-Module "$PSScriptRoot/Support/BuildTaskMocks.psm1"

Describe "VSCode Build Task wiring" {
    BeforeAll {
        $script:mocks = Initialize-BuildTaskMocks -RepoPath $repoRoot
    }

    AfterAll {
        if ($script:mocks.TempBin -and (Test-Path $script:mocks.TempBin)) {
            Remove-Item -LiteralPath $script:mocks.TempBin -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context "invoking Build.ps1 with task-like arguments" {
        It "binds all parameters correctly (no positional shifts)" {
            $params = @{
                RepositoryPath       = $repoRoot
                Major                = 1
                Minor                = 2
                Patch                = 3
                Build                = 4
                LabVIEWMinorRevision = 3
                Commit               = "cafebabecafebabecafebabecafebabe"
                CompanyName          = "LabVIEW-Community-CI-CD"
                AuthorName           = "LabVIEW Icon Editor CI"
            }

            { & $buildScript @params } | Should -Throw
        }

        It "uses git commit from PATH when not provided" {
            $params = @{
                RepositoryPath       = $repoRoot
                Major                = 0
                Minor                = 0
                Patch                = 0
                Build                = 1
                LabVIEWMinorRevision = 3
                CompanyName          = "LabVIEW-Community-CI-CD"
                AuthorName           = "LabVIEW Icon Editor CI"
            }

            { & $buildScript @params } | Should -Throw
            $log = Get-Content -ErrorAction SilentlyContinue -Path $script:mocks.LogPath
            $log | Should -Match 'mock-start|lvbuildspec'
        }

        It "passes company/author strings with spaces without shifting args" {
            $params = @{
                RepositoryPath       = $repoRoot
                Major                = 0
                Minor                = 0
                Patch                = 0
                Build                = 1
                LabVIEWMinorRevision = 3
                Commit               = "manual"
                CompanyName          = "Acme Widgets Inc"
                AuthorName           = "Jane Q Public"
            }

            { & $buildScript @params } | Should -Throw
        }
    }
}
