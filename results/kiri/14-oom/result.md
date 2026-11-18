Test ID / name:      14 / memory limits
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T09:18:40Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): App OOM-killed; host and other containers survive
Observed:            alloc request threw (expected if container died): The underlying connection was closed: The connection was closed unexpectedly.; app_killed=True pg_ok=True redis_ok=True
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
