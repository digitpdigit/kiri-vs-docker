Test ID / name:      20 / stack start time warm images
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:51:22Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): time docker compose up -d until all services healthy
Observed:            median=13560ms over 3 measured runs, warmup discarded
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Time includes WaitHealthy polling. Same measurement on both runtimes.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
