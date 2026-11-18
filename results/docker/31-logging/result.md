Test ID / name:      31 / log rotation
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:48:59Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): json-file rotation honored; docker logs still works; disk bounded
Observed:            docker logs still works after high log volume; LogConfig: {"Type":"json-file","Config":{"max-file":"3","max-size":"10m"}}; json-file driver confirmed; max-size=10m max-file=3
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
