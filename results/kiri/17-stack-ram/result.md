Test ID / name:      17 / stack RAM
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:55:58Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Record host Working Set before and after compose up
Observed:            engine 40.8 to 40.8 MB; vmmem=957.1 MB vhdx=4127 MB
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- WorkingSet delta includes WSL2 VM memory, which both runtimes share on Windows.
- Use free_delta_mb as the host-visible RAM cost — most honest cross-runtime comparison.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
