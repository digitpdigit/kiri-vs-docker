Test ID / name:      38 / k6 ramp max load
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T09:05:14Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): highest VUs with p95 under 100ms and fail rate under 1 percent
Observed:            max_stable_vus=200 rps=0 p95_ms=29.0 stop=
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- GET /health only. Stop when p95 > 100ms or check fail rate > 1%.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
