#!/usr/bin/env pwsh
# Test 19: single container start time. FINDING.
# Uses hyperfine (preferred) or Measure-Command fallback.
. "$PSScriptRoot\..\lib\common.ps1"

$img = 'alpine:latest'

Kvd-Begin '19' 'single container start time' "hyperfine 'docker run --rm $img true'"

docker pull $img 2>&1 | Out-Null

$n = if ($env:KVD_QUICK -eq '1') { 3 } else { 6 }

if (Get-Command hyperfine -ErrorAction SilentlyContinue) {
    $hfJson = "$script:KVD_RESULT_DIR\raw\hyperfine.json"
    hyperfine --warmup 1 --runs $n --export-json $hfJson "docker run --rm $img true" |
        Tee-Object -FilePath "$script:KVD_RESULT_DIR\raw\hyperfine.txt"

    $hf  = Get-Content $hfJson -Raw | ConvertFrom-Json
    $r0  = $hf.results[0]
    if ($r0.summary -and $r0.summary.time_wall_clock) {
        $tw  = $r0.summary.time_wall_clock
        $med = [math]::Round($tw.median * 1000, 1)
        $min = [math]::Round($tw.min    * 1000, 1)
        $max = [math]::Round($tw.max    * 1000, 1)
    } else {
        $med = [math]::Round($r0.median * 1000, 1)
        $min = [math]::Round($r0.min    * 1000, 1)
        $max = [math]::Round($r0.max    * 1000, 1)
    }

    Kvd-Metric 'median_ms' $med
    Kvd-Metric 'min_ms'    $min
    Kvd-Metric 'max_ms'    $max
    Kvd-Observe "hyperfine median=${med}ms min=${min}ms max=${max}ms runs=$n"
} else {
    # Fallback: Measure-Command loop
    Write-Warning 'hyperfine not found; using Measure-Command (less accurate than hyperfine)'
    $times = @()
    docker run --rm $img true | Out-Null   # warmup
    for ($i = 1; $i -le $n; $i++) {
        $ms = (Measure-Command { docker run --rm $img true }).TotalMilliseconds
        $times += $ms
    }
    $sorted = $times | Sort-Object
    $med = if ($sorted.Count % 2) {
        $sorted[[int]($sorted.Count / 2)]
    } else {
        ($sorted[$sorted.Count/2 - 1] + $sorted[$sorted.Count/2]) / 2
    }
    $med = [math]::Round($med, 1)

    Kvd-Metric 'median_ms' $med
    Kvd-Metric 'min_ms'    [math]::Round(($sorted | Measure-Object -Minimum).Minimum, 1)
    Kvd-Metric 'max_ms'    [math]::Round(($sorted | Measure-Object -Maximum).Maximum, 1)
    Kvd-Observe "Measure-Command median=${med}ms runs=$n"
    Kvd-Note 'Install hyperfine for more reliable timing: winget install sharkdp.hyperfine'
}

Kvd-End
