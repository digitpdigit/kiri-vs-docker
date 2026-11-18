#!/usr/bin/env pwsh
# Test 17: total host RAM increase when stack starts. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '17' 'stack RAM' 'Record host Working Set before and after compose up'

Kvd-DownV
Start-Sleep 10

# Baseline: engine running, no containers
$beforeMB = Kvd-EngineRamMB
$freeBeforeOut = (Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory)
$freeBeforeMB  = [math]::Round($freeBeforeOut.FreePhysicalMemory / 1KB, 1)

"before_ram_mb=$beforeMB free_mb=$freeBeforeMB" |
    Set-Content "$script:KVD_RESULT_DIR\raw\before.txt" -Encoding UTF8

Kvd-Up
Start-Sleep 10  # let stack settle

$afterMB = Kvd-EngineRamMB
$freeAfterOut = (Get-CimInstance Win32_OperatingSystem | Select-Object FreePhysicalMemory)
$freeAfterMB  = [math]::Round($freeAfterOut.FreePhysicalMemory / 1KB, 1)

"after_ram_mb=$afterMB free_mb=$freeAfterMB" |
    Set-Content "$script:KVD_RESULT_DIR\raw\after.txt" -Encoding UTF8

# Also capture docker stats
docker stats --no-stream --format 'table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>&1 |
    Set-Content "$script:KVD_RESULT_DIR\raw\docker-stats.txt" -Encoding UTF8

$deltaMB   = [math]::Round($afterMB - $beforeMB, 1)
$deltaFreeMB = [math]::Round($freeBeforeMB - $freeAfterMB, 1)
$vmmem = Kvd-VmmemRamMB
$vhdx  = Kvd-VhdxMB

Kvd-Metric 'engine_before_mb'  $beforeMB
Kvd-Metric 'engine_after_mb'   $afterMB
Kvd-Metric 'engine_delta_mb'   $deltaMB
Kvd-Metric 'host_free_delta_mb' $deltaFreeMB
Kvd-Metric 'vmmem_mb' $vmmem
Kvd-Metric 'vhdx_mb'  $vhdx
Kvd-Observe ("engine {0} to {1} MB; vmmem={2} MB vhdx={3} MB" -f $beforeMB, $afterMB, $vmmem, $vhdx)

Kvd-Note 'WorkingSet delta includes WSL2 VM memory, which both runtimes share on Windows.'
Kvd-Note 'Use free_delta_mb as the host-visible RAM cost — most honest cross-runtime comparison.'

Kvd-End
