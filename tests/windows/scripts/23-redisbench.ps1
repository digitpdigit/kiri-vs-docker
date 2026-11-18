#!/usr/bin/env pwsh
# Test 23: Redis throughput via redis-benchmark. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '23' 'redis-benchmark' 'ops/s for SET and GET via redis-benchmark inside container'

Kvd-DownV
Kvd-Up

$requests = if ($env:KVD_QUICK -eq '1') { 10000 } else { 50000 }
$clients  = 10

$out = Kvd-Compose @('exec', '-T', 'redis', 'redis-benchmark', '-c', "$clients", '-n', "$requests", '-t', 'set,get', '--csv') 2>&1
$out | Set-Content "$script:KVD_RESULT_DIR\raw\redis-bench.txt" -Encoding UTF8

# CSV format: "SET","12345.67"
$setOps = ($out | Where-Object { $_ -match '^"SET"' } |
           Select-String '"SET","([\d.]+)"').Matches[0].Groups[1].Value
$getOps = ($out | Where-Object { $_ -match '^"GET"' } |
           Select-String '"GET","([\d.]+)"').Matches[0].Groups[1].Value

Kvd-Metric 'set_ops_per_sec' ([math]::Round([double]$setOps, 0))
Kvd-Metric 'get_ops_per_sec' ([math]::Round([double]$getOps, 0))
Kvd-Observe "SET=${setOps} GET=${getOps} ops/s clients=$clients requests=$requests"

if (-not $setOps -or -not $getOps) { Kvd-Fail 'could not parse ops/s from redis-benchmark output' }

Kvd-End
