#!/usr/bin/env pwsh
# Test 08: depends_on service_healthy ordering. BLOCKER.
# App must not start until postgres and redis are healthy.
# DB_CONNECT_RETRIES=0 means app exits if it races ahead — the runtime must hold it.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '08' 'startup ordering healthcheck depends_on' 'App starts only after both dependencies healthy'

Kvd-DownV

# Start without --wait so we can observe the ordering
"$ docker compose up -d --no-build" | Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
Kvd-Compose @('up', '-d', '--no-build')

# Poll for a minute; at no point should app be running while postgres/redis are still starting
$appStartedEarly = $false
$tries = 60
for ($i = 1; $i -le $tries; $i++) {
    $st = docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE `
          ps --format '{{.Service}} {{.Health}} {{.State}}' 2>$null | Out-String

    $appRunning  = $st -match 'app.*(running|healthy)'
    $pgHealthy   = $st -match 'postgres healthy'
    $redisHealhy = $st -match 'redis healthy'

    if ($appRunning -and (-not $pgHealthy -or -not $redisHealhy)) {
        $appStartedEarly = $true
        Kvd-Note "ORDERING VIOLATION at iteration ${i}: app running before deps healthy"
        $st | Set-Content "$script:KVD_RESULT_DIR\raw\ordering-violation.txt" -Encoding UTF8
    }

    if ($st -match 'app healthy' -and $pgHealthy -and $redisHealhy) {
        Kvd-Observe "all healthy at iteration $i (${i}x2s = ~$([int]($i*2))s)"
        break
    }

    if ($i -eq $tries) {
        Kvd-Fail "stack not healthy after $tries tries"
    }
    Start-Sleep 2
}

if ($appStartedEarly) { Kvd-Fail 'app started before dependencies were healthy' }

# Confirm /ready shows both deps OK
$r = Kvd-Curl "$env:KVD_APP_URL/ready"
$r.Content | Set-Content "$script:KVD_RESULT_DIR\raw\ready.json" -Encoding UTF8
if ($r.StatusCode -ne 200) { Kvd-Fail "/ready returned $($r.StatusCode)" }
Kvd-Observe "/ready 200: $($r.Content)"

Kvd-End
