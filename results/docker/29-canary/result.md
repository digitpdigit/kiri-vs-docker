Test ID / name:      29 / secrets in logs and reports
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:48:38Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): CANARY_SECRET does not appear in docker logs or Windows Event Log
Observed:            CANARY_SECRET present in container logs (expected; /debug/canary writes it); fake DSN password present in container logs (expected); CANARY_SECRET not in Windows Event Log
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Also check any Kiri crash-report or telemetry files manually: check KVD_RESULT_DIR/raw/event-log.txt
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
