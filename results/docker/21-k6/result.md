Test ID / name:      21 / app latency k6
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:48:16Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): p50/p95/p99 latency and req/s for /health, /db, /cache
Observed:            see raw/
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load ran on the same host as the engine (see load_on_host). Numbers are relative, not absolute.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
