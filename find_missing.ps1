$lines = Get-Content .\episodes_1_245_utf8.txt | Where-Object { $_ -notmatch '^COUNT' }
$nums = $lines | ForEach-Object { [int]($_ -split ':')[0] }
1..245 | Where-Object { $nums -notcontains $_ } | ForEach-Object { Write-Host $_ }
