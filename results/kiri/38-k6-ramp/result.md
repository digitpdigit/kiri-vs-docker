Test ID / name:      38 / k6 ramp max load
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:58:06Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): highest VUs with p95 under 100ms and fail rate under 1 percent
Observed:            max_stable_vus=400 rps=0 p95_ms=66.5 stop=
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- GET /health only. Stop when p95 > 100ms or check fail rate > 1%.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
