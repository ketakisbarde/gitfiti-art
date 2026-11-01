<#
.SYNOPSIS
Previews full-height EAT YOUR VEGGIES on the 2023 or 2024 calendar.
.DESCRIPTION
Default operation writes only an HTML preview and date-count CSV.
-CreateCommits appends one year's explicitly backdated art to the existing
personal repository. It refuses duplicate plans and never pushes or rewrites
history. The same bitmap is used for both years.
.EXAMPLE
.\New-VeggieArt.ps1 -Year 2023
.EXAMPLE
.\New-VeggieArt.ps1 -Year 2024
#>
[CmdletBinding()]
param(
    [ValidateSet(2023, 2024)]
    [int]$Year = 2023,
    [string]$OutputDirectory = $PSScriptRoot,
    [string]$Repository = 'C:\temp\ketakisbarde-gitfiti-2026\gitfiti-art',
    [switch]$CreateCommits,
    [ValidateRange(1, 100)]
    [int]$CommitsPerPixel = 4
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$start = [datetime]::new($Year, 1, 1)
$end = [datetime]::new($Year, 12, 31)
if ($end -gt (Get-Date).Date) { throw 'Artwork dates must be in the past.' }
$firstSunday = $start.AddDays((7 - [int]$start.DayOfWeek) % 7)

# Seven-row glyphs use narrow E, I, and S letters so the complete phrase fits.
$letters = @{
    E = @('11', '10', '10', '11', '10', '10', '11')
    A = @('010', '101', '101', '111', '101', '101', '101')
    T = @('111', '010', '010', '010', '010', '010', '010')
    Y = @('101', '101', '101', '010', '010', '010', '010')
    O = @('010', '101', '101', '101', '101', '101', '010')
    U = @('101', '101', '101', '101', '101', '101', '111')
    R = @('110', '101', '101', '110', '101', '101', '101')
    V = @('101', '101', '101', '101', '101', '101', '010')
    G = @('011', '100', '100', '101', '101', '101', '011')
    I = @('1', '1', '1', '1', '1', '1', '1')
    S = @('11', '10', '10', '11', '01', '01', '11')
    ' ' = @('', '', '', '', '', '', '')
}
function Get-TextRows {
    param([Parameter(Mandatory = $true)][string]$Text)
    foreach ($character in $Text.ToCharArray()) {
        if (-not $letters.ContainsKey([string]$character)) {
            throw "Unsupported character: $character"
        }
    }
    for ($row = 0; $row -lt 7; $row++) {
        (@(foreach ($character in $Text.ToCharArray()) {
            $letters[[string]$character][$row]
        }) -join '0')
    }
}
# Empty space glyphs still get join separators on both sides: two blank word columns.
$rows = @(Get-TextRows -Text 'EAT YOUR VEGGIES')
$width = $rows[0].Length
$completeWeeks = [int][math]::Floor(($end.AddDays(1) - $firstSunday).TotalDays / 7)
if ($width -gt $completeWeeks) { throw 'Artwork does not fit the selected year.' }
$offset = [int][math]::Floor(($completeWeeks - $width) / 2)
$plan = [System.Collections.Generic.List[object]]::new()
$litDates = [System.Collections.Generic.HashSet[string]]::new()
for ($column = 0; $column -lt $width; $column++) {
    for ($row = 0; $row -lt 7; $row++) {
        if ($rows[$row][$column] -ne '1') { continue }
        # Column selects a week; row selects Sunday (0) through Saturday (6).
        $date = $firstSunday.AddDays(($offset + $column) * 7 + $row)
        if ($date -lt $start -or $date -gt $end) { throw 'Pixel outside selected year.' }
        $key = $date.ToString('yyyy-MM-dd')
        [void]$litDates.Add($key)
        $plan.Add([pscustomobject]@{ Date = $key; Commits = $CommitsPerPixel })
    }
}
$output = [System.IO.Path]::GetFullPath($OutputDirectory)
[void][System.IO.Directory]::CreateDirectory($output)
$planPath = Join-Path $output "commit-plan-$Year.csv"
$plan | Export-Csv -LiteralPath $planPath -NoTypeInformation -Encoding utf8
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
<title>Ketaki - EAT YOUR VEGGIES / $Year</title>
<style>
body{background:#0d1117;color:#e6edf3;font:16px system-ui,sans-serif;margin:0;padding:20px}
main{max-width:1000px;margin:auto}h1{font-size:26px}
.muted{color:#9198a1;line-height:1.6}.scroll{overflow-x:auto;padding:22px 0}
.calendar{display:grid;grid-template-rows:repeat(7,9px);grid-auto-flow:column;grid-auto-columns:9px;gap:2px;width:max-content}
.cell{border-radius:2px;border:1px solid #ffffff0d}
.blank{background:#161b22}.lit{background:#39d353}.outside{visibility:hidden}
.note{border:1px solid #30363d;border-radius:8px;padding:18px;margin-top:20px}
</style></head><body><main>
<h1>EAT YOUR VEGGIES / $Year</h1>
<p class="muted">Original full-height pixel lettering for <strong>ketakisbarde</strong>.
Read the phrase left to right. The smiley is omitted so the text fits clearly.</p>
<div class="scroll"><div class="calendar">$($cells.ToString())</div></div>
<p>$($plan.Count) lit dates &middot; $total planned art commits
&middot; $width-week-wide bitmap</p>
<div class="note"><strong>Artwork-only preview - no automatic push.</strong>
<p class="muted">The same bitmap is used for 2023 and 2024. These are deliberately
backdated art commits, not historical software development. Existing contributions
are not shown and may obscure the pattern. GitHub controls actual green shades.</p>
<p class="muted">The existing 2025 and 2026 artwork is preserved.</p></div>
</main></body></html>
"@
$previewPath = Join-Path $output "preview-$Year.html"
[System.IO.File]::WriteAllText($previewPath, $html)
Write-Output "Preview: $previewPath"
Write-Output "Year: $Year; width: $width weeks; lit dates: $($plan.Count); commits: $total"
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
if ([System.IO.Path]::GetFullPath($root) -ne $repo) { throw 'Unexpected repository root.' }
$remote = Invoke-ArtGit -Arguments @('remote', 'get-url', 'origin')
if ($remote -ne 'https://github.com/ketakisbarde/gitfiti-art.git') {
    throw 'Refusing to modify a different repository.'
}
if ((Invoke-ArtGit -Arguments @('branch', '--show-current')) -ne 'main') {
    throw 'The art repository must be on main.'
}
if (@(Invoke-ArtGit -Arguments @('status', '--porcelain')).Count -gt 0) {
    throw 'The art repository has uncommitted changes; stopped without editing it.'
}
$destinationPlan = Join-Path $repo "commit-plan-$Year.csv"
if (Test-Path -LiteralPath $destinationPlan) {
    throw "A $Year plan already exists; refusing duplicate artwork generation."
}
# Publish one year before generating another to avoid accumulating large pushes.
$localTip = Invoke-ArtGit -Arguments @('rev-parse', 'HEAD')
$published = @(Invoke-ArtGit -Arguments @('ls-remote', 'origin', 'refs/heads/main'))
if ($published.Count -ne 1 -or $published[0].Split("`t")[0] -ne $localTip) {
    throw 'Publish and verify the existing local history before adding another year.'
}
$email = Invoke-ArtGit -Arguments @('config', '--local', '--get', 'user.email')
if ($email -ne 'ketakibarde97@gmail.com') { throw 'Unexpected personal commit email.' }
$destinationScript = Join-Path $repo 'New-VeggieArt.ps1'
if (Test-Path -LiteralPath $destinationScript) {
    if ((Get-FileHash -LiteralPath $destinationScript).Hash -ne
        (Get-FileHash -LiteralPath $PSCommandPath).Hash) {
        throw 'The existing shared generator differs; stopped before overwriting it.'
    }
}
$before = [int](Invoke-ArtGit -Arguments @('rev-list', '--count', 'HEAD'))
$originalHead = Invoke-ArtGit -Arguments @('rev-parse', 'HEAD')
if (-not (Test-Path -LiteralPath $destinationScript)) {
    Copy-Item -LiteralPath $PSCommandPath -Destination $destinationScript
}
Copy-Item -LiteralPath $planPath -Destination $destinationPlan
# Files enter the first pixel commit; later commits can be empty.
Invoke-ArtGit -Arguments @('add', 'New-VeggieArt.ps1', "commit-plan-$Year.csv")
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
                '-m', "Generated EAT YOUR VEGGIES art: $($pixel.Date) pixel $index",
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
Write-Output "Verified $total new LOCAL commits for $Year; original history preserved."
Write-Output 'Nothing pushed. Review before publishing to GitHub.'
