#!/usr/bin/env pwsh
# Test 13: restart policies — crash each service, verify it recovers. BLOCKER.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '13' 'restart policy' 'Each service returns after crash per unless-stopped'

Kvd-DownV

# Need debug endpoints for /debug/panic
$debugCompose = "$env:KVD_ROOT\compose\compose.debug.yml"
"$ docker compose -f compose.yml -f compose.debug.yml up -d --no-build" |
    Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
Kvd-ComposeFiles -ExtraFiles @($debugCompose) -DockerArgs @('up', '-d', '--no-build')

Kvd-WaitHealthy

# Crash app via /debug/panic
Write-Host "[kvd] crashing app via /debug/panic..."
try { Invoke-WebRequest -Uri "$env:KVD_APP_URL/debug/panic" -UseBasicParsing -TimeoutSec 3 } catch {}

# Wait for app to restart
$recovered = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep 2
    try {
        $r = Invoke-WebRequest -Uri "$env:KVD_APP_URL/health" -UseBasicParsing -TimeoutSec 3
        if ($r.StatusCode -eq 200) { $recovered = $true; break }
    } catch {}
}
if ($recovered) { Kvd-Observe "app recovered after panic in ~$([int]($i*2))s" }
else            { Kvd-Fail 'app did not recover after panic' }

# Kill postgres container
Write-Host "[kvd] crashing postgres (pg_ctl stop -m immediate)..."
Kvd-CrashPostgres | Add-Content "$script:KVD_RESULT_DIR\raw\kill-postgres.txt" -Encoding UTF8

$pgRecovered = $false
for ($i = 1; $i -le 30; $i++) {
    Start-Sleep 2
    $st = docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE `
          ps --format '{{.Service}} {{.Health}}' 2>$null | Out-String
    if ($st -match 'postgres healthy') { $pgRecovered = $true; break }
}
if ($pgRecovered) { Kvd-Observe "postgres recovered in ~$([int]($i*2))s" }
else              { Kvd-Fail 'postgres did not recover after kill' }

$stackOk = Kvd-WaitHealthy -AllowFail
if ($stackOk -ne $true) { Kvd-Fail 'stack not fully healthy after restart-policy probes' }

Kvd-Metric 'app_recovered' ([int]$recovered)
Kvd-Metric 'postgres_recovered' ([int]$pgRecovered)

Kvd-End
