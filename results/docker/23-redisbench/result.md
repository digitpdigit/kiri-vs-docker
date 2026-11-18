Test ID / name:      23 / redis-benchmark
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:37:42Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): ops/s for SET and GET via redis-benchmark inside container
Observed:            SET=161812.31 GET=147929.00 ops/s clients=10 requests=50000
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
