<#
.SYNOPSIS
Previews original robot + AI contribution art for January-October 2026.
.DESCRIPTION
The default operation only writes a preview and commit plan. -CreateCommits
creates a NEW local personal repository with explicitly backdated artwork
commits. This script never pushes, overwrites a repository, or changes global
Git configuration. Calendar colors are illustrative, not guaranteed by GitHub.
.EXAMPLE
.\New-RobotAiArt.ps1
.EXAMPLE
.\New-RobotAiArt.ps1 -CreateCommits -CommitEmail 'YOUR_VERIFIED_GITHUB_EMAIL'
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = $PSScriptRoot,
    [switch]$CreateCommits,
    [string]$CommitEmail,
    [ValidateRange(1, 100)]
    [int]$CommitsPerPixel = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$start = [datetime]'2026-01-01'
$end = [datetime]'2026-10-31'
if ($end.Date -gt (Get-Date).Date) {
    throw 'The selected end date is in the future. Only past dates are allowed.'
}

# Start artwork on a complete Sunday-Saturday week.
$firstSunday = $start.AddDays((7 - [int]$start.DayOfWeek) % 7)
# Each string is a day row; character columns become weeks. Only '1' is lit.
$tile = @(
    '00100 010 111',
    '01110 101 010',
    '11111 101 010',
    '10101 111 010',
    '11111 101 010',
    '10001 101 010',
    '01110 101 111'
)
$tileWidth = $tile[0].Length
$period = $tileWidth + 2
$completeWeeks = [int][math]::Floor(($end.AddDays(1) - $firstSunday).TotalDays / 7)
# R tiles occupy R * tileWidth + (R - 1) * 2 weeks: no trailing gap is needed.
$repetitions = [int][math]::Floor(($completeWeeks + 2) / $period)
if ($repetitions -lt 1) {
    throw 'The date range does not contain a complete robot + AI motif.'
}

$plan = [System.Collections.Generic.List[object]]::new()
$litDates = [System.Collections.Generic.HashSet[string]]::new()
for ($repeat = 0; $repeat -lt $repetitions; $repeat++) {
    for ($column = 0; $column -lt $tileWidth; $column++) {
        for ($row = 0; $row -lt 7; $row++) {
            if ($tile[$row][$column] -ne '1') { continue }
            # Move to this repetition's week, then select Sunday (0) through Saturday (6).
            $date = $firstSunday.AddDays(($repeat * $period + $column) * 7 + $row)
            if ($date -lt $start -or $date -gt $end) {
                throw "Artwork date outside the requested range: $date"
            }
            $key = $date.ToString('yyyy-MM-dd')
            [void]$litDates.Add($key)
            $plan.Add([pscustomobject]@{
                Date = $key
                Commits = $CommitsPerPixel
                Motif = $repeat + 1
            })
        }
    }
}

$output = [System.IO.Path]::GetFullPath($OutputDirectory)
[void][System.IO.Directory]::CreateDirectory($output)
$planPath = Join-Path $output 'commit-plan.csv'
$plan | Export-Csv -LiteralPath $planPath -NoTypeInformation -Encoding utf8

# Include boundary weeks in the preview, but hide dates outside the requested range.
$gridStart = $start.AddDays(-[int]$start.DayOfWeek)
$gridWeeks = [int][math]::Ceiling(($end.AddDays(1) - $gridStart).TotalDays / 7)
$cells = [System.Text.StringBuilder]::new()
for ($week = 0; $week -lt $gridWeeks; $week++) {
    for ($day = 0; $day -lt 7; $day++) {
        $date = $gridStart.AddDays($week * 7 + $day)
        $key = $date.ToString('yyyy-MM-dd')
        $class = if ($date -lt $start -or $date -gt $end) {
            'outside'
        } elseif ($litDates.Contains($key)) {
            'lit'
        } else {
            'blank'
        }
        $count = if ($class -eq 'lit') { $CommitsPerPixel } else { 0 }
        [void]$cells.AppendLine(
            "<div class='cell $class' title='$key : $count generated commits'></div>"
        )
    }
}
$total = $plan.Count * $CommitsPerPixel
$html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ketaki - Robot + AI contribution art preview</title>
<style>
body{background:#0d1117;color:#e6edf3;font:16px system-ui,sans-serif;margin:0;padding:24px}
main{max-width:1100px;margin:auto}
h1{font-size:28px}.muted{color:#9198a1;line-height:1.6}
.scroll{overflow-x:auto;padding:22px 0}
.calendar{display:grid;grid-template-rows:repeat(7,10px);grid-auto-flow:column;grid-auto-columns:10px;gap:2px;width:max-content}
.cell{border-radius:3px;border:1px solid #ffffff0d}
.blank{background:#161b22}.lit{background:#39d353}.outside{visibility:hidden}
.note{border:1px solid #30363d;border-radius:8px;padding:18px;margin-top:20px}
code{color:#79c0ff}
</style>
</head>
<body><main>
<h1>Robot + AI / 2026</h1>
<p class="muted">Original generated calendar art for <strong>ketakisbarde</strong>.
January 1-October 31, 2026. Sunday is the top row; weeks run left to right.</p>
<div class="scroll"><div class="calendar">
$($cells.ToString())
</div></div>
<p>$repetitions motifs &middot; $($plan.Count) lit days &middot; $total planned commits
&middot; $CommitsPerPixel commits per lit day</p>
<div class="note"><strong>Preview only - nothing pushed.</strong>
<p class="muted">This shows artwork alone, not your existing GitHub contributions.
Real contributions cannot be erased by blank pixels and may obscure the pattern.
GitHub chooses green shades based on contribution counts, so actual colors can differ.</p>
<p class="muted">Use a new personal <code>gitfiti-art</code> repository.
These are deliberately backdated art commits, not a record of engineering work.
Commits must use an email associated with your GitHub account and be pushed to
the repository's default branch to count. Profile updates can take time.</p></div>
</main></body></html>
"@
$previewPath = Join-Path $output 'preview.html'
[System.IO.File]::WriteAllText($previewPath, $html)

Write-Output "Preview: $previewPath"
Write-Output "Plan: $planPath"
Write-Output "Motifs: $repetitions; lit days: $($plan.Count); planned commits: $total"

# Preview is the default; Git history changes require the explicit switch.
if (-not $CreateCommits) { return }
if ([string]::IsNullOrWhiteSpace($CommitEmail) -or
    $CommitEmail -notmatch '^[^\s@]+@[^\s@]+$') {
    throw 'Supply -CommitEmail with an email verified on your personal GitHub account.'
}
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git is required to create commits.'
}
$repo = Join-Path $output 'gitfiti-art'
if (Test-Path -LiteralPath $repo) {
    throw "Refusing to overwrite an existing path: $repo"
}

function Invoke-ArtGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    & git --no-pager -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed with exit code $LASTEXITCODE during: $($Arguments[0])"
    }
}

[void][System.IO.Directory]::CreateDirectory($repo)
Invoke-ArtGit -Arguments @('init', '--initial-branch=main')
Invoke-ArtGit -Arguments @('config', '--local', 'user.name', 'Ketaki Barde')
Invoke-ArtGit -Arguments @('config', '--local', 'user.email', $CommitEmail)
Invoke-ArtGit -Arguments @(
    'remote', 'add', 'origin', 'https://github.com/ketakisbarde/gitfiti-art.git'
)
$readme = @'
# Robot + AI contribution-calendar art

Original pixel art with three robot + AI motifs across January-October 2026.

**The commits in this repository are intentionally backdated, generated artwork.
They do not represent software development performed on those dates.**

Inspired by the contribution-calendar art concept of
[gelstudios/gitfiti](https://github.com/gelstudios/gitfiti).

The generator and date/count plan are included for transparency.
Existing contributions and GitHub's color scale can affect the appearance.
'@
[System.IO.File]::WriteAllText((Join-Path $repo 'README.md'), $readme)
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $repo 'New-RobotAiArt.ps1')
Copy-Item -LiteralPath $planPath -Destination (Join-Path $repo 'commit-plan.csv')
Invoke-ArtGit -Arguments @('add', 'README.md', 'New-RobotAiArt.ps1', 'commit-plan.csv')

# Staged files enter the first pixel commit; later commits can be empty.
# Both timestamps are backdated, and the caller's environment is restored afterward.
$oldAuthorDate = $env:GIT_AUTHOR_DATE
$oldCommitterDate = $env:GIT_COMMITTER_DATE
try {
    foreach ($pixel in $plan) {
        for ($index = 1; $index -le $pixel.Commits; $index++) {
            # UTC noon keeps these timestamps away from local midnight.
            $stamp = "$($pixel.Date)T12:00:00+00:00"
            $env:GIT_AUTHOR_DATE = $stamp
            $env:GIT_COMMITTER_DATE = $stamp
            $message = "Generated robot + AI art: $($pixel.Date) pixel $index"
            Invoke-ArtGit -Arguments @(
                '-c', 'commit.gpgsign=false',
                'commit', '--allow-empty', '--quiet', '-m', $message,
                '-m', 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
            )
        }
    }
} finally {
    $env:GIT_AUTHOR_DATE = $oldAuthorDate
    $env:GIT_COMMITTER_DATE = $oldCommitterDate
}

$actualCount = & git --no-pager -C $repo rev-list --count HEAD
if ($LASTEXITCODE -ne 0 -or [int]$actualCount -ne $total) {
    throw "Commit-count verification failed. Expected $total; got $actualCount."
}
Write-Output "Created and verified $actualCount LOCAL art commits in $repo."
Write-Output 'Nothing pushed. Create an empty personal GitHub repo named gitfiti-art.'
Write-Output "After reviewing it, publish with: git -C `"$repo`" push -u origin main"
