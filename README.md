# Kiri vs Docker Desktop on Windows

A repeatable comparison of [Kiri](https://github.com/libracoder/kiri) 0.2.1 and Docker Desktop 4.44.2 (Engine 28.3.2) on one Windows 11 PC. Both run the same small stack: a Go web app, Postgres 16 and Redis 7.

This is an independent study. It is not affiliated with or endorsed by the Kiri or Docker projects. Results are from one machine on 2026-11-17 with the versions named above.

Scope: **Windows developer machine only.** Both tools run their engine in a WSL2 VM there. Kiri's Linux mode without a VM is not tested, so this says nothing about Linux servers or production.

## Results in short

| Area | Result |
| --- | --- |
| Compatibility (Compose, health order, DNS, logs, build) | Same on both |
| Reliability (Postgres crash with write loop, restart policy, memory limit) | Same on both. No acknowledged write lost |
| Idle CPU | Kiri 1.4% of one core, Docker Desktop 11.6% |
| Idle RAM (WSL2 VM) | Kiri 908 MB, Docker Desktop 1633 MB |
| Single container start | Kiri 118 ms, Docker Desktop 514 ms |
| Stack to healthy, pgbench, HTTP load ramp | No meaningful difference |
| Disk, empty / stack up / after build | Kiri 108 / 972 / 2796 MB, Docker Desktop 1464 / 2360 / 3800 MB |
| Install size | Kiri 239 MB, Docker Desktop 3226 MB |

Most numbers come from a single run, so read them as direction, not a rating. Full method, limits and recommendations are in the write-up.

- [report/writeup.md](report/writeup.md): the write-up. Start here.
- [report/report.md](report/report.md): detailed findings, one per test, with the harness corrections made along the way.
- [report/risk-register.md](report/risk-register.md): risks raised about Kiri and what the tests showed.
- [results/COMPARE.md](results/COMPARE.md): side-by-side table built from the raw results.

## Layout

```
app/                  Go test app and Dockerfile
compose/              Compose files and .env.example
tests/windows/        PowerShell test harness (run.ps1, lib/, scripts/)
tests/tools/          writeloop (acknowledged writes) and verify (data-loss check)
tests/compare.py      builds results/COMPARE.md from the raw results
env/versions.md       host, versions and image digests used
results/              raw results: results/<runtime>/<test>/{result.md,metrics.json,raw/}
report/               write-up, findings, risk register
```

## Tests

| Group | Tests |
| --- | --- |
| Compatibility | 07 compose, 08 startup order, 09 DNS, 34 build |
| Reliability | 00 happy path, 01 Postgres hard kill, 02 restart (Kiri only, no admin shell for Docker Desktop), 13 restart policy, 14 memory limit |
| Resources | 16 idle RAM, 17 stack RAM, 18 idle CPU, 19 container start, 20 stack start, 24 disk |
| Performance | 21 k6 steady load, 38 k6 ramp, 22 pgbench (5 rounds), 23 redis-benchmark |
| Security and operations | 28 engine pipe, 29 secret canary in Event Log, 31 logging |

## Run it

Prerequisites: Windows 11 with WSL2, Go, Python 3, [hyperfine](https://github.com/sharkdp/hyperfine) and [k6](https://k6.io) on `PATH`. Run **one engine at a time**: stop Docker Desktop completely before starting Kiri, and the reverse.

```powershell
docker build -t kiri-vs-docker-app:local app      # build once, then:
docker save kiri-vs-docker-app:local -o app-image.tar   # load this file into the other engine

# Docker Desktop pass
powershell -File tests\windows\run.ps1 -Runtime docker -KeepGoing

# Stop Docker Desktop, start Kiri, `docker context use kiri`, load app-image.tar, then:
$env:KVD_ENGINE_PROCESS_MATCH = 'kiri'
powershell -File tests\windows\run.ps1 -Runtime kiri -KeepGoing

python tests\compare.py                            # writes results\COMPARE.md
```

Runner flags: `-Only 7,8,9`, `-Skip 24`, `-Round 2`, `-Quick` (short run, ignored by compare), `-KeepGoing`, `-DryRun`. Overrides for process names, pipe names and paths are listed in [tests/windows/README.md](tests/windows/README.md).

The comparison rule in `compare.py` flags a difference only when the median differs by more than 10% and the min-max ranges do not overlap. You still decide whether the saving matters.

## Notes

- The test app and its env vars are described in [app/README.md](app/README.md). Credentials in the Compose files are fake.
- The tests start and remove containers, volumes and images. Run them on a machine where that is acceptable.
- The logs under `results/*/29-canary/` contain deliberately fake secrets (`CANARY-...`). They are the test input, not leaked credentials.
- Code is MIT licensed, see [LICENSE](LICENSE).
