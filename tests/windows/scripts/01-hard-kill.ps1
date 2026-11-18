#!/usr/bin/env pwsh
# Test 01: Postgres hard-kill survival. STOP severity.
# On Windows: Stop-Process -Force on the container process rather than kill -9.
# No power-cycle available from PowerShell — that step is manual (see notes).
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '01' 'postgres hard-kill survival' 'ACKED_BUT_MISSING = 0 after Stop-Process on postgres container'

Kvd-DownV
Kvd-Up

# Start writeloop in background
$ack = "$script:KVD_RESULT_DIR\raw\ack.log"
$wlJob = Start-Job -ScriptBlock {
    param($root, $url, $ack)
    Push-Location "$root\tests\tools\writeloop"
    go run . -url $url -n 200 -rate 10 -ack $ack
    Pop-Location
} -ArgumentList $env:KVD_ROOT, $env:KVD_APP_URL, $ack

Kvd-Sleep 5

# Crash postgres without a daemon-level manual stop (docker kill would disable the restart policy).
Write-Host "[kvd] crashing postgres (pg_ctl stop -m immediate)"
Kvd-CrashPostgres | Tee-Object -FilePath "$script:KVD_RESULT_DIR\raw\kill.txt"

Kvd-Sleep 5

Write-Host "[kvd] waiting for postgres to recover..."
$ok = Kvd-WaitHealthy -AllowFail
if ($ok -ne $true) {
    Kvd-Fail 'postgres did not return after SIGKILL (restart policy)'
    Kvd-Metric 'acked_but_missing' -1
    Kvd-End
    return
}

# Wait for writeloop to finish
Receive-Job $wlJob -Wait -AutoRemoveJob | Out-Null

$seqFile = "$script:KVD_RESULT_DIR\raw\seqs.txt"
Kvd-SeqDump $seqFile

$out = Kvd-Verify -AckLog $ack -SeqFile $seqFile
$missing = ($out | Select-String 'ACKED_BUT_MISSING:\s*(\d+)').Matches[0].Groups[1].Value
Kvd-Metric 'acked_but_missing' ([int]$missing)
Kvd-Observe "ACKED_BUT_MISSING=$missing"

if ([int]$missing -gt 0) {
    Kvd-Fail "data loss after hard kill: ACKED_BUT_MISSING=$missing"
}

Kvd-Note 'Power-cycle step (kill -9 on host) is not automated on Windows. Run manually and record separately.'
Kvd-Note 'Crash made with pg_ctl stop -m immediate (no shutdown checkpoint). docker kill is a manual stop and skips the restart policy.'
Kvd-Note 'This exercises Postgres crash recovery on the engine volume, not a host power cut.'

Kvd-End
