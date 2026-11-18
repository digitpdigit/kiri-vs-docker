#!/usr/bin/env pwsh
# Test 18: engine idle CPU. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '18' 'engine idle CPU' 'one-core percent of engine processes over a quiet sample'

Kvd-DownV
Start-Sleep 10

$sec = if ($env:KVD_QUICK -eq '1') { 20 } else { 180 }
Write-Host ("[kvd] sampling engine CPU for {0}s" -f $sec)
$pct = Kvd-EngineCpuSample -Seconds $sec

("cpu_one_core_pct=$pct sample_s=$sec match=$($env:KVD_ENGINE_PROCESS_MATCH)") |
    Set-Content (Join-Path $script:KVD_RESULT_DIR 'raw\cpu.txt') -Encoding UTF8

Kvd-EngineProcessList | Out-Null
Kvd-Metric 'cpu_one_core_pct' $pct
Kvd-Metric 'sample_s' $sec
Kvd-Observe ("engine CPU {0}% of one logical core over {1}s" -f $pct, $sec)
Kvd-Note '100 means one logical core busy for the whole sample. Host has many cores.'
Kvd-End
