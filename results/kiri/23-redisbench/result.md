Test ID / name:      23 / redis-benchmark
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:16:06Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): ops/s for SET and GET via redis-benchmark inside container
Observed:            SET=162866.44 GET=141242.94 ops/s clients=10 requests=50000
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
