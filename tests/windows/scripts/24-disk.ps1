#!/usr/bin/env pwsh
# Test 24: disk usage. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '24' 'disk usage' 'docker system df; install dir; WSL vhdx'

Kvd-DownV
Kvd-Up

$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$summary = docker system df 2>&1 | Out-String
$ErrorActionPreference = $prev
$summary | Set-Content (Join-Path $script:KVD_RESULT_DIR 'raw\system-df-summary.txt') -Encoding UTF8

$prev = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
docker system df --verbose 2>&1 | Set-Content (Join-Path $script:KVD_RESULT_DIR 'raw\system-df.txt') -Encoding UTF8
$ErrorActionPreference = $prev

$imagesGb  = Kvd-ParseDfGb $summary 'Images'
$volsGb    = Kvd-ParseDfGb $summary 'Local Volumes'
$cacheGb   = Kvd-ParseDfGb $summary 'Build Cache'
$installMB = Kvd-InstallMB
$vhdxMB    = Kvd-VhdxMB

if ($imagesGb -ne $null) { Kvd-Metric 'images_gb' $imagesGb }
if ($volsGb -ne $null)   { Kvd-Metric 'volumes_gb' $volsGb }
if ($cacheGb -ne $null)  { Kvd-Metric 'cache_gb' $cacheGb }
Kvd-Metric 'install_mb' $installMB
Kvd-Metric 'vhdx_mb'    $vhdxMB
Kvd-Observe ("images_gb={0} volumes_gb={1} cache_gb={2} install_mb={3} vhdx_mb={4}" -f $imagesGb, $volsGb, $cacheGb, $installMB, $vhdxMB)
Kvd-End
