Test ID / name:      02 / data survives engine restart
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:03:56Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): ACKED_BUT_MISSING = 0 after engine service restart
Observed:            cannot restart kiri: Cannot find any service with service name 'kiri'.. Need elevated PowerShell.
Result:              PARTIAL
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Re-run 02 from an Administrator terminal.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
