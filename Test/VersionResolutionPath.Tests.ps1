$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$repoRoot = Split-Path -Parent $PSScriptRoot
$workflowPath = Join-Path $repoRoot '.github/workflows/ci-composite.yml'
$actionPath = Join-Path $repoRoot '.github/actions/run-unit-tests/action.yml'

Describe "LabVIEW version resolution wiring" {
    BeforeAll {
        Test-Path -LiteralPath $workflowPath | Should -BeTrue
        Test-Path -LiteralPath $actionPath   | Should -BeTrue

        $script:Workflow = Get-Content -LiteralPath $workflowPath -Raw | ConvertFrom-Yaml
        $script:Action   = Get-Content -LiteralPath $actionPath -Raw   | ConvertFrom-Yaml
    }

    Context "resolve-labview-version job" {
        It "invokes get-package-lv-version.ps1 from the workspace root" {
            $job = $script:Workflow.jobs.'resolve-labview-version'
            $job | Should -Not -BeNullOrEmpty

            $readStep = @($job.steps) | Where-Object { $_.id -eq 'read' }
            $readStep | Should -Not -BeNullOrEmpty

            $readStep.run | Should -Match '\$env:GITHUB_WORKSPACE/scripts/get-package-lv-version\.ps1'
        }
    }

    Context "unit-test jobs" {
        BeforeAll {
            $script:ExpectedVersionExpr = '${{ needs.resolve-labview-version.outputs.minimum_supported_lv_version }}'
        }

        It "propagates the resolved version into both x64 and x86 runs" {
            foreach ($jobKey in 'test-x64', 'test-x86') {
                $job = $script:Workflow.jobs.$jobKey
                $job | Should -Not -BeNullOrEmpty

                $job.env.LABVIEW_VERSION | Should -Be $script:ExpectedVersionExpr

                $unitStep = @($job.steps) | Where-Object { $_.uses -eq './.github/actions/run-unit-tests' }
                $unitStep | Should -Not -BeNullOrEmpty
                $unitStep.with.labview_version | Should -Be $script:ExpectedVersionExpr
            }
        }
    }

    Context "run-unit-tests composite action" {
        It "relies on provided labview_version input or LABVIEW_VERSION env and passes it to RunUnitTests.ps1" {
            $runStep = @($script:Action.runs.steps) | Where-Object { $_.name -eq 'Run RunUnitTests.ps1' }
            $runStep | Should -Not -BeNullOrEmpty

            $scriptBlock = $runStep.run
            $scriptBlock | Should -Match '\$Env:LABVIEW_VERSION'
            $scriptBlock | Should -Match '-Package_LabVIEW_Version \$lvVer'
            $scriptBlock | Should -Not -Match 'get-package-lv-version\.ps1'
        }
    }
}
