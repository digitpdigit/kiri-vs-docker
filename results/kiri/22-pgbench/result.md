Test ID / name:      22 / pgbench
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T10:21:19Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): tps read-heavy and write-heavy via pgbench inside container
Observed:            read_tps=61453.64597 write_tps=1719.59251 scale=10 clients=5
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
