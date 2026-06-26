$lines = Get-Content .\tmp_folgen.html
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match 'nr=29') {
        $start = [Math]::Max(0, $i - 5)
        $end = [Math]::Min($lines.Count - 1, $i + 5)
        for ($j = $start; $j -le $end; $j++) {
            Write-Host ('{0}: {1}' -f ($j + 1), $lines[$j])
        }
    }
}
