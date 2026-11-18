# Windows test harness

PowerShell scripts, one per test. Each script starts from a clean stack, runs one check and writes `results\<runtime>\<test>\` with `result.md`, `metrics.json` and `raw\`.

## Prerequisites

```powershell
winget install sharkdp.hyperfine   # tests 19, 20
winget install k6                  # tests 21, 38
# Go and Python 3 must be on PATH
```

The app image `kiri-vs-docker-app:local` must exist in the engine under test (`docker build` or `docker load -i app-image.tar`). The runner stops if it is missing.

## Run

Run one engine at a time.

```powershell
powershell -File tests\windows\run.ps1 -Runtime docker -KeepGoing
powershell -File tests\windows\run.ps1 -Runtime kiri   -KeepGoing
```

Flags:
- `-Only 7,8,19` run specific test IDs
- `-Skip 24` leave out test IDs
- `-Round 2` repeat run, result folder gets `-r2`
- `-Quick` shorter sleeps and fewer iterations (ignored by `compare.py`)
- `-KeepGoing` continue after a failing script
- `-DryRun` list scripts without running them

Running a test again without `-Round` adds a `+2`, `+3` suffix to its folder. `compare.py` uses every folder it finds, so delete reruns you do not want counted.

## Environment variables

Optional overrides. Set them before running.

| Var | Purpose | Default / example |
| --- | --- | --- |
| `KVD_ENGINE_PROCESS_MATCH` | Process name pattern for RAM and CPU tests | `docker`. Set to `kiri` for Kiri |
| `KVD_ENGINE_PIPE_NAME` | Named pipe for test 28 | `docker_engine` / `kiri` |
| `KVD_RUNTIME_SERVICE_NAME` | Windows service for test 02 | `com.docker.service` / `kiri` |
| `KVD_ENGINE_INSTALL_PATH` | Install dir for test 24 | `C:\Program Files\Docker` |
| `KVD_ENGINE_VHDX_PATH` | WSL disk file(s) for tests 16, 17, 24 | auto-detected |

## Compare

```powershell
python tests\compare.py    # writes results\COMPARE.md
```
