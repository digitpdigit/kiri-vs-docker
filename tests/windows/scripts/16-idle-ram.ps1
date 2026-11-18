#!/usr/bin/env pwsh
# Test 16: engine idle RAM (no containers running). FINDING.
# Uses Windows WorkingSet64 via Get-Process — different from Linux /proc VmRSS
# but the most comparable measure on Windows.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '16' 'engine idle RAM' 'Record Working Set of engine processes with no containers'

# Bring stack fully down (no containers)
Kvd-DownV

# Give engine a moment to settle after containers stop
Start-Sleep 10

# Collect process list and sum WorkingSet
$procs = Kvd-EngineProcessList
$ramMB = Kvd-EngineRamMB

$ramMB | Set-Content "$script:KVD_RESULT_DIR\raw\idle_ram_mb.txt" -Encoding UTF8

$vmmem = Kvd-VmmemRamMB
$vhdx  = Kvd-VhdxMB
Kvd-Metric 'ram_mb'     $ramMB
Kvd-Metric 'vmmem_mb'   $vmmem
Kvd-Metric 'vhdx_mb'    $vhdx
Kvd-Observe ("WS={0} MB vmmem={1} MB vhdx={2} MB pattern={3}" -f $ramMB, $vmmem, $vhdx, $env:KVD_ENGINE_PROCESS_MATCH)

Kvd-Note "WorkingSet64 (Windows) includes shared pages. Not directly comparable to Linux VmRSS."
Kvd-Note "Human: confirm the process name pattern is fair: set KVD_ENGINE_PROCESS_MATCH if needed."
Kvd-Note "For Docker Desktop: pattern 'com.docker' or 'docker'. For Kiri: pattern 'kiri'."

Kvd-End
