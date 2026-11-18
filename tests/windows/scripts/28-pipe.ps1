#!/usr/bin/env pwsh
# Test 28: named-pipe permissions (Windows equivalent of Unix socket test). BLOCKER.
# On Linux: who can reach /var/run/docker.sock
# On Windows: who can reach \\.\pipe\docker_engine (Docker Desktop) or \\.\pipe\kiri (Kiri)
#
# Pass if: an unprivileged user (not in docker-users / engine group) cannot connect to the pipe.
. "$PSScriptRoot\..\lib\common.ps1"
Kvd-Begin '28' 'named-pipe permissions' 'Unprivileged user cannot reach engine pipe'

$pipeName = switch ($env:KVD_RUNTIME) {
    'docker' { 'docker_engine' }
    'kiri'   { 'kiri' }
    default  { 'docker_engine' }
}
if ($env:KVD_ENGINE_PIPE_NAME) { $pipeName = $env:KVD_ENGINE_PIPE_NAME }

$pipePath = "\\.\pipe\$pipeName"
"pipe_path=$pipePath" | Set-Content "$script:KVD_RESULT_DIR\raw\pipe.txt" -Encoding UTF8

# 1. Check the pipe exists
$pipeExists = [System.IO.Directory]::GetFiles('\\.\pipe\') -contains "\\.\pipe\$pipeName"
if (-not $pipeExists) {
    Kvd-Note "Pipe \\.\pipe\$pipeName not found in directory listing. Trying connection test anyway."
}

# 2. Get current user and group membership
$whoami = whoami /groups 2>&1
$whoami | Set-Content "$script:KVD_RESULT_DIR\raw\whoami-groups.txt" -Encoding UTF8
$inDockerGroup = $whoami -match 'docker-users|docker'
$isAdmin       = $whoami -match 'S-1-5-32-544'  # BUILTIN\Administrators SID

Kvd-Observe "current_user=$(whoami) in_docker_group=$inDockerGroup is_admin=$isAdmin"

# 3. Try to connect to the pipe
$canConnect = $false
try {
    $pipe = [System.IO.Pipes.NamedPipeClientStream]::new('.', $pipeName,
            [System.IO.Pipes.PipeDirection]::InOut,
            [System.IO.Pipes.PipeOptions]::None)
    $pipe.Connect(1000)   # 1-second timeout
    $canConnect = $true
    $pipe.Dispose()
} catch {
    $canConnect = $false
}
"can_connect=$canConnect" | Add-Content "$script:KVD_RESULT_DIR\raw\pipe.txt" -Encoding UTF8

Kvd-Metric 'can_connect'      ([int]$canConnect)
Kvd-Metric 'in_docker_group'  ([int]$inDockerGroup)
Kvd-Metric 'is_admin'         ([int]$isAdmin)

# 4. Evaluate
if ($isAdmin -or $inDockerGroup) {
    Kvd-Observe 'Running as privileged user — connection is expected. Rerun as a plain user to verify restriction.'
    Kvd-Note 'IMPORTANT: rerun this test as a Windows user NOT in docker-users / Administrators to fully verify.'
    if (-not $canConnect) { Kvd-Fail "Expected connection as privileged user but pipe refused" }
} else {
    # Unprivileged user: should NOT be able to connect
    if ($canConnect) {
        Kvd-Fail 'Unprivileged user can connect to engine pipe — anyone can control containers'
    } else {
        Kvd-Observe 'Unprivileged user correctly denied access to engine pipe'
    }
}

Kvd-End
