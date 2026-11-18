Test ID / name:      01 / postgres hard-kill survival
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T09:14:00Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): ACKED_BUT_MISSING = 0 after Stop-Process on postgres container
Observed:            ACKED_BUT_MISSING=0
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Power-cycle step (kill -9 on host) is not automated on Windows. Run manually and record separately.
- Crash made with pg_ctl stop -m immediate (no shutdown checkpoint). docker kill is a manual stop and skips the restart policy.
- This exercises Postgres crash recovery on the engine volume, not a host power cut.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
