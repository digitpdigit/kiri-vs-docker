Test ID / name:      13 / restart policy
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T09:14:25Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Each service returns after crash per unless-stopped
Observed:            app recovered after panic in ~2s; postgres recovered in ~6s
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
