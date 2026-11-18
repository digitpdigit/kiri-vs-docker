Test ID / name:      22 / pgbench
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T10:31:37Z / 2
Command(s):          raw\commands.log
Expected (pass criteria): tps read-heavy and write-heavy via pgbench inside container
Observed:            read_tps=62235.060063 write_tps=1719.290315 scale=10 clients=5
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
