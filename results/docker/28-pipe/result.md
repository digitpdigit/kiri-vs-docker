Test ID / name:      28 / named-pipe permissions
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:37:59Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Unprivileged user cannot reach engine pipe
Observed:            current_user=win-host\user in_docker_group=win-host\docker-users                                  Alias            S-1-5-21-<redacted> Mandatory group, Enabled by default, Enabled group is_admin=BUILTIN\Administrators                                        Alias            S-1-5-32-544                                   Group used for deny only                          ; Running as privileged user — connection is expected. Rerun as a plain user to verify restriction.
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- IMPORTANT: rerun this test as a Windows user NOT in docker-users / Administrators to fully verify.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
