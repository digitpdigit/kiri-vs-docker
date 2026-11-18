#!/usr/bin/env pwsh
# Test 29: secrets in logs and crash reports. BLOCKER.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '29' 'secrets in logs and reports' 'CANARY_SECRET does not appear in docker logs or Windows Event Log'

Kvd-DownV
$debugCompose = "$env:KVD_ROOT\compose\compose.debug.yml"
Kvd-ComposeFiles -ExtraFiles @($debugCompose) -DockerArgs @('up', '-d', '--no-build')
Kvd-WaitHealthy

# Fake secret from compose.debug.yml (never a real credential)
$canary = 'CANARY-FAKE-SECRET-DO-NOT-USE'

# Trigger canary logging
Write-Host "[kvd] triggering /debug/canary..."
try { Invoke-WebRequest -Uri "$env:KVD_APP_URL/debug/canary" -UseBasicParsing -TimeoutSec 5 } catch {}

# Trigger crash report (Kiri may capture this for telemetry)
Write-Host "[kvd] triggering /debug/panic..."
try { Invoke-WebRequest -Uri "$env:KVD_APP_URL/debug/panic" -UseBasicParsing -TimeoutSec 3 } catch {}
Start-Sleep 5

# Collect docker logs
$dockerLogs = Kvd-Compose @('logs', '--no-color', 'app') 2>&1
$dockerLogs | Set-Content "$script:KVD_RESULT_DIR\raw\docker-logs.txt" -Encoding UTF8

# App stdout is supposed to contain the canary (that is the probe).
# Fail only if the *engine* copies it into Windows Event Log / crash reports.
if ($dockerLogs -match [regex]::Escape($canary)) {
    Kvd-Observe 'CANARY_SECRET present in container logs (expected; /debug/canary writes it)'
} else {
    Kvd-Partial 'CANARY_SECRET missing from container logs; probe may not have fired'
}
if ($dockerLogs -match 'CANARY-PASSWORD-123') {
    Kvd-Observe 'fake DSN password present in container logs (expected)'
}

# Check Windows Application Event Log for engine entries
$evtLogs = Get-WinEvent -LogName Application -MaxEvents 500 -ErrorAction SilentlyContinue |
           Where-Object { $_.Message -match 'docker|kiri' -or $_.ProviderName -match 'docker|kiri' }
$evtLogs | Select-Object TimeCreated, ProviderName, Message |
    Format-List | Out-String |
    Set-Content "$script:KVD_RESULT_DIR\raw\event-log.txt" -Encoding UTF8

$evtText = $evtLogs | Select-Object -ExpandProperty Message -ErrorAction SilentlyContinue
if ($evtText -match [regex]::Escape($canary)) {
    Kvd-Fail 'CANARY_SECRET found in Windows Event Log'
} else {
    Kvd-Observe 'CANARY_SECRET not in Windows Event Log'
}

Kvd-Note 'Also check any Kiri crash-report or telemetry files manually: check KVD_RESULT_DIR/raw/event-log.txt'
Kvd-End
