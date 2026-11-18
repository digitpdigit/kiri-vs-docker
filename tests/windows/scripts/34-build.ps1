#!/usr/bin/env pwsh
# Test 34: image builds work. FINDING.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '34' 'image build' 'docker build and compose build: produce a working image'

$tag = 'kiri-vs-docker-app:build-test'

# docker build
Write-Host "[kvd] docker build..."
"$ docker build -t $tag $env:KVD_ROOT\app" |
    Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
docker build -t $tag "$env:KVD_ROOT\app" 2>&1 |
    Tee-Object -FilePath "$script:KVD_RESULT_DIR\raw\build.txt"
if ($LASTEXITCODE -ne 0) {
    Kvd-Fail "docker build exited $LASTEXITCODE"
    Kvd-End
    return
}
Kvd-Observe 'docker build succeeded'

# Distroless has no ls/id/shell. Inspect config instead.
Write-Host "[kvd] inspect built image..."
$cfg = docker inspect --format 'User={{.Config.User}} Entrypoint={{json .Config.Entrypoint}}' $tag 2>&1
$cfg | Add-Content "$script:KVD_RESULT_DIR\raw\build.txt" -Encoding UTF8
Kvd-Observe $cfg
if ($cfg -match 'User=$' -or $cfg -match 'User=0' -or $cfg -match 'User=root') {
    Kvd-Fail 'image user is root or empty (expected nonroot)'
}

# Clean up test image
docker rmi -f $tag 2>$null | Out-Null
Kvd-Note 'Build test uses docker build, not compose build: — test compose build: separately if needed.'
Kvd-End
