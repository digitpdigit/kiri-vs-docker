#!/usr/bin/env pwsh
# Test 21: app latency and throughput via k6. FINDING.
# k6 replaces wrk here — available on Windows natively (winget install k6).
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '21' 'app latency k6' 'p50/p95/p99 latency and req/s for /health, /db, /cache'

Kvd-DownV

# Use load compose override to suppress per-request logs
$loadCompose = "$env:KVD_ROOT\compose\compose.load.yml"
Kvd-ComposeFiles -ExtraFiles @($loadCompose) -DockerArgs @('up', '-d', '--no-build')
Kvd-WaitHealthy

if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
    Kvd-Fail 'k6 not installed. Install: winget install k6'
    Kvd-End
    return
}

$duration = if ($env:KVD_QUICK -eq '1') { '15s' } else { '30s' }
$vus      = 10

# Write a minimal k6 script covering all three endpoints
$k6Script = "$script:KVD_RESULT_DIR\raw\load.js"
@"
import http from 'k6/http';
import { check } from 'k6';

export let options = {
  vus: $vus,
  duration: '$duration',
};

const BASE = '$env:KVD_APP_URL';

export default function () {
  let endpoints = ['/health', '/db', '/cache'];
  let url = BASE + endpoints[Math.floor(Math.random() * endpoints.length)];
  let r = http.get(url, { timeout: '5s' });
  check(r, { 'status < 503': (res) => res.status < 503 });
}
"@ | Set-Content $k6Script -Encoding UTF8

# Warmup: 60s run, results discarded
Write-Host "[kvd] warmup 60s..."
if ($env:KVD_QUICK -ne '1') {
    k6 run --vus $vus --duration '60s' --no-summary $k6Script 2>&1 | Out-Null
}

# Measured run: export summary JSON
$summaryJson = "$script:KVD_RESULT_DIR\raw\k6-summary.json"
Write-Host "[kvd] measured run ${duration}..."
"$ k6 run --vus $vus --duration $duration $k6Script" |
    Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8

k6 run --vus $vus --duration $duration --summary-export $summaryJson $k6Script |
    Tee-Object -FilePath "$script:KVD_RESULT_DIR\raw\k6-output.txt"

if ($LASTEXITCODE -ne 0) { Kvd-Fail "k6 exited $LASTEXITCODE" }

# Parse summary JSON
if (Test-Path $summaryJson) {
    $s = Get-Content $summaryJson -Raw | ConvertFrom-Json
    $d = $s.metrics.http_req_duration
    if ($d.values) { $d = $d.values }
    $req = $s.metrics.http_reqs
    $rpsRaw = if ($req.values) { $req.values.rate } else { $req.rate }
    $p50 = [math]::Round($d.med, 1)
    $p95 = [math]::Round($d.'p(95)', 1)
    $p99 = if ($d.'p(99)') { [math]::Round($d.'p(99)', 1) } else { [math]::Round($d.max, 1) }
    $rps = [math]::Round($rpsRaw, 1)

    Kvd-Metric 'p50_ms'  $p50
    Kvd-Metric 'p95_ms'  $p95
    Kvd-Metric 'p99_ms'  $p99
    Kvd-Metric 'rps'     $rps
    Kvd-Observe "p50=${p50}ms p95=${p95}ms p99=${p99}ms rps=${rps} vus=$vus duration=$duration"
} else {
    Kvd-Partial 'k6 summary JSON not written — parse output manually'
}

Kvd-Note 'Load ran on the same host as the engine (see load_on_host). Numbers are relative, not absolute.'
Kvd-End
