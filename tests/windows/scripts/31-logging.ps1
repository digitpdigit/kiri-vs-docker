#!/usr/bin/env pwsh
# Test 31: log rotation. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '31' 'log rotation' 'json-file rotation honored; docker logs still works; disk bounded'

Kvd-DownV
$logCompose   = "$env:KVD_ROOT\compose\compose.logging.yml"
$debugCompose = "$env:KVD_ROOT\compose\compose.debug.yml"
Kvd-ComposeFiles -ExtraFiles @($logCompose, $debugCompose) -DockerArgs @('up', '-d', '--no-build')
Kvd-WaitHealthy

# Write lots of logs via /debug/log
$logUrl = "$env:KVD_APP_URL/debug/log?n=10000&size=200"
Write-Host "[kvd] writing 10000 log lines via /debug/log..."
"$ curl $logUrl" | Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
Invoke-WebRequest -Uri $logUrl -UseBasicParsing -TimeoutSec 30 | Out-Null

Start-Sleep 5

# Check docker logs still returns something (rotation must not break logs command)
$logs = Kvd-Compose @('logs', '--no-color', '--tail', '50', 'app') 2>&1
$logs | Set-Content "$script:KVD_RESULT_DIR\raw\logs-after.txt" -Encoding UTF8
if (-not $logs) {
    Kvd-Fail 'docker logs returned nothing after log rotation'
} else {
    Kvd-Observe 'docker logs still works after high log volume'
}

# Inspect the container for LogConfig
$inspect = docker inspect --format '{{json .HostConfig.LogConfig}}' `
           "$($env:KVD_PROJECT)-app-1" 2>&1
$inspect | Set-Content "$script:KVD_RESULT_DIR\raw\logconfig.txt" -Encoding UTF8
Kvd-Observe "LogConfig: $inspect"

$logCfg = $inspect | ConvertFrom-Json -ErrorAction SilentlyContinue
if ($logCfg -and $logCfg.Type -eq 'json-file') {
    Kvd-Observe 'json-file driver confirmed'
} else {
    Kvd-Note "Log driver is '$($logCfg.Type)'; may not be json-file. Check if runtime honors logging options."
}

# Check for max-size option
if ($logCfg -and $logCfg.Config.'max-size') {
    Kvd-Observe "max-size=$($logCfg.Config.'max-size') max-file=$($logCfg.Config.'max-file')"
} else {
    Kvd-Partial 'max-size not found in LogConfig; rotation options may not be honored'
}

Kvd-End
