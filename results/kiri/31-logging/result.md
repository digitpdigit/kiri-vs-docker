Test ID / name:      31 / log rotation
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:17:00Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): json-file rotation honored; docker logs still works; disk bounded
Observed:            docker logs still works after high log volume; LogConfig: {"Type":"json-file","Config":{"max-file":"3","max-size":"10m"}}; json-file driver confirmed; max-size=10m max-file=3
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
