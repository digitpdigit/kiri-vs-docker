#!/usr/bin/env pwsh
# Test 02: data survives engine service restart (and upgrade if Kiri).
# Restart the Windows service while writeloop runs. STOP severity.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '02' 'data survives engine restart' 'ACKED_BUT_MISSING = 0 after engine service restart'

Kvd-DownV
Kvd-Up

# Determine Windows service name
$svcName = switch ($env:KVD_RUNTIME) {
    'docker' { 'com.docker.service' }
    'kiri'   { 'kiri' }
    default  { throw "Unknown runtime $env:KVD_RUNTIME; set KVD_RUNTIME_SERVICE_NAME" }
}
if ($env:KVD_RUNTIME_SERVICE_NAME) { $svcName = $env:KVD_RUNTIME_SERVICE_NAME }

$ack = "$script:KVD_RESULT_DIR\raw\ack.log"
$wlJob = Start-Job -ScriptBlock {
    param($root, $url, $ack)
    Push-Location "$root\tests\tools\writeloop"
    go run . -url $url -n 300 -rate 5 -ack $ack
    Pop-Location
} -ArgumentList $env:KVD_ROOT, $env:KVD_APP_URL, $ack

Kvd-Sleep 8

Write-Host "[kvd] restarting Windows service: $svcName"
"$ Restart-Service $svcName" | Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
try {
    Restart-Service -Name $svcName -Force -ErrorAction Stop
} catch {
    Kvd-Partial "cannot restart ${svcName}: $($_.Exception.Message). Need elevated PowerShell."
    Kvd-Note 'Re-run 02 from an Administrator terminal.'
    Kvd-End
    return
}

Write-Host "[kvd] waiting for engine + stack to recover..."
# Wait for docker to respond again
$ok = $false
for ($i = 1; $i -le 60; $i++) {
    $v = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -eq 0 -and $v) { $ok = $true; break }
    Start-Sleep 2
}
if (-not $ok) { Kvd-Fail 'engine did not respond after restart' }
else { Kvd-WaitHealthy }

Receive-Job $wlJob -Wait -AutoRemoveJob | Out-Null

$seqFile = "$script:KVD_RESULT_DIR\raw\seqs.txt"
Kvd-SeqDump $seqFile

$out = Kvd-Verify -AckLog $ack -SeqFile $seqFile
$missing = ($out | Select-String 'ACKED_BUT_MISSING:\s*(\d+)').Matches[0].Groups[1].Value
Kvd-Metric 'acked_but_missing' ([int]$missing)
Kvd-Observe "ACKED_BUT_MISSING=$missing service=$svcName"

if ([int]$missing -gt 0) { Kvd-Fail "data loss: ACKED_BUT_MISSING=$missing" }

Kvd-Note "Upgrade test: after this passes, upgrade $env:KVD_RUNTIME to the next version, restart the stack, re-run verify manually."

Kvd-End
