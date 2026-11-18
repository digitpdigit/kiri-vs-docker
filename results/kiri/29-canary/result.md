Test ID / name:      29 / secrets in logs and reports
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:16:41Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): CANARY_SECRET does not appear in docker logs or Windows Event Log
Observed:            CANARY_SECRET present in container logs (expected; /debug/canary writes it); fake DSN password present in container logs (expected); CANARY_SECRET not in Windows Event Log
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Also check any Kiri crash-report or telemetry files manually: check KVD_RESULT_DIR/raw/event-log.txt
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
