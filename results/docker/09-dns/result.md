Test ID / name:      09 / service-name DNS
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:43:46Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): postgres and redis resolve by name inside the app container
Observed:            postgres resolves: 172.21.0.3      postgres; redis resolves: 172.21.0.2      redis; /ready 200; /ready 200 after postgres restart
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Also verify DNS survives container restart: restart postgres, re-check /ready.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
