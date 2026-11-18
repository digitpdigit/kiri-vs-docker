Test ID / name:      17 / stack RAM
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T08:59:54Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Record host Working Set before and after compose up
Observed:            engine 747.8 to 741.6 MB; vmmem=1730.3 MB vhdx=20807 MB
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- WorkingSet delta includes WSL2 VM memory, which both runtimes share on Windows.
- Use free_delta_mb as the host-visible RAM cost — most honest cross-runtime comparison.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
