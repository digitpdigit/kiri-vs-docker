#!/usr/bin/env pwsh
# Test 00: happy-path writeloop. Proves writeloop+verify work before durability tests.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '00' 'happy writeloop' 'ACKED_BUT_MISSING = 0'

Kvd-DownV
Kvd-Up

$ack = Kvd-Writeloop -N 50
Kvd-Sleep 2

$seqFile = "$script:KVD_RESULT_DIR\raw\seqs.txt"
Kvd-SeqDump $seqFile

$out = Kvd-Verify -AckLog $ack -SeqFile $seqFile
$missing = ($out | Select-String 'ACKED_BUT_MISSING:\s*(\d+)').Matches[0].Groups[1].Value
Kvd-Metric 'acked_but_missing' ([int]$missing)
Kvd-Observe "ACKED_BUT_MISSING=$missing"

if ([int]$missing -gt 0) {
    Kvd-Fail "data loss: ACKED_BUT_MISSING=$missing"
} else {
    Kvd-Note 'writeloop and verify confirmed end-to-end durability path works'
}

Kvd-End
