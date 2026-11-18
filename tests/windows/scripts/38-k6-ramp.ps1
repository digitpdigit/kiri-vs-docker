#!/usr/bin/env pwsh
# Test 38: raise k6 VUs on GET /health until p95 or errors climb.
# FINDING. Ramps virtual users to find the max load.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '38' 'k6 ramp max load' 'highest VUs with p95 under 100ms and fail rate under 1 percent'

Kvd-DownV
$loadCompose = Join-Path $env:KVD_ROOT 'compose\compose.load.yml'
Kvd-ComposeFiles -ExtraFiles @($loadCompose) -DockerArgs @('up', '-d', '--no-build')
Kvd-WaitHealthy

if (-not (Get-Command k6 -ErrorAction SilentlyContinue)) {
    Kvd-Fail 'k6 not installed'
    Kvd-End
    return
}

$js = Join-Path $script:KVD_RESULT_DIR 'raw\health.js'
@'
import http from 'k6/http';
import { check } from 'k6';
export default function () {
  const r = http.get(__ENV.BASE + '/health', { timeout: '5s' });
  check(r, { '200': (res) => res.status === 200 });
}
'@ | Set-Content $js -Encoding ASCII

$levels = @(10, 25, 50, 100, 200, 400)
if ($env:KVD_QUICK -eq '1') { $levels = @(10, 25, 50) }
$dur = if ($env:KVD_QUICK -eq '1') { '10s' } else { '15s' }

$maxVus = 0
$maxRps = 0
$lastP95 = 0
$broke = ''
$rows = @()

foreach ($vus in $levels) {
    Write-Host ("[kvd] ramp VUs={0} duration={1}" -f $vus, $dur)
    $sum = Join-Path $script:KVD_RESULT_DIR ("raw\k6-vus{0}.json" -f $vus)
    $env:BASE = $env:KVD_APP_URL
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    k6 run --vus $vus --duration $dur --env ("BASE=" + $env:KVD_APP_URL) --summary-export $sum --quiet $js |
        Out-File (Join-Path $script:KVD_RESULT_DIR ("raw\k6-vus{0}.txt" -f $vus)) -Encoding UTF8
    $ErrorActionPreference = $prev
    if (-not (Test-Path $sum)) {
        $broke = "no summary at vus=$vus"
        break
    }
    $s = Get-Content $sum -Raw | ConvertFrom-Json
    $d = $s.metrics.http_req_duration
    if ($d.values) { $d = $d.values }
    $req = $s.metrics.http_reqs
    $rps = if ($req.values) { $req.values.rate } else { $req.rate }
    $p95 = $d.'p(95)'
    $fail = 0
    $chk = $s.root_group.checks.'200'
    if ($chk) {
        $tot = $chk.passes + $chk.fails
        if ($tot -gt 0) { $fail = $chk.fails / $tot }
    }
    $line = ('vus={0} rps={1} p95_ms={2} fail={3}' -f $vus, [math]::Round($rps,0), [math]::Round($p95,1), [math]::Round($fail,4))
    Write-Host $line
    $rows += $line
    if ($fail -gt 0.01 -or $p95 -gt 100) {
        $broke = $line
        break
    }
    $maxVus = $vus
    $maxRps = [math]::Round($rps, 0)
    $lastP95 = [math]::Round($p95, 1)
}

$rows | Set-Content (Join-Path $script:KVD_RESULT_DIR 'raw\ramp.txt') -Encoding UTF8
Kvd-Metric 'max_stable_vus' $maxVus
Kvd-Metric 'max_stable_rps' $maxRps
Kvd-Metric 'p95_at_max_ms'  $lastP95
Kvd-Observe ("max_stable_vus={0} rps={1} p95_ms={2} stop={3}" -f $maxVus, $maxRps, $lastP95, $broke)
if ($maxVus -eq 0) { Kvd-Fail 'no stable VU level' }
Kvd-Note 'GET /health only. Stop when p95 > 100ms or check fail rate > 1%.'
Kvd-End
