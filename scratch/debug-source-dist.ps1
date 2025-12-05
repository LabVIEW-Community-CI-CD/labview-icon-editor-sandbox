Import-Module './Test/Support/SyntheticRepoFixtures.psm1' -Force
Import-Module './Test/Support/SourceDistTestHelpers.psm1' -Force

$fx = New-SyntheticRepo -IncludeSupport
$dist = Join-Path $fx.Path 'builds/LabVIEWIconAPI'
$envOverrides = @{ BUILD_SD_TEST_DIST = $dist; BUILD_SD_TEST_PAYLOADS = 'resource/plugins/generated/sample.vi' }
$stub = New-GcliStub

$build = Invoke-OrchestrationCli -RepoPath $fx.Path -Subcommand 'source-dist-build' -Args @('--gcli-path',$stub.Path,'--lv-version','2025','--bitness','64') -EnvOverrides $envOverrides
Write-Host "build exit $($build.ExitCode)"

$manifestPath = Join-Path $dist 'manifest.json'
Write-Host 'manifest before:'
Get-Content -LiteralPath $manifestPath -Raw | Write-Host

Set-ManifestMutation -ManifestPath $manifestPath -MutationType 'commit_mismatch'
Write-Host 'manifest after:'
Get-Content -LiteralPath $manifestPath -Raw | Write-Host

Update-SourceDistZip -DistRoot $dist -ZipPath (Join-Path $fx.Path 'builds/artifacts/source-distribution.zip')

$verify = Invoke-OrchestrationCli -RepoPath $fx.Path -Subcommand 'source-dist-verify'
Write-Host "verify exit $($verify.ExitCode)"
Write-Host 'verify stdout:'
Write-Host $verify.StdOut
Write-Host 'verify stderr:'
Write-Host $verify.StdErr

$fx.Dispose.Invoke($fx.Path)
$stub.Dispose.Invoke($stub.Root)
