# Shared helpers for the Windows test harness.
# Dot-source this file from each test script: . "$PSScriptRoot\..\lib\common.ps1"
#
# Writes result.md and metrics.json per test; tests/compare.py reads metrics.json.

Set-StrictMode -Version Latest
# Continue: docker writes progress to stderr; PS 5.1 treats that as terminating under Stop.
$ErrorActionPreference = 'Continue'

# ── Environment defaults ────────────────────────────────────────────────────

if (-not $env:KVD_ROOT) {
    $env:KVD_ROOT = (Resolve-Path "$PSScriptRoot\..\..\..").Path
}
if (-not $env:KVD_RUNTIME)         { $env:KVD_RUNTIME = '' }
if (-not $env:KVD_ROUND)           { $env:KVD_ROUND = '1' }
if (-not $env:KVD_QUICK)           { $env:KVD_QUICK = '0' }
if (-not $env:KVD_PROJECT)         { $env:KVD_PROJECT = 'kvd' }
if (-not $env:KVD_COMPOSE_FILE)    { $env:KVD_COMPOSE_FILE = "$env:KVD_ROOT\compose\compose.yml" }
if (-not $env:KVD_ENV_FILE)        { $env:KVD_ENV_FILE = "$env:KVD_ROOT\compose\.env.example" }
if (-not $env:KVD_APP_URL)         { $env:KVD_APP_URL = 'http://127.0.0.1:8080' }
if (-not $env:KVD_LOAD_ON_HOST)    { $env:KVD_LOAD_ON_HOST = '1' }

# ── Script-level state ──────────────────────────────────────────────────────

$script:KVD_TEST_ID   = ''
$script:KVD_TEST_NAME = ''
$script:KVD_EXPECTED  = ''
$script:KVD_OBSERVED  = ''
$script:KVD_RESULT    = 'PASS'
$script:KVD_LABEL     = 'Verified'
$script:KVD_NOTES     = [System.Collections.Generic.List[string]]::new()
$script:KVD_METRICS   = [ordered]@{}
$script:KVD_RESULT_DIR = ''

# ── Core lifecycle ──────────────────────────────────────────────────────────

function Kvd-Begin {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Expected = ''
    )
    $script:KVD_TEST_ID   = $Id
    $script:KVD_TEST_NAME = $Name
    $script:KVD_EXPECTED  = $Expected
    $script:KVD_OBSERVED  = ''
    $script:KVD_RESULT    = 'PASS'
    $script:KVD_LABEL     = 'Verified'
    $script:KVD_NOTES     = [System.Collections.Generic.List[string]]::new()
    $script:KVD_METRICS   = [ordered]@{}

    # results\<runtime>\<script name>[-rN][-quick]  (e.g. results\kiri\22-pgbench-r2)
    $testName = [IO.Path]::GetFileNameWithoutExtension((Get-PSCallStack)[1].ScriptName)
    $suffix = ''
    if ($env:KVD_ROUND -ne '1') { $suffix += "-r$env:KVD_ROUND" }
    if ($env:KVD_QUICK -eq '1') { $suffix += '-quick' }

    $base = "$env:KVD_ROOT\results\$env:KVD_RUNTIME\${testName}${suffix}"
    $dir  = $base
    $n    = 2
    while (Test-Path $dir) { $dir = "${base}+$n"; $n++ }

    $script:KVD_RESULT_DIR = $dir
    New-Item -ItemType Directory -Path "$dir\raw" -Force | Out-Null

    Write-Host "[kvd] begin test $Id $Name -> $dir"
}

function Kvd-End {
    if (-not $script:KVD_RESULT_DIR) { throw 'Kvd-End called before Kvd-Begin' }

    $imageId   = Kvd-AppImageId
    $engineVer = Kvd-EngineVersion
    $host_     = $env:COMPUTERNAME

    if (-not $script:KVD_OBSERVED) { $script:KVD_OBSERVED = 'see raw/' }
    if (-not $script:KVD_EXPECTED) { $script:KVD_EXPECTED = "see test script $script:KVD_TEST_ID" }

    if ($env:KVD_QUICK -eq '1') {
        Kvd-Note 'QUICK mode: compare.py ignores this directory'
        $script:KVD_LABEL = 'Not tested'
    }
    if ($env:KVD_LOAD_ON_HOST -eq '1') {
        Kvd-Note 'Load generator ran on the host (same machine as the engine)'
    }

    $notesText = ($script:KVD_NOTES | ForEach-Object { "- $_" }) -join "`n"

    $resultMd = @"
Test ID / name:      $script:KVD_TEST_ID / $script:KVD_TEST_NAME
Runtime / version:   $env:KVD_RUNTIME / $engineVer
Host:                $host_
Date / run number:   $((Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')) / $env:KVD_ROUND
Command(s):          raw\commands.log
Expected (pass criteria): $script:KVD_EXPECTED
Observed:            $script:KVD_OBSERVED
Result:              $script:KVD_RESULT
Label:               $script:KVD_LABEL
Raw output:          raw\
Notes / surprises:
$notesText

App image ID:        $imageId
"@
    Set-Content -Path "$script:KVD_RESULT_DIR\result.md" -Value $resultMd -Encoding UTF8

    # metrics.json — read by tests/compare.py
    $metricsObj = [ordered]@{
        test_id        = $script:KVD_TEST_ID
        test_name      = $script:KVD_TEST_NAME
        runtime        = $env:KVD_RUNTIME
        round          = [int]$env:KVD_ROUND
        quick          = [int]$env:KVD_QUICK
        result         = $script:KVD_RESULT
        label          = $script:KVD_LABEL
        engine_version = $engineVer
        app_image_id   = $imageId
        host           = $host_
        load_on_host   = [int]$env:KVD_LOAD_ON_HOST
        metrics        = $script:KVD_METRICS
    }
    $json = $metricsObj | ConvertTo-Json -Depth 3
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText("$script:KVD_RESULT_DIR\metrics.json", $json, $utf8)

    Write-Host "[kvd] end test $script:KVD_TEST_ID $script:KVD_RESULT"
    if ($script:KVD_RESULT -eq 'FAIL') { exit 1 }
}

# ── State mutators ──────────────────────────────────────────────────────────

function Kvd-Metric {
    param([string]$Key, $Value)
    $script:KVD_METRICS[$Key] = $Value
}

function Kvd-Fail {
    param([string]$Msg)
    $script:KVD_RESULT = 'FAIL'
    $script:KVD_OBSERVED += if ($script:KVD_OBSERVED) { "; $Msg" } else { $Msg }
}

function Kvd-Partial {
    param([string]$Msg)
    if ($script:KVD_RESULT -ne 'FAIL') { $script:KVD_RESULT = 'PARTIAL' }
    $script:KVD_OBSERVED += if ($script:KVD_OBSERVED) { "; $Msg" } else { $Msg }
}

function Kvd-Observe {
    param([string]$Msg)
    $script:KVD_OBSERVED += if ($script:KVD_OBSERVED) { "; $Msg" } else { $Msg }
}

function Kvd-Note {
    param([string]$Msg)
    $script:KVD_NOTES.Add($Msg)
}

# ── Docker helpers ──────────────────────────────────────────────────────────

function Kvd-Compose {
    # Call as: Kvd-Compose @('up','-d','--no-build')
    # Do not pass bare -d — PowerShell treats it as a switch.
    param([Parameter(Mandatory = $true, Position = 0)][string[]]$ComposeArgs)
    if ($script:KVD_RESULT_DIR) {
        "$ docker compose $($ComposeArgs -join ' ')" |
            Add-Content -Path "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
    }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        & docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE @ComposeArgs
        if ($LASTEXITCODE -ne 0) {
            throw "docker compose failed with exit $LASTEXITCODE"
        }
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Kvd-ComposeFiles {
    # Usage: Kvd-ComposeFiles @('-f', 'extra.yml') -- up -d
    param([string[]]$ExtraFiles, [string[]]$DockerArgs)
    $fArgs = @('-p', $env:KVD_PROJECT, '-f', $env:KVD_COMPOSE_FILE)
    foreach ($f in $ExtraFiles) { $fArgs += '-f'; $fArgs += $f }
    $fArgs += '--env-file'; $fArgs += $env:KVD_ENV_FILE
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $n = 0
        while ($true) {
            $n++
            $ErrorActionPreference = 'Continue'
            & docker compose @fArgs @DockerArgs
            if ($LASTEXITCODE -eq 0) { break }
            if ($n -ge 5) { throw "docker compose failed with exit $LASTEXITCODE" }
            Write-Host ("[kvd] compose retry {0} exit {1}" -f $n, $LASTEXITCODE)
            Start-Sleep 4
        }
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Kvd-Up {
    $n = 0
    while ($true) {
        $n++
        try {
            Kvd-Compose @('up', '-d', '--no-build')
            break
        } catch {
            if ($n -ge 5) { throw }
            Write-Host ("[kvd] compose up failed (try {0}): {1}" -f $n, $_)
            Start-Sleep 4
            try { Kvd-Compose @('down', '--remove-orphans') } catch { }
            Start-Sleep 2
        }
    }
    Kvd-WaitHealthy
}

function Kvd-Down {
    try { Kvd-Compose @('down', '--remove-orphans') } catch { }
}

function Kvd-DownV {
    try { Kvd-Compose @('down', '-v', '--remove-orphans') } catch { }
}

function Kvd-WaitHealthy {
    param([switch]$AllowFail)
    $tries = if ($env:KVD_QUICK -eq '1') { 30 } else { 60 }
    for ($i = 1; $i -le $tries; $i++) {
        $st = docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE `
              ps --format '{{.Service}} {{.Health}} {{.State}}' 2>$null | Out-String
        if ($st -match 'app healthy' -and $st -match 'postgres healthy' -and $st -match 'redis healthy') {
            return $true
        }
        Start-Sleep -Seconds 2
    }
    # Out-Null: table output must not leak into the return value (it made `-not $ok` false).
    try { Kvd-Compose @('ps') | Out-Null } catch { }
    if ($AllowFail) { return $false }
    throw "Stack not healthy after $tries tries"
}

# Crash Postgres the way a real crash looks to the daemon: the main process dies on its own.
# `docker kill` is a manual stop; restart policy ignores it (docs.docker.com/engine/containers/start-containers-automatically).
# pg_ctl -m immediate = SIGQUIT to postmaster, no shutdown checkpoint, crash recovery on next start.
function Kvd-CrashPostgres {
    $name = "$($env:KVD_PROJECT)-postgres-1"
    "$ docker exec -u postgres $name pg_ctl -D /var/lib/postgresql/data stop -m immediate" |
        Add-Content "$script:KVD_RESULT_DIR\raw\commands.log" -Encoding UTF8
    $ErrorActionPreference = 'Continue'
    docker exec -u postgres $name pg_ctl -D /var/lib/postgresql/data stop -m immediate 2>&1 | Out-String
}

function Kvd-AppImageId {
    $id = docker image inspect --format '{{.Id}}' kiri-vs-docker-app:local 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $id) { return 'missing' }
    return $id.Trim()
}

function Kvd-EngineVersion {
    $v = docker version --format '{{.Server.Version}}' 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $v) { return 'unknown' }
    return $v.Trim()
}

function Kvd-Curl {
    param([string]$Url, [int]$TimeoutSec = 5)
    $r = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop
    return $r
}

function Kvd-Psql {
    param([string]$Query)
    docker compose -p $env:KVD_PROJECT -f $env:KVD_COMPOSE_FILE --env-file $env:KVD_ENV_FILE `
        exec -T postgres psql -U app -d appdb -Atc $Query
    if ($LASTEXITCODE -ne 0) { throw "psql failed with exit $LASTEXITCODE" }
}

function Kvd-SeqDump {
    param([string]$OutFile)
    # PS 5.1 UTF8 encoding writes a BOM; verify then fails to parse seq=1.
    $text = (Kvd-Psql 'SELECT seq FROM events ORDER BY seq') | Out-String
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($OutFile, $text.Trim() + "`n", $utf8)
}

function Kvd-Verify {
    param([string]$AckLog, [string]$SeqFile)
    $out = "$script:KVD_RESULT_DIR\raw\verify.txt"
    Push-Location "$env:KVD_ROOT\tests\tools\verify"
    try {
        go run . -ack $AckLog -seq-file $SeqFile | Tee-Object -FilePath $out
    } finally {
        Pop-Location
    }
    return $out
}

function Kvd-Writeloop {
    param([int]$N = 20, [string]$AckLog = '')
    if (-not $AckLog) { $AckLog = "$script:KVD_RESULT_DIR\raw\ack.log" }
    Push-Location "$env:KVD_ROOT\tests\tools\writeloop"
    try {
        go run . -url $env:KVD_APP_URL -n $N -rate 20 -ack $AckLog
    } finally {
        Pop-Location
    }
    return $AckLog
}

function Kvd-Sleep {
    param([int]$Seconds)
    $s = if ($env:KVD_QUICK -eq '1' -and $Seconds -gt 5) { 5 } else { $Seconds }
    Start-Sleep -Seconds $s
}

# ── Windows-specific helpers ────────────────────────────────────────────────

function Kvd-EngineRamMB {
    # Sum WorkingSet of all processes matching the engine name pattern.
    # KVD_ENGINE_PROCESS_MATCH defaults to 'docker' for Docker Desktop; set to 'kiri' for Kiri.
    $pattern = if ($env:KVD_ENGINE_PROCESS_MATCH) { $env:KVD_ENGINE_PROCESS_MATCH } else { 'docker' }
    $procs = Get-Process | Where-Object { $_.ProcessName -match $pattern }
    if (-not $procs) { return 0.0 }
    $totalBytes = ($procs | Measure-Object WorkingSet64 -Sum).Sum
    return [math]::Round($totalBytes / 1MB, 1)
}

function Kvd-EngineProcessList {
    # Writes process list to raw/processes.txt and returns it.
    $pattern = if ($env:KVD_ENGINE_PROCESS_MATCH) { $env:KVD_ENGINE_PROCESS_MATCH } else { 'docker' }
    $procs = Get-Process | Where-Object { $_.ProcessName -match $pattern } |
             Select-Object Id, ProcessName, @{N='WorkingSet_MB';E={[math]::Round($_.WorkingSet64/1MB,1)}},
                           @{N='CPU_s';E={[math]::Round($_.CPU,1)}} |
             Sort-Object WorkingSet_MB -Descending
    $out = "$script:KVD_RESULT_DIR\raw\processes.txt"
    $procs | Format-Table | Out-String | Set-Content -Path $out -Encoding UTF8
    return $procs
}

function Kvd-VmmemRamMB {
    $procs = Get-Process | Where-Object { $_.ProcessName -match '^vmmem' }
    if (-not $procs) { return 0.0 }
    $sum = ($procs | Measure-Object WorkingSet64 -Sum).Sum
    return [math]::Round($sum / 1MB, 1)
}

function Kvd-VhdxMB {
    $paths = @()
    if ($env:KVD_RUNTIME -eq 'kiri') {
        $paths += Join-Path $env:LOCALAPPDATA 'Kiri\wsl'
    } else {
        $paths += Join-Path $env:LOCALAPPDATA 'Docker\wsl'
    }
    if ($env:KVD_ENGINE_VHDX_PATH) { $paths = @($env:KVD_ENGINE_VHDX_PATH) }
    $bytes = 0L
    foreach ($root in $paths) {
        if (-not (Test-Path $root)) { continue }
        Get-ChildItem $root -Recurse -Filter *.vhdx -ErrorAction SilentlyContinue | ForEach-Object {
            $bytes += $_.Length
        }
    }
    return [math]::Round($bytes / 1MB, 1)
}

function Kvd-InstallMB {
    $candidates = @()
    if ($env:KVD_ENGINE_INSTALL_PATH) {
        $candidates += $env:KVD_ENGINE_INSTALL_PATH
    } elseif ($env:KVD_RUNTIME -eq 'kiri') {
        $candidates += (Join-Path $env:LOCALAPPDATA 'Kiri')
    } else {
        $candidates += (Join-Path $env:ProgramFiles 'Docker')
        $candidates += (Join-Path $env:LOCALAPPDATA 'Docker')
    }
    $bytes = 0L
    $used = @()
    foreach ($p in $candidates) {
        if (-not (Test-Path $p)) { continue }
        $used += $p
        $sum = (Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue |
            Measure-Object -Property Length -Sum).Sum
        if ($sum) { $bytes += $sum }
    }
    $mb = [math]::Round($bytes / 1MB, 1)
    if ($script:KVD_RESULT_DIR) {
        ("paths=" + ($used -join '; ') + " install_mb=$mb") |
            Set-Content (Join-Path $script:KVD_RESULT_DIR 'raw\install-size.txt') -Encoding UTF8
    }
    return $mb
}

function Kvd-ParseDfGb {
    param([string]$Text, [string]$TypeName)
    $line = ($Text -split "`n" | Where-Object { $_ -match "^$TypeName\s" } | Select-Object -First 1)
    if (-not $line) { return $null }
    if ($line -notmatch '([\d.]+)\s*(GB|MB|kB|B)\s+') { return $null }
    $n = [double]$Matches[1]
    $u = $Matches[2]
    switch ($u) {
        'GB' { return [math]::Round($n, 3) }
        'MB' { return [math]::Round($n / 1024, 3) }
        'kB' { return [math]::Round($n / 1024 / 1024, 3) }
        default { return [math]::Round($n / 1024 / 1024 / 1024, 6) }
    }
}

function Kvd-EngineCpuSample {
    param([int]$Seconds = 60)
    $pattern = if ($env:KVD_ENGINE_PROCESS_MATCH) { $env:KVD_ENGINE_PROCESS_MATCH } else { 'docker' }
    $t0 = Get-Date
    $c0 = 0.0
    Get-Process | Where-Object { $_.ProcessName -match $pattern } | ForEach-Object {
        if ($_.CPU) { $c0 += $_.CPU }
    }
    Start-Sleep -Seconds $Seconds
    $c1 = 0.0
    Get-Process | Where-Object { $_.ProcessName -match $pattern } | ForEach-Object {
        if ($_.CPU) { $c1 += $_.CPU }
    }
    $wall = ((Get-Date) - $t0).TotalSeconds
    if ($wall -le 0) { return 0.0 }
    # CPU property is process-seconds. 100 = one logical core busy for the whole sample.
    return [math]::Round((($c1 - $c0) / $wall) * 100, 2)
}
