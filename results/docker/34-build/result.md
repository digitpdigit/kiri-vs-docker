Test ID / name:      34 / image build
Runtime / version:   docker / 28.3.2
Host:                win-host
Date / run number:   2026-11-17T12:03:14Z / 1
Command(s):          raw\commands.log
Expected (pass criteria): docker build and compose build: produce a working image
Observed:            docker build succeeded; User=nonroot:nonroot Entrypoint=["/app"]
Result:              PASS
Label:               Verified
Raw output:          raw\
Notes / surprises:
- Build test uses docker build, not compose build: — test compose build: separately if needed.
- Load generator ran on the host (same machine as the engine)

App image ID:        sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3
