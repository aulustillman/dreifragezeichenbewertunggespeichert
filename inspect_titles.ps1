$text = Get-Content .\tmp_folgen.html -Raw
$pattern = 'href="folgendb.php?nr='
$idx = 0
$seen = @{}
while (($idx = $text.IndexOf($pattern, $idx)) -ne -1) {
    $start = $idx + $pattern.Length
    $end = $text.IndexOf('"', $start)
    if ($end -lt 0) { break }
    $nr = $text.Substring($start, $end - $start).Split('&')[0]
    if ($nr -match '^[0-9]+$') { $seen[$nr] = $true }
    $idx = $end
}
$seen.Keys.Count | Write-Host
$seen.Keys | Sort-Object {[int]$_} | Select-Object -Last 10 | ForEach-Object { Write-Host $_ }
