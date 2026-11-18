#!/usr/bin/env pwsh
# Windows test runner.
# Usage:
#   powershell -File tests\windows\run.ps1 -Runtime docker
#   powershell -File tests\windows\run.ps1 -Runtime kiri -Only 7,8,9
#   powershell -File tests\windows\run.ps1 -Runtime docker -Round 2 -KeepGoing -DryRun
#
# Each test writes results\<runtime>\<test>\ in the repo root (result.md, metrics.json, raw\).
# Afterward run: python tests\compare.py

[CmdletBinding()]
param(
    [ValidateSet('docker','kiri')]
    [string]$Runtime = '',

    [string]$Only = '',          # comma-separated test IDs
    [string]$Skip = '',          # comma-separated test IDs
    [int]   $Round = 1,
    [switch]$Quick,
    [switch]$KeepGoing,
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ROOT = (Resolve-Path "$PSScriptRoot\..\..")
$SCRIPTS = "$PSScriptRoot\scripts"

# ── Validate ────────────────────────────────────────────────────────────────

if (-not $Runtime) {
    Write-Error "Required: --runtime docker|kiri"
    exit 2
}

# ── Env export ──────────────────────────────────────────────────────────────

$env:KVD_ROOT    = $ROOT
$env:KVD_RUNTIME = $Runtime
$env:KVD_ROUND   = $Round
$env:KVD_QUICK   = if ($Quick) { '1' } else { '0' }

# ── Discover scripts ─────────────────────────────────────────────────────────

$allScripts = Get-ChildItem -Path $SCRIPTS -Filter '*.ps1' |
              Sort-Object Name

function Get-KvdScriptId {
    param([string]$Name)
    if ($Name -match '^(\d+)-') { return $Matches[1].TrimStart('0') }
    if ($Name -match '^0-') { return '0' }
    return ''
}

if ($Only) {
    $ids = @($Only -split ',' | ForEach-Object {
        $t = $_.Trim()
        if ($t -match '^0+$') { '0' } else { $t.TrimStart('0') }
    })
    $allScripts = $allScripts | Where-Object { (Get-KvdScriptId $_.Name) -in $ids }
}

if ($Skip) {
    $skipIds = @($Skip -split ',' | ForEach-Object {
        $t = $_.Trim()
        if ($t -match '^0+$') { '0' } else { $t.TrimStart('0') }
    })
    $allScripts = $allScripts | Where-Object { (Get-KvdScriptId $_.Name) -notin $skipIds }
}

$allScripts = @($allScripts)
if ($allScripts.Count -eq 0) {
    Write-Error "No scripts matched. Check --only or the scripts directory."
    exit 2
}

# ── Pre-flight ───────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "=== kiri-vs-docker Windows run ==="
Write-Host "Runtime : $Runtime"
Write-Host "Round   : $Round"
Write-Host "Quick   : $($env:KVD_QUICK)"
Write-Host "Scripts : $($allScripts.Count)"
Write-Host ""

# Verify docker responds
$ver = docker version --format '{{.Server.Version}}' 2>$null
if ($LASTEXITCODE -ne 0 -or -not $ver) {
    Write-Error "docker not reachable. Is $Runtime running?"
    exit 2
}
Write-Host "Engine version: $ver"
Write-Host ""

# Verify app image exists
$imgId = docker image inspect --format '{{.Id}}' kiri-vs-docker-app:local 2>$null
if ($LASTEXITCODE -ne 0 -or -not $imgId) {
    Write-Error "kiri-vs-docker-app:local not found. Build or docker load it first."
    exit 2
}
Write-Host "App image: $($imgId.Trim())"
Write-Host ""

New-Item -ItemType Directory -Path "$ROOT\results" -Force | Out-Null

# ── Run ──────────────────────────────────────────────────────────────────────

$passed = 0
$failed = 0
$skipped = 0

foreach ($script in $allScripts) {
    Write-Host "--- $($script.Name) ---"
    if ($DryRun) {
        Write-Host "[dry-run] skip"
        $skipped++
        continue
    }
    # Child process: script `exit 1` must not kill this runner.
    # Host may be Windows PowerShell 5.1 (no pwsh).
    $shellExe = (Get-Process -Id $PID).Path
    $p = Start-Process -FilePath $shellExe -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script.FullName) `
        -WorkingDirectory $ROOT -Wait -PassThru -NoNewWindow
    if ($p.ExitCode -eq 0) {
        $passed++
    } else {
        $failed++
        Write-Warning "FAILED: $($script.Name) exit=$($p.ExitCode)"
        if (-not $KeepGoing) {
            Write-Error "Stopping after failure. Use -KeepGoing to continue."
            break
        }
    }
    Write-Host ""
}

Write-Host ""
Write-Host "=== summary: passed=$passed failed=$failed skipped=$skipped ==="
Write-Host "Results in: $ROOT\results\"
Write-Host "Run compare: python tests\compare.py"
Write-Host ""

if ($failed -gt 0) { exit 1 }
