Test ID / name:      09 / service-name DNS
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:04:46Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): postgres and redis resolve by name inside the app container
Observed:            postgres resolves: 172.18.0.2      postgres; redis resolves: 172.18.0.3      redis; /ready 200; /ready 200 after postgres restart
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Also verify DNS survives container restart: restart postgres, re-check /ready.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
