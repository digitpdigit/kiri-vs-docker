#!/usr/bin/env pwsh
# Test 22: Postgres throughput via pgbench. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '22' 'pgbench' 'tps read-heavy and write-heavy via pgbench inside container'

Kvd-DownV
Kvd-Up

$scale   = 10
$clients = 5
$threads = 2
$seconds = if ($env:KVD_QUICK -eq '1') { 15 } else { 30 }

# Init pgbench schema inside postgres container
Write-Host "[kvd] pgbench init..."
Kvd-Compose @('exec', '-T', 'postgres', 'pgbench', '-U', 'app', '-i', "-s$scale", 'appdb') 2>&1 |
    Set-Content "$script:KVD_RESULT_DIR\raw\pgbench-init.txt" -Encoding UTF8

# Read-heavy (select-only)
Write-Host "[kvd] pgbench read-heavy..."
$readOut = Kvd-Compose @('exec', '-T', 'postgres', 'pgbench', '-U', 'app', '-c', "$clients", '-j', "$threads", '-T', "$seconds", '-S', 'appdb') 2>&1
$readOut | Set-Content "$script:KVD_RESULT_DIR\raw\pgbench-read.txt" -Encoding UTF8
$readTps = ($readOut | Select-String 'tps\s*=\s*([\d.]+)').Matches |
           ForEach-Object { [double]$_.Groups[1].Value } | Select-Object -Last 1

# Write-heavy (default tpcb-like)
Write-Host "[kvd] pgbench write-heavy..."
$writeOut = Kvd-Compose @('exec', '-T', 'postgres', 'pgbench', '-U', 'app', '-c', "$clients", '-j', "$threads", '-T', "$seconds", 'appdb') 2>&1
$writeOut | Set-Content "$script:KVD_RESULT_DIR\raw\pgbench-write.txt" -Encoding UTF8
$writeTps = ($writeOut | Select-String 'tps\s*=\s*([\d.]+)').Matches |
            ForEach-Object { [double]$_.Groups[1].Value } | Select-Object -Last 1

Kvd-Metric 'read_tps'  ([math]::Round($readTps,  1))
Kvd-Metric 'write_tps' ([math]::Round($writeTps, 1))
Kvd-Observe "read_tps=$readTps write_tps=$writeTps scale=$scale clients=$clients"

if (-not $readTps -or -not $writeTps) { Kvd-Fail 'could not parse tps from pgbench output' }

Kvd-End
