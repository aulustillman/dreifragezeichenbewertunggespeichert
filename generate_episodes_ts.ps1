$lines = Get-Content .\episodes_1_245_utf8.txt
$out = @("export interface EpisodeInfo { id: number; title: string; }", "", "export const episodeList: EpisodeInfo[] = [")
foreach ($line in $lines) {
    if ($line -match '^(\d+):\s*(.*)$') {
        $id = $matches[1]
        $title = $matches[2] -replace "'", "\\'"
        $out += "  { id: $id, title: '$title' },"
    }
}
$out += ']'
$out += ''
Set-Content -Path .\src\episodes.ts -Value $out -Encoding UTF8
Write-Host "created src/episodes.ts with" $lines.Count "episodes"
