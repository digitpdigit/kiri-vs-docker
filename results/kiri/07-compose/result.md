Test ID / name:      07 / compose up/down/logs/exec
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:04:12Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): up works, all services healthy, logs and exec work
Observed:            ps ok; logs ok; exec healthcheck ok; /health 200
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
