Test ID / name:      18 / engine idle CPU
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T09:03:07Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): one-core percent of engine processes over a quiet sample
Observed:            engine CPU 11.56% of one logical core over 180s
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- 100 means one logical core busy for the whole sample. Host has many cores.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
