#!/usr/bin/env pwsh
# Test 07: real Compose file runs unmodified. BLOCKER.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '07' 'compose up/down/logs/exec' 'up works, all services healthy, logs and exec work'

Kvd-DownV
Kvd-Up

# Check services are listed
$ps = Kvd-Compose @('ps', '--format', 'table {{.Service}}	{{.Status}}')
$psText = $ps | Out-String
$psText | Set-Content "$script:KVD_RESULT_DIR\raw\ps.txt" -Encoding UTF8

foreach ($svc in 'app', 'postgres', 'redis') {
    if ($psText -notmatch [regex]::Escape($svc)) { Kvd-Fail "service $svc missing from ps output" }
}

# logs — just check they're non-empty
$logs = Kvd-Compose @('logs', '--no-color', '--tail', '20', 'app')
$logs | Set-Content "$script:KVD_RESULT_DIR\raw\logs-app.txt" -Encoding UTF8
if (-not $logs) { Kvd-Fail 'docker compose logs app returned nothing' }

# exec
$execOut = Kvd-Compose @('exec', '-T', 'app', '/app', 'healthcheck') 2>&1
$execOut | Set-Content "$script:KVD_RESULT_DIR\raw\exec.txt" -Encoding UTF8
if ($LASTEXITCODE -ne 0) { Kvd-Fail "exec healthcheck exit $LASTEXITCODE" }

# /health endpoint
$r = Kvd-Curl "$env:KVD_APP_URL/health"
if ($r.StatusCode -ne 200) { Kvd-Fail "/health $($r.StatusCode)" }

Kvd-Observe "ps ok; logs ok; exec healthcheck ok; /health 200"
Kvd-End
