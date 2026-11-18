# COMPARE

Human decides outcome A / B / C. This file does not.

Note: the two engines report different IDs for the same app image (saved from one, loaded into the other). One ID per runtime is expected:

- docker: `sha256:4dcea8f45ad8f792cda82f75e6d67fb05f7b96d7291e939e36e9f843d5058df3`
- kiri: `sha256:f8635dcd4674750210a1e8a8e0c26c0c4293795adff8f0b8a60b924b063b8888`

## STOP / BLOCKER

No STOP-only-on-Kiri failures in this tree.

No BLOCKER-only-on-Kiri failures in this tree.

## A. Compatibility

| ID | Docker | Kiri | Perf rule |
|---|---|---|---|
| 07 | PASS | PASS | — |
| 08 | PASS | PASS | — |
| 09 | PASS | PASS | — |
| 34 | PASS | PASS | — |

## B. Resource usage

| ID | Docker | Kiri | Perf rule |
|---|---|---|---|
| 14 | PASS | PASS | app_oom_killed: no meaningful difference; app_restarts: no meaningful difference; postgres_survived: no meaningful difference; redis_survived: no meaningful difference |
| 16 | PASS | PASS | ram_mb: candidate (94.1% median delta, ranges do not overlap; still needs decision-size judgement); vhdx_mb: candidate (80.3% median delta, ranges do not overlap; still needs decision-size judgement); vmmem_mb: candidate (44.4% median delta, ranges do not overlap; still needs decision-size judgement) |
| 17 | PASS | PASS | engine_after_mb: candidate (94.5% median delta, ranges do not overlap; still needs decision-size judgement); engine_before_mb: candidate (94.5% median delta, ranges do not overlap; still needs decision-size judgement); engine_delta_mb: candidate (100.0% median delta, ranges do not overlap; still needs decision-size judgement); host_free_delta_mb: candidate (187.0% median delta, ranges do not overlap; still needs decision-size judgement); vhdx_mb: candidate (80.2% median delta, ranges do not overlap; still needs decision-size judgement); vmmem_mb: candidate (44.7% median delta, ranges do not overlap; still needs decision-size judgement) |
| 18 | PASS | PASS | cpu_one_core_pct: candidate (88.1% median delta, ranges do not overlap; still needs decision-size judgement); sample_s: no meaningful difference |
| 19 | PASS | PASS | max_ms: candidate (76.5% median delta, ranges do not overlap; still needs decision-size judgement); median_ms: candidate (77.1% median delta, ranges do not overlap; still needs decision-size judgement); min_ms: candidate (81.3% median delta, ranges do not overlap; still needs decision-size judgement) |
| 20 | PASS | PASS | max_ms: no meaningful difference; median_ms: no meaningful difference; min_ms: no meaningful difference |
| 21 | PASS | PASS | p50_ms: candidate (50.0% median delta, ranges do not overlap; still needs decision-size judgement); p95_ms: candidate (34.6% median delta, ranges do not overlap; still needs decision-size judgement) |
| 22 | PASS | PASS | read_tps: no meaningful difference; write_tps: no meaningful difference |
| 23 | PASS | PASS | get_ops_per_sec: no meaningful difference; set_ops_per_sec: no meaningful difference |
| 24 | PASS | PASS | cache_gb: no meaningful difference; images_gb: candidate (25.3% median delta, ranges do not overlap; still needs decision-size judgement); install_mb: candidate (78.7% median delta, ranges do not overlap; still needs decision-size judgement); vhdx_mb: candidate (58.8% median delta, ranges do not overlap; still needs decision-size judgement); volumes_gb: no meaningful difference |
| 38 | PASS | PASS | max_stable_rps: no meaningful difference; max_stable_vus: candidate (100.0% median delta, ranges do not overlap; still needs decision-size judgement); p95_at_max_ms: candidate (129.3% median delta, ranges do not overlap; still needs decision-size judgement) |

## C. Fault tolerance

| ID | Docker | Kiri | Perf rule |
|---|---|---|---|
| 00 | PASS | PASS | acked_but_missing: no meaningful difference |
| 01 | PASS | PASS | acked_but_missing: no meaningful difference |
| 02 | — | PARTIAL | — |
| 13 | PASS | PASS | app_recovered: no meaningful difference; postgres_recovered: no meaningful difference |

## D. Security and operations

| ID | Docker | Kiri | Perf rule |
|---|---|---|---|
| 28 | PASS | PASS | can_connect: no meaningful difference |
| 29 | PASS | PASS | — |
| 31 | PASS | PASS | — |

## Directories

- `docker/00-happy-writeloop` test=00 runtime=docker result=PASS
- `docker/01-hard-kill` test=01 runtime=docker result=PASS
- `docker/07-compose` test=07 runtime=docker result=PASS
- `docker/08-startup-order` test=08 runtime=docker result=PASS
- `docker/09-dns` test=09 runtime=docker result=PASS
- `docker/13-restart-policy` test=13 runtime=docker result=PASS
- `docker/14-oom` test=14 runtime=docker result=PASS
- `docker/16-idle-ram` test=16 runtime=docker result=PASS
- `docker/17-stack-ram` test=17 runtime=docker result=PASS
- `docker/18-idle-cpu` test=18 runtime=docker result=PASS
- `docker/19-alpine-start` test=19 runtime=docker result=PASS
- `docker/20-stack-start` test=20 runtime=docker result=PASS
- `docker/21-k6` test=21 runtime=docker result=PASS
- `docker/22-pgbench` test=22 runtime=docker result=PASS
- `docker/22-pgbench-r2` test=22 runtime=docker result=PASS
- `docker/22-pgbench-r3` test=22 runtime=docker result=PASS
- `docker/22-pgbench-r4` test=22 runtime=docker result=PASS
- `docker/22-pgbench-r5` test=22 runtime=docker result=PASS
- `docker/23-redisbench` test=23 runtime=docker result=PASS
- `docker/24-disk` test=24 runtime=docker result=PASS
- `docker/28-pipe` test=28 runtime=docker result=PASS
- `docker/29-canary` test=29 runtime=docker result=PASS
- `docker/31-logging` test=31 runtime=docker result=PASS
- `docker/34-build` test=34 runtime=docker result=PASS
- `docker/38-k6-ramp` test=38 runtime=docker result=PASS
- `kiri/00-happy-writeloop` test=00 runtime=kiri result=PASS
- `kiri/01-hard-kill` test=01 runtime=kiri result=PASS
- `kiri/02-restart-upgrade` test=02 runtime=kiri result=PARTIAL
- `kiri/07-compose` test=07 runtime=kiri result=PASS
- `kiri/08-startup-order` test=08 runtime=kiri result=PASS
- `kiri/09-dns` test=09 runtime=kiri result=PASS
- `kiri/13-restart-policy` test=13 runtime=kiri result=PASS
- `kiri/14-oom` test=14 runtime=kiri result=PASS
- `kiri/16-idle-ram` test=16 runtime=kiri result=PASS
- `kiri/17-stack-ram` test=17 runtime=kiri result=PASS
- `kiri/18-idle-cpu` test=18 runtime=kiri result=PASS
- `kiri/19-alpine-start` test=19 runtime=kiri result=PASS
- `kiri/20-stack-start` test=20 runtime=kiri result=PASS
- `kiri/21-k6` test=21 runtime=kiri result=PASS
- `kiri/22-pgbench` test=22 runtime=kiri result=PASS
- `kiri/22-pgbench-r2` test=22 runtime=kiri result=PASS
- `kiri/22-pgbench-r3` test=22 runtime=kiri result=PASS
- `kiri/22-pgbench-r4` test=22 runtime=kiri result=PASS
- `kiri/22-pgbench-r5` test=22 runtime=kiri result=PASS
- `kiri/23-redisbench` test=23 runtime=kiri result=PASS
- `kiri/24-disk` test=24 runtime=kiri result=PASS
- `kiri/28-pipe` test=28 runtime=kiri result=PASS
- `kiri/29-canary` test=29 runtime=kiri result=PASS
- `kiri/31-logging` test=31 runtime=kiri result=PASS
- `kiri/34-build` test=34 runtime=kiri result=PASS
- `kiri/38-k6-ramp` test=38 runtime=kiri result=PASS
