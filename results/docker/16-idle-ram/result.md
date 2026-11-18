Test ID / name:      16 / engine idle RAM
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T08:59:15Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Record Working Set of engine processes with no containers
Observed:            WS=794.1 MB vmmem=1633 MB vhdx=20807 MB pattern=com.docker|docker
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- WorkingSet64 (Windows) includes shared pages. Not directly comparable to Linux VmRSS.
- Human: confirm the process name pattern is fair: set KVD_ENGINE_PROCESS_MATCH if needed.
- For Docker Desktop: pattern 'com.docker' or 'docker'. For Kiri: pattern 'kiri'.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
