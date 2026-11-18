Test ID / name:      13 / restart policy
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T09:16:18Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Each service returns after crash per unless-stopped
Observed:            app recovered after panic in ~2s; postgres recovered in ~6s
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
