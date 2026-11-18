Test ID / name:      19 / single container start time
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:09:28Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): hyperfine 'docker run --rm alpine:latest true'
Observed:            hyperfine median=117.7ms min=85.8ms max=126.7ms runs=6
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
