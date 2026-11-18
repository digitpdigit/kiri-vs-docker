Test ID / name:      07 / compose up/down/logs/exec
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:29:15Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): up works, all services healthy, logs and exec work
Observed:            ps ok; logs ok; exec healthcheck ok; /health 200
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
