Test ID / name:      19 / single container start time
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T07:47:27Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): hyperfine 'docker run --rm alpine:latest true'
Observed:            hyperfine median=514.5ms min=458.8ms max=539.6ms runs=6
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
