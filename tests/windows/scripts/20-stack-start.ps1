#!/usr/bin/env pwsh
# Test 20: stack start time (warm images). FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '20' 'stack start time warm images' 'time docker compose up -d until all services healthy'

$n = if ($env:KVD_QUICK -eq '1') { 2 } else { 3 }

$times = @()
for ($i = 1; $i -le ($n + 1); $i++) {
    Kvd-DownV
    Start-Sleep 3
    $ms = (Measure-Command {
        Kvd-Compose @('up', '-d', '--no-build') | Out-Null
        Kvd-WaitHealthy
    }).TotalMilliseconds
    if ($i -eq 1) {
        Write-Host '[kvd] run 1 is warmup; discarded'
        continue
    }
    $rounded = [math]::Round($ms, 0)
    $times += $rounded
    Write-Host ('[kvd] run {0} = {1}ms' -f $i, $rounded)
}

$sorted = $times | Sort-Object
$med = if ($sorted.Count % 2) {
    $sorted[[int]($sorted.Count / 2)]
} else {
    ($sorted[$sorted.Count/2 - 1] + $sorted[$sorted.Count/2]) / 2
}

Kvd-Metric 'median_ms' ([math]::Round($med, 0))
Kvd-Metric 'min_ms'    ($sorted | Measure-Object -Minimum).Minimum
Kvd-Metric 'max_ms'    ($sorted | Measure-Object -Maximum).Maximum
Kvd-Observe ('median={0}ms over {1} measured runs, warmup discarded' -f $med, $n)

$times | Set-Content (Join-Path $script:KVD_RESULT_DIR 'raw\times.txt') -Encoding UTF8

Kvd-Note 'Time includes WaitHealthy polling. Same measurement on both runtimes.'
Kvd-End
