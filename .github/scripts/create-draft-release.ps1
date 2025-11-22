[CmdletBinding()]
param(
    [Parameter()][string]$RepositoryPath = ".",
    [Parameter()][string]$VipPath = "builds/VI Package",
    [Parameter()][string]$ReleaseNotesPath = "Tooling/deployment/release_notes.md",
    [Parameter()][string]$Tag,
    [Parameter()][string]$Title,
    [Parameter()][int]$Major,
    [Parameter()][int]$Minor,
    [Parameter()][int]$Patch,
    [Parameter()][int]$Build = 0,
    [Parameter()][bool]$Prerelease = $false
)

$ErrorActionPreference = 'Stop'
$repoRoot = Resolve-Path -Path $RepositoryPath

function Resolve-Asset {
    param(
        [string]$Path,
        [string]$Description,
        [string]$DefaultFilter
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path -Path $repoRoot -ChildPath $Path }

    if (Test-Path -LiteralPath $candidate -PathType Leaf) {
        return Get-Item -LiteralPath $candidate
    }

    $dir = $candidate
    $filter = $DefaultFilter

    if (-not (Test-Path -LiteralPath $dir)) {
        $dir = Split-Path -Path $candidate -Parent
        $leaf = Split-Path -Path $candidate -Leaf
        if ($leaf -and $leaf -ne '.' -and $leaf -ne '..') { $filter = $leaf }
    }
    elseif (Test-Path -LiteralPath $dir -PathType Leaf) {
        $dir = Split-Path -Path $candidate -Parent
    }

    $match = Get-ChildItem -Path $dir -Filter $filter -File -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $match) {
        throw ("{0} not found. Checked '{1}' with filter '{2}'." -f $Description, $dir, $filter)
    }

    return $match
}

Push-Location -LiteralPath $repoRoot

try {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "GitHub CLI (gh) not found. Install it and ensure it is on PATH."
    }

    $token = $Env:GH_TOKEN
    if (-not $token) {
        $token = $Env:GITHUB_TOKEN
    }
    if (-not $token) {
        throw "Set GH_TOKEN or GITHUB_TOKEN so the GitHub CLI can create the draft release."
    }
    $Env:GH_TOKEN = $token

    $vipFile = Resolve-Asset -Path $VipPath -Description "VI Package (.vip)" -DefaultFilter "*.vip"
    $notesFile = Resolve-Asset -Path $ReleaseNotesPath -Description "Release notes" -DefaultFilter "*.md"

    if (-not $Tag) {
        if ($PSBoundParameters.ContainsKey('Major') -and $PSBoundParameters.ContainsKey('Minor') -and $PSBoundParameters.ContainsKey('Patch')) {
            $Tag = ("v{0}.{1}.{2}.{3}" -f $Major, $Minor, $Patch, $Build)
        }
        else {
            throw "Provide -Tag or all of -Major, -Minor, -Patch, -Build so a tag can be derived."
        }
    }

    if (-not $Title) {
        $Title = $Tag
    }

    $assetList = @($vipFile.FullName, $notesFile.FullName)

    $releaseExists = $false
    try {
        & gh release view $Tag *> $null
        $releaseExists = $LASTEXITCODE -eq 0
    }
    catch {
        $releaseExists = $false
        $global:LASTEXITCODE = 0
    }

    if ($releaseExists) {
        Write-Host ("Release {0} exists; updating draft metadata and refreshing assets." -f $Tag)
        $editArgs = @('release', 'edit', $Tag, '--draft', '--title', $Title, '--notes-file', $notesFile.FullName)
        if ($Prerelease) { $editArgs += '--prerelease' }
        & gh @editArgs

        $uploadArgs = @('release', 'upload', $Tag) + $assetList + '--clobber'
        & gh @uploadArgs
    }
    else {
        Write-Host ("Creating draft release {0} and uploading assets." -f $Tag)
        $createArgs = @('release', 'create', $Tag) + $assetList + @('--draft', '--title', $Title, '--notes-file', $notesFile.FullName)
        if ($Prerelease) { $createArgs += '--prerelease' }
        & gh @createArgs
    }

    Write-Host ("Attached assets:`n- {0}`n- {1}" -f $vipFile.Name, $notesFile.Name)
}
finally {
    Pop-Location
}
