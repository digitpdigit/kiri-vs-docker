Test ID / name:      08 / startup ordering healthcheck depends_on
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:43:23Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): App starts only after both dependencies healthy
Observed:            all healthy at iteration 4 (4x2s = ~8s); /ready 200: {"postgres":"ok","redis":"ok"}

Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
