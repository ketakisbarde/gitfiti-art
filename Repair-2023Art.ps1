<#
.SYNOPSIS
Compares the public 2023 calendar with its art plan and previews missing counts.
.DESCRIPTION
-CreateCommits adds only currently missing public counts as explicitly backdated
art commits. It never rewrites history or pushes. A later GitHub reindex can count
the original missing commits too, changing shades but not pixel positions.
#>
[CmdletBinding()]
param(
    [string]$Repository = 'C:\temp\ketakisbarde-gitfiti-2026\gitfiti-art',
    [string]$OutputDirectory = $PSScriptRoot,
    [switch]$CreateCommits
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repo = [System.IO.Path]::GetFullPath($Repository)
function Invoke-ArtGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $result = & git --no-pager -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed during: $($Arguments[0])" }
    $result
}
$root = Invoke-ArtGit -Arguments @('rev-parse', '--show-toplevel')
if ([System.IO.Path]::GetFullPath($root) -ne $repo) { throw 'Unexpected repository root.' }
if ((Invoke-ArtGit -Arguments @('remote', 'get-url', 'origin')) -ne
    'https://github.com/ketakisbarde/gitfiti-art.git') { throw 'Unexpected remote.' }
$plan = @(Import-Csv -LiteralPath (Join-Path $repo 'commit-plan-2023.csv'))
if ($plan.Count -ne 158) { throw 'Unexpected 2023 plan size.' }
$uri = 'https://github.com/users/ketakisbarde/contributions?from=2023-01-01&to=2023-12-31'
$html = (Invoke-WebRequest -Uri $uri -TimeoutSec 30).Content
# Parse dates and their accessible tooltips, not the visually chosen green shades.
$pattern = '<td\b[^>]*data-date="(?<date>2023-\d{2}-\d{2})"[^>]*data-level="[0-4]"[^>]*></td>\s*<tool-tip\b[^>]*>(?<text>.*?)</tool-tip>'
$matches = [regex]::Matches($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
if ($matches.Count -ne 365) { throw 'GitHub calendar markup changed or is incomplete.' }
$days = @{}
foreach ($match in $matches) {
    $date = $match.Groups['date'].Value
    if ($days.ContainsKey($date)) { throw "Duplicate GitHub date: $date" }
    $text = $match.Groups['text'].Value
    $countMatch = [regex]::Match($text, '(?<count>[\d,]+) contributions? on')
    if ($text -match 'No contributions on') { $count = 0 }
    elseif ($countMatch.Success) {
        $count = [int]$countMatch.Groups['count'].Value.Replace(',', '')
    } else { throw "Cannot parse contribution count for $date." }
    $days[$date] = $count
}
$repair = @(
    foreach ($pixel in $plan) {
        $date = [datetime]::ParseExact($pixel.Date, 'yyyy-MM-dd', $null)
        if ($date.Year -ne 2023 -or [int]$pixel.Commits -ne 4) {
            throw 'Unexpected date or intensity in original plan.'
        }
        $missing = [math]::Max(0, [int]$pixel.Commits - $days[$pixel.Date])
        if ($missing -gt 0) {
            [pscustomobject]@{
                Date = $pixel.Date
                Expected = [int]$pixel.Commits
                GitHubBefore = $days[$pixel.Date]
                MissingCommits = $missing
            }
        }
    }
)
if ($repair.Count -eq 0) {
    Write-Output 'All planned pixels are already visible. No repair required.'
    return
}
$total = [int]($repair | Measure-Object MissingCommits -Sum).Sum
if ($total -ge 1000) { throw 'Repair is too large for a single small push.' }
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
[void][System.IO.Directory]::CreateDirectory($output)
$snapshot = Join-Path $output 'repair-plan-2023.csv'
$repair | Export-Csv -LiteralPath $snapshot -NoTypeInformation -Encoding utf8
Write-Output "Currently missing: $total contributions across $($repair.Count) dates."
Write-Output "Snapshot: $snapshot"
if (-not $CreateCommits) { return }
if ((Invoke-ArtGit -Arguments @('branch', '--show-current')) -ne 'main') {
    throw 'The art repository must be on main.'
}
if (@(Invoke-ArtGit -Arguments @('status', '--porcelain')).Count) {
    throw 'Repository is dirty; stopped before editing it.'
}
if ((Invoke-ArtGit -Arguments @('config', '--local', '--get', 'user.email')) -ne
    'ketakibarde97@gmail.com') { throw 'Unexpected personal commit identity.' }
$destinationSnapshot = Join-Path $repo 'repair-plan-2023.csv'
$destinationScript = Join-Path $repo 'Repair-2023Art.ps1'
if ((Test-Path -LiteralPath $destinationSnapshot) -or
    (Test-Path -LiteralPath $destinationScript)) {
    throw 'A repair already exists; refusing to add duplicate repair commits.'
}
$oldHead = Invoke-ArtGit -Arguments @('rev-parse', 'HEAD')
$before = [int](Invoke-ArtGit -Arguments @('rev-list', '--count', 'HEAD'))
Copy-Item -LiteralPath $snapshot -Destination $destinationSnapshot
Copy-Item -LiteralPath $PSCommandPath -Destination $destinationScript
Invoke-ArtGit -Arguments @('add', 'repair-plan-2023.csv', 'Repair-2023Art.ps1')
$oldAuthorDate = $env:GIT_AUTHOR_DATE
$oldCommitterDate = $env:GIT_COMMITTER_DATE
try {
    foreach ($pixel in $repair) {
        for ($index = 1; $index -le $pixel.MissingCommits; $index++) {
            $env:GIT_AUTHOR_DATE = "$($pixel.Date)T12:00:00+00:00"
            $env:GIT_COMMITTER_DATE = $env:GIT_AUTHOR_DATE
            Invoke-ArtGit -Arguments @(
                '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '--quiet',
                '-m', "Repair missing public 2023 art: $($pixel.Date) pixel $index",
                '-m', 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
            )
        }
    }
} finally {
    $env:GIT_AUTHOR_DATE = $oldAuthorDate
    $env:GIT_COMMITTER_DATE = $oldCommitterDate
}
if ([int](Invoke-ArtGit -Arguments @('rev-list', '--count', 'HEAD')) -ne $before + $total) {
    throw 'Repair commit-count verification failed.'
}
Invoke-ArtGit -Arguments @('merge-base', '--is-ancestor', $oldHead, 'HEAD')
Write-Output "Created $total LOCAL repair commits without rewriting any history."
Write-Output 'No push performed. Verify the calendar again after publishing.'
