$text = Get-Content .\tmp_folgen.html -Raw
$results = @()
$idx = 0
$pattern = 'href="folgendb.php?nr='
while (($idx = $text.IndexOf($pattern, $idx)) -ne -1) {
    $start = $idx + $pattern.Length
    $end = $text.IndexOf('"', $start)
    if ($end -lt 0) { break }
    $nrText = $text.Substring($start, $end - $start).Split('&')[0]
    $nr = [int]$nrText
    $aStart = $text.IndexOf('>', $end) + 1
    $aEnd = $text.IndexOf('</a>', $aStart)
    if ($aEnd -lt 0) { break }
    $titleHtml = $text.Substring($aStart, $aEnd - $aStart)
    $title = $titleHtml -replace '<[^>]+>', ''
    $title = $title -replace '[\r\n]+', ' '
    $title = $title -replace '\s+', ' '
    $title = $title.Trim()
    if ($title -match 'Die drei|die drei') {
        $results += [PSCustomObject]@{Nr=$nr; Title=$title}
    }
    $idx = $aEnd + 4
}
$results | Sort-Object Nr | Select-Object -First 120 | ForEach-Object { Write-Host "$($_.Nr): $($_.Title)" }
Write-Host 'COUNT' $results.Count
