<#
.SYNOPSIS
Previews MY NINJA WAY lettering centered on the 2025 contribution calendar.
.DESCRIPTION
Default operation writes only a preview and plan. -CreateCommits appends
explicitly backdated art commits to the existing personal gitfiti-art repo.
It never pushes or rewrites existing commits.
#>
[CmdletBinding()]
param(
    [string]$OutputDirectory = $PSScriptRoot,
    [string]$Repository = 'C:\temp\ketakisbarde-gitfiti-2026\gitfiti-art',
    [switch]$CreateCommits,
    [ValidateRange(1, 100)]
    [int]$CommitsPerPixel = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$start = [datetime]'2025-01-01'
$end = [datetime]'2025-12-31'
if ($end -gt (Get-Date).Date) { throw 'Artwork dates must be in the past.' }
$firstSunday = $start.AddDays((7 - [int]$start.DayOfWeek) % 7)
# Glyphs have seven day rows; their widths vary to fit the phrase into one year.
$letters = @{
    M = @('10001', '11011', '10101', '10101', '10001', '10001', '10001')
    Y = @('101', '101', '101', '010', '010', '010', '010')
    N = @('1001', '1101', '1101', '1011', '1011', '1001', '1001')
    I = @('111', '010', '010', '010', '010', '010', '111')
    J = @('111', '001', '001', '001', '101', '101', '010')
    A = @('010', '101', '101', '111', '101', '101', '101')
    W = @('10001', '10001', '10001', '10101', '10101', '10101', '01010')
    ' ' = @('0', '0', '0', '0', '0', '0', '0')
}
$word = 'MY NINJA WAY'
# Join glyph rows with one blank week. A space glyph makes word gaps three weeks wide.
$rows = @(
    for ($row = 0; $row -lt 7; $row++) {
        (@(foreach ($character in $word.ToCharArray()) {
            $letters[[string]$character][$row]
        }) -join '0')
    }
)
$width = $rows[0].Length
$completeWeeks = [int][math]::Floor(($end.AddDays(1) - $firstSunday).TotalDays / 7)
if ($width -gt $completeWeeks) { throw 'The word does not fit the year.' }
# Divide unused complete weeks between the left and right margins.
$offset = [int][math]::Floor(($completeWeeks - $width) / 2)
$plan = [System.Collections.Generic.List[object]]::new()
$litDates = [System.Collections.Generic.HashSet[string]]::new()
for ($column = 0; $column -lt $width; $column++) {
    for ($row = 0; $row -lt 7; $row++) {
        if ($rows[$row][$column] -ne '1') { continue }
        # Column selects the week; row selects Sunday (0) through Saturday (6).
        $date = $firstSunday.AddDays(($offset + $column) * 7 + $row)
        if ($date -lt $start -or $date -gt $end) { throw 'Pixel outside 2025.' }
        $key = $date.ToString('yyyy-MM-dd')
        [void]$litDates.Add($key)
        $plan.Add([pscustomobject]@{ Date = $key; Commits = $CommitsPerPixel })
    }
}
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
[void][System.IO.Directory]::CreateDirectory($output)
$planPath = Join-Path $output 'commit-plan-2025.csv'
$plan | Export-Csv -LiteralPath $planPath -NoTypeInformation -Encoding utf8
# Boundary weeks belong in the preview, but dates outside 2025 stay hidden.
$gridStart = $start.AddDays(-[int]$start.DayOfWeek)
$gridWeeks = [int][math]::Ceiling(($end.AddDays(1) - $gridStart).TotalDays / 7)
$cells = [System.Text.StringBuilder]::new()
for ($week = 0; $week -lt $gridWeeks; $week++) {
    for ($day = 0; $day -lt 7; $day++) {
        $date = $gridStart.AddDays($week * 7 + $day)
        $key = $date.ToString('yyyy-MM-dd')
        $class = if ($date -lt $start -or $date -gt $end) { 'outside' }
            elseif ($litDates.Contains($key)) { 'lit' } else { 'blank' }
        $count = if ($class -eq 'lit') { $CommitsPerPixel } else { 0 }
        [void]$cells.AppendLine(
            "<div class='cell $class' title='$key : $count generated commits'></div>"
        )
    }
}
$total = $plan.Count * $CommitsPerPixel
$html = @"
<!doctype html>
<html lang="en"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Ketaki - MY NINJA WAY calendar art / 2025</title>
<style>
body{background:#0d1117;color:#e6edf3;font:16px system-ui,sans-serif;margin:0;padding:20px}
main{max-width:1000px;margin:auto}h1{font-size:28px}
.muted{color:#9198a1;line-height:1.6}.scroll{overflow-x:auto;padding:22px 0}
.calendar{display:grid;grid-template-rows:repeat(7,9px);grid-auto-flow:column;grid-auto-columns:9px;gap:2px;width:max-content}
.cell{border-radius:2px;border:1px solid #ffffff0d}
.blank{background:#161b22}.lit{background:#39d353}.outside{visibility:hidden}
.note{border:1px solid #30363d;border-radius:8px;padding:18px;margin-top:20px}
</style></head><body><main>
<h1>MY NINJA WAY / 2025</h1>
<p class="muted">Original pixel lettering for <strong>ketakisbarde</strong>,
centered on the 2025 calendar. Sunday is the top row; weeks run left to right.</p>
<div class="scroll"><div class="calendar">$($cells.ToString())</div></div>
<p>$($plan.Count) lit dates &middot; $total planned art commits
&middot; $CommitsPerPixel commits per lit date</p>
<div class="note"><strong>Artwork-only preview.</strong>
<p class="muted">Existing contributions are not shown and may obscure the lettering.
GitHub determines the actual green shades. These are generated, intentionally
backdated art commits, not development work performed in 2025.</p>
<p class="muted">The 2026 robot + AI artwork remains unchanged.</p></div>
</main></body></html>
"@
$previewPath = Join-Path $output 'preview-2025.html'
[System.IO.File]::WriteAllText($previewPath, $html)
Write-Output "Preview: $previewPath"
Write-Output "Plan: $planPath"
Write-Output "Word: $word; width: $width weeks; lit dates: $($plan.Count); commits: $total"
# Preview can be repeated safely; creating the artwork is a guarded, one-time operation.
if (-not $CreateCommits) { return }

$repo = [System.IO.Path]::GetFullPath($Repository)
function Invoke-ArtGit {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)
    $result = & git --no-pager -C $repo @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Git failed during: $($Arguments[0])" }
    $result
}
if (-not (Test-Path -LiteralPath (Join-Path $repo '.git') -PathType Container)) {
    throw 'The existing personal artwork repository is required.'
}
$root = Invoke-ArtGit -Arguments @('rev-parse', '--show-toplevel')
if ([System.IO.Path]::GetFullPath($root) -ne $repo) { throw 'Unexpected repo root.' }
$remote = Invoke-ArtGit -Arguments @('remote', 'get-url', 'origin')
if ($remote -ne 'https://github.com/ketakisbarde/gitfiti-art.git') {
    throw 'Refusing to modify a different repository.'
}
$branch = Invoke-ArtGit -Arguments @('branch', '--show-current')
if ($branch -ne 'main') { throw 'The art repository must be on main.' }
if (@(Invoke-ArtGit -Arguments @('status', '--porcelain')).Count -gt 0) {
    throw 'The art repository has uncommitted changes; stopped without editing it.'
}
if (Test-Path -LiteralPath (Join-Path $repo 'New-NinjaArt.ps1')) {
    throw '2025 artwork generator already exists; refusing duplicate generation.'
}
$email = Invoke-ArtGit -Arguments @('config', '--local', '--get', 'user.email')
if ($email -ne 'ketakibarde97@gmail.com') { throw 'Unexpected personal commit email.' }
$before = [int](Invoke-ArtGit -Arguments @('rev-list', '--count', 'HEAD'))
# Keep the old tip so the final ancestry check can prove no existing history was rewritten.
$originalHead = Invoke-ArtGit -Arguments @('rev-parse', 'HEAD')
$readmePath = Join-Path $repo 'README.md'
$readme = [System.IO.File]::ReadAllText($readmePath)
$oldTitle = '# Robot + AI contribution-calendar art'
$oldSummary = 'Original pixel art with three robot + AI motifs across January-October 2026.'
if (-not $readme.Contains($oldTitle) -or -not $readme.Contains($oldSummary)) {
    throw 'README has changed unexpectedly; stopped before modifying repository files.'
}
$readme = $readme.Replace($oldTitle, '# Contribution-calendar pixel art').Replace(
    $oldSummary,
    "Original generated pixel art:`n`n" +
    '- **2025:** MY NINJA WAY lettering centered on the calendar. ' +
    "[Generator](./New-NinjaArt.ps1) / [date-count plan](./commit-plan-2025.csv).`n" +
    '- **2026:** Three robot + AI motifs across January-October. ' +
    '[Generator](./New-RobotAiArt.ps1) / [date-count plan](./commit-plan.csv).'
)
[System.IO.File]::WriteAllText($readmePath, $readme)
Copy-Item -LiteralPath $PSCommandPath -Destination (Join-Path $repo 'New-NinjaArt.ps1')
Copy-Item -LiteralPath $planPath -Destination (Join-Path $repo 'commit-plan-2025.csv')
Invoke-ArtGit -Arguments @('add', 'README.md', 'New-NinjaArt.ps1', 'commit-plan-2025.csv')

# Files enter the first pixel commit. All remaining commits may be empty.
# These historical timestamps affect calendar dates, not the parent order of Git history.
$oldAuthorDate = $env:GIT_AUTHOR_DATE
$oldCommitterDate = $env:GIT_COMMITTER_DATE
try {
    foreach ($pixel in $plan) {
        for ($index = 1; $index -le $pixel.Commits; $index++) {
            $stamp = "$($pixel.Date)T12:00:00+00:00"
            $env:GIT_AUTHOR_DATE = $stamp
            $env:GIT_COMMITTER_DATE = $stamp
            Invoke-ArtGit -Arguments @(
                '-c', 'commit.gpgsign=false', 'commit', '--allow-empty', '--quiet',
                '-m', "Generated MY NINJA WAY art: $($pixel.Date) pixel $index",
                '-m', 'Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>'
            )
        }
    }
} finally {
    $env:GIT_AUTHOR_DATE = $oldAuthorDate
    $env:GIT_COMMITTER_DATE = $oldCommitterDate
}
$after = [int](Invoke-ArtGit -Arguments @('rev-list', '--count', 'HEAD'))
if ($after -ne $before + $total) { throw 'Commit count verification failed.' }
Invoke-ArtGit -Arguments @('merge-base', '--is-ancestor', $originalHead, 'HEAD')
Write-Output "Verified $total new LOCAL commits; all original history preserved."
Write-Output 'Nothing pushed. Review before publishing to GitHub.'
