Test ID / name:      08 / startup ordering healthcheck depends_on
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:04:26Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): App starts only after both dependencies healthy
Observed:            all healthy at iteration 4 (4x2s = ~8s); /ready 200: {"postgres":"ok","redis":"ok"}

Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
