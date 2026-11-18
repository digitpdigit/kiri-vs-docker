#!/usr/bin/env pwsh
# Test 09: service-name DNS resolves inside containers. BLOCKER.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '09' 'service-name DNS' 'postgres and redis resolve by name inside the app container'

Kvd-DownV
Kvd-Up

$raw = "$script:KVD_RESULT_DIR\raw\dns.txt"
# App image is distroless (no shell). Resolve from postgres, which has getent.
'--- getent from postgres ---' | Set-Content $raw -Encoding UTF8

foreach ($svc in 'postgres', 'redis') {
    $out = docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE `
           exec -T postgres getent hosts $svc 2>&1
    $out | Add-Content $raw -Encoding UTF8
    if ($LASTEXITCODE -ne 0 -or $out -match 'NXDOMAIN|not found|failed') {
        Kvd-Fail "$svc does not resolve"
    } else {
        Kvd-Observe "$svc resolves: $out"
    }
}

# /ready proves the app can actually connect using those names
$r = Kvd-Curl "$env:KVD_APP_URL/ready"
if ($r.StatusCode -ne 200) { Kvd-Fail "/ready $($r.StatusCode); DNS may work but connections fail" }
Kvd-Observe "/ready 200"

Kvd-Note 'Also verify DNS survives container restart: restart postgres, re-check /ready.'
$restart = Kvd-Compose @('restart', 'postgres')
Kvd-WaitHealthy
$r2 = Kvd-Curl "$env:KVD_APP_URL/ready"
if ($r2.StatusCode -ne 200) { Kvd-Fail "/ready $($r2.StatusCode) after postgres restart" }
Kvd-Observe "/ready 200 after postgres restart"

Kvd-End
