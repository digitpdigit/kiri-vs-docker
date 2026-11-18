Test ID / name:      20 / stack start time warm images
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:10:31Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): time docker compose up -d until all services healthy
Observed:            median=12259ms over 3 measured runs, warmup discarded
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Time includes WaitHealthy polling. Same measurement on both runtimes.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
