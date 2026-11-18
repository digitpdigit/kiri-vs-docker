Test ID / name:      14 / memory limits
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T09:19:51Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): App OOM-killed; host and other containers survive
Observed:            alloc request threw (expected if container died): The underlying connection was closed: The connection was closed unexpectedly.; app_killed=True pg_ok=True redis_ok=True
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
