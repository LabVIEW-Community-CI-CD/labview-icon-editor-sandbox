$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Describe "VSCode Dev Mode Task wiring" {
    It "Set/ Revert Dev Mode tasks contain required flags to avoid quoting errors" {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $tasksPath = Join-Path $repoRoot '.vscode/tasks.json'
        Test-Path -LiteralPath $tasksPath | Should -BeTrue

        $json = Get-Content -LiteralPath $tasksPath -Raw | ConvertFrom-Json
        $labels = @("Set Dev Mode (LabVIEW)", "Revert Dev Mode (LabVIEW)")
        foreach ($label in $labels) {
            $task = $json.tasks | Where-Object { $_.label -eq $label } | Select-Object -First 1
            $task | Should -Not -BeNullOrEmpty
            $command = ($task.args -join ' ')
            # Ensure we don't use single-quoted -Command wrappers that break $ErrorActionPreference or path resolution
            $command | Should -Match "-NoProfile"
            $command | Should -Match "-Command"
            $command | Should -Not -Match "Stop: The term 'Stop' is not recognized"
            $command -like "*`$ErrorActionPreference='Stop'*" | Should -BeTrue
            $command | Should -Match "--RepositoryPath| -RepositoryPath|`-RepositoryPath"
            $command | Should -Match "Set_Development_Mode.ps1|RevertDevelopmentMode.ps1"
            $command | Should -Match '\$\{input:repoPath\}'
            $command | Should -Match '\$\{workspaceFolder\}/\.github/actions/'
        }
    }
}
