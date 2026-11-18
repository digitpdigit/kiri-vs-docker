#!/usr/bin/env pwsh
# Test 14: memory limits enforced. BLOCKER.
# Allocate over the app's 256 MB limit via /debug/alloc. Only the app container must die, not the host.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '14' 'memory limits' 'App OOM-killed; host and other containers survive'

Kvd-DownV
$debugCompose = "$env:KVD_ROOT\compose\compose.debug.yml"
Kvd-ComposeFiles -ExtraFiles @($debugCompose) -DockerArgs @('up', '-d', '--no-build')
Kvd-WaitHealthy

# Record stats before
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' 2>&1 |
    Set-Content "$script:KVD_RESULT_DIR\raw\stats-before.txt" -Encoding UTF8

# Allocate 1024 MB. mem_limit 256M with no memswap_limit allows 256M RAM + 256M swap = 512M total
# (docs.docker.com/engine/containers/resource_constraints/). 400 MB fits inside that, so it proves nothing.
Write-Host "[kvd] allocating 1024 MB via /debug/alloc..."
try {
    Invoke-WebRequest -Uri "$env:KVD_APP_URL/debug/alloc?mb=1024" -Method POST -UseBasicParsing -TimeoutSec 20
} catch {
    Kvd-Observe "alloc request threw (expected if container died): $_"
}

Start-Sleep 10

docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}' 2>&1 |
    Set-Content "$script:KVD_RESULT_DIR\raw\stats-after.txt" -Encoding UTF8

# App should have been OOM-killed; Postgres and Redis should still run
$st = docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE `
      ps --format '{{.Service}} {{.State}}' 2>$null | Out-String
$st | Set-Content "$script:KVD_RESULT_DIR\raw\ps-after.txt" -Encoding UTF8

$pgOk    = $st -match 'postgres.*running'
$redisOk = $st -match 'redis.*running'
# restart: unless-stopped brings the app back before this check, so read RestartCount, not State.
$appName = "$($env:KVD_PROJECT)-app-1"
$restarts = [int](docker inspect $appName --format '{{.RestartCount}}' 2>$null)
$exitCode = docker inspect $appName --format '{{.State.ExitCode}}' 2>$null
$appKilled = ($restarts -gt 0)
"restarts=$restarts last_exit=$exitCode" | Set-Content "$script:KVD_RESULT_DIR\raw\app-inspect.txt" -Encoding UTF8
Kvd-Metric 'app_restarts' $restarts

Kvd-Metric 'postgres_survived' ([int]$pgOk)
Kvd-Metric 'redis_survived'    ([int]$redisOk)
Kvd-Metric 'app_oom_killed'    ([int]$appKilled)
Kvd-Observe "app_killed=$appKilled pg_ok=$pgOk redis_ok=$redisOk"

if (-not $pgOk)    { Kvd-Fail 'postgres did not survive OOM event' }
if (-not $redisOk) { Kvd-Fail 'redis did not survive OOM event' }
if (-not $appKilled) {
    Kvd-Partial 'app was not killed; mem_limit may not be enforced (record as finding)'
    Kvd-Note 'If limit not enforced, check whether Docker Desktop / Kiri passes mem_limit to WSL2 cgroup.'
}

Kvd-End
