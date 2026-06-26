$text = Get-Content .\tmp_folgen.html -Raw
$regex = [regex] '<img[^>]+src="/folgen_images/nummern/([0-9]{3})\.gif"[^>]*>.*?</a>\s*</td>\s*<td[^>]*>\s*<a[^>]*class="folgenlink"[^>]*>(.*?)</a>'
$matches = $regex.Matches($text)
$episodes = @{}
foreach ($match in $matches) {
    $nr = [int]$match.Groups[1].Value
    $titleHtml = $match.Groups[2].Value
    $titleHtml = $titleHtml -replace '(?i)<br[^>]*>', ' '
    $title = $titleHtml -replace '<[^>]+>', ''
    $title = $title -replace '[\r\n]+', ' '
    $title = $title -replace '\s+', ' '
    $title = $title.Trim()
    if ($nr -le 245 -and $title.Length -gt 0) {
        $episodes[$nr] = $title
    }
}
$episodes.GetEnumerator() | Sort-Object Name | ForEach-Object { Write-Output ("{0}: {1}" -f $_.Name, $_.Value) }
