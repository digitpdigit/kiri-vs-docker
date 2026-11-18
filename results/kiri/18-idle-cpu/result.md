Test ID / name:      18 / engine idle CPU
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:52:48Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): one-core percent of engine processes over a quiet sample
Observed:            engine CPU 1.38% of one logical core over 180s
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- 100 means one logical core busy for the whole sample. Host has many cores.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
