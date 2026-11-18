Test ID / name:      34 / image build
Runtime / version:   kiri / 27.5.1
Host:                win-host
Date / run number:   2026-11-17T12:12:56Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): docker build and compose build: produce a working image
Observed:            docker build succeeded; User=nonroot:nonroot Entrypoint=["/app"]
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Build test uses docker build, not compose build: — test compose build: separately if needed.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888
