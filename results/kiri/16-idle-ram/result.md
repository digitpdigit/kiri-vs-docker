Test ID / name:      16 / engine idle RAM
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T08:49:25Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): Record Working Set of engine processes with no containers
Observed:            WS=47.2 MB vmmem=907.6 MB vhdx=4095 MB pattern=kiri
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- WorkingSet64 (Windows) includes shared pages. Not directly comparable to Linux VmRSS.
- Human: confirm the process name pattern is fair: set KVD_ENGINE_PROCESS_MATCH if needed.
- For Docker Desktop: pattern 'com.docker' or 'docker'. For Kiri: pattern 'kiri'.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
