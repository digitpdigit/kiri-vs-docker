# Kiri vs Docker Desktop — Windows evaluation report

Language: ASD-STE100 style (short sentences, one idea each, approved verbs).  
Scope: Windows developer-tool comparison only. Do not use this report as proof of Linux production readiness.  
Evidence index: `results/COMPARE.md` and `results/<runtime>/<test>/`.

---

## 1. Summary

This report recommends outcome **B: acceptable for a non-critical local-development PoC**.  
No STOP or BLOCKER failure occurred on either runtime after the harness corrections in section 10.  
Kiri starts a single container faster and uses less host RAM and CPU. Compose for this stack works on both runtimes.

Conditions for B:

1. Pin Kiri 0.2.1. Do not enable auto-update during the PoC.
2. Keep external backups. Do not use this stack as the only copy of data.
3. Keep a rollback path to Docker Desktop (`docker context use desktop-linux` or reinstall).
4. Do not use the result for Linux production. Test 03 (reboot) and test 28 (unprivileged pipe) are Not tested.

---

## 2. Setup

| Item | Value |
|---|---|
| Date | 2026-11-17 |
| Host | Windows 11 Pro build 26300, Intel Core i5-13400F, 31.8 GB RAM, local workstation |
| Method | One host. Docker Desktop pass first. Then stop Docker Desktop. Then start Kiri. |
| Docker Desktop | 4.44.2, Engine 28.3.2, Compose 5.6.1, context `desktop-linux` |
| Kiri | 0.2.1, `kiri-win.exe`, WSL distro `kiri`, context `kiri`, Engine API 27.5.1 |
| App | `kiri-vs-docker-app:local`, Go 1.25.0, Postgres 16, Redis 7 |
| Load | On the same host (`load_on_host=1`) |
| Versions file | `env/versions.md` |

**Limitation (image ID).** Docker Desktop `inspect` gave manifest-list ID `sha256:4dcea8f…`. After `docker load -i app-image.tar` on Kiri, `inspect` gave config ID `sha256:f8635dcd…`. The tar is the same file. The IDs are not the same string. `compare.sh` warns. This report still uses the numbers. Label: **Unknown** whether the two IDs name one image.

The two engines did not run at the same time during measurement.

---

## 3. Results

Use the latest recorded PASS or FAIL for each ID. Early FAIL rows from harness defects are not evidence.

### A. Compatibility

| ID | Docker Desktop | Kiri | Label |
|---|---|---|---|
| 07 Compose up/down/logs/exec | PASS | PASS | Verified |
| 08 healthcheck / `depends_on` | PASS | PASS | Verified |
| 09 service DNS | PASS | PASS | Verified |
| 34 image build | PASS | PASS | Verified |
| 10, 11, 32, 36 | — | — | Not tested |

Prose: The Compose file started the app, Postgres, and Redis on both runtimes. The app waited for healthy dependencies. Name `postgres` and name `redis` resolved. `docker build` of the app image completed.

### B. Resource usage

| ID | Metric | Docker Desktop | Kiri | Rule (section 7) |
|---|---|---|---|---|
| 16 | Engine idle Working Set (host processes) | 794.1 MB | 47.2 MB | candidate (94% delta, no range overlap) |
| 16 | `vmmem` (WSL2 VM RAM), idle | 1633 MB | 907.6 MB | candidate (44% delta) |
| 17 | Engine Working Set with stack | 741.6 MB | 40.8 MB | candidate |
| 17 | `vmmem` with stack | 1730 MB | 957 MB | candidate (45% delta) |
| 18 | Idle CPU, 180 s mean, % of one core | 11.56 | 1.38 | candidate (88% delta) |
| 24 | Engine disk files, empty / stack up / after build | 1464 / 2360 / 3800 MB | 108 / 972 / 2796 MB | see F-12 (clean-to-clean, one run) |
| 38 | Max VUs with p95 < 100 ms and fail < 1% | 200 | 400 | see F-13; throughput about 15k req/s on both |
| 19 | `docker run --rm alpine true` median | 514.5 ms | 117.7 ms | candidate (77% delta, no range overlap) |
| 20 | Stack start until healthy, median | 13560 ms | 12259 ms | no meaningful difference |
| 21 | k6 p50 / p95 | 1.0 ms / 2.6 ms | 0.5 ms / 1.7 ms | candidate; absolute values are small |
| 22 | pgbench read / write tps (median of 5) | 62713.8 / 1714.4 | 63126.3 / 1720.5 | no meaningful difference |
| 23 | Redis SET / GET ops/s | 161812 / 147929 | 162866 / 141243 | no meaningful difference |
| 14 | App OOM after 1024 MB alloc (limit 256M) | killed, 1 restart | killed, 1 restart | PASS both |
| 24 | Program install size | 3226 MB | 239 MB | see F-12 |

Working Set is for Windows processes whose names match `docker` or `kiri`. It does not include the WSL2 VM. Use `vmmem` for VM RAM. Do not read 47 MB as the total host cost of Kiri.

### C. Fault tolerance

| ID | Docker Desktop | Kiri | Label |
|---|---|---|---|
| 00 happy writeloop | PASS (`ACKED_BUT_MISSING=0`) | PASS (`ACKED_BUT_MISSING=0`) | Verified |
| 01 Postgres crash (`pg_ctl stop -m immediate`) + verify | PASS (0 missing, 200 rows) | PASS (0 missing, 200 rows) | Verified |
| 13 restart policy | PASS (app back in ~2 s, Postgres in ~6 s) | PASS (app ~2 s, Postgres ~6 s) | Verified |
| 02 engine restart | Not tested (no admin) | PARTIAL (no Windows service `kiri`) | Not tested / Partial |
| 03, 05, 06, 12, 15 | — | — | Not tested |

### D. Security and operations

| ID | Docker Desktop | Kiri | Label |
|---|---|---|---|
| 28 named pipe | PASS (user can connect) | PASS (user can connect) | Verified (privileged user) |
| 29 canary in Event Log | PASS (retest) | PASS | Verified |
| 31 log options | PASS | PASS | Verified |
| 26, 27, 30, 33, 35 | — | — | Not tested |

---

## 4. Findings (ASD-STE)

Each finding has: identifier, title, condition, evidence, effect, label, exclusive-to-Kiri.

### FINDING F-01 — Postgres returns and keeps all acknowledged writes after a crash

**Condition.** Postgres is crashed with `pg_ctl stop -m immediate` during a 200-write load (10 writes/s). The restart policy is `unless-stopped`.

**Evidence.** Tests 01 and 13. Results: `results/<runtime>/01-hard-kill` and `results/<runtime>/13-restart-policy`. `ACKED_BUT_MISSING=0`, `GAPS=0`, 200 rows on both. Postgres healthy again in about 6 s on both. App recovers from `/debug/panic` in about 2 s on both.

**Effect.** No durability or restart difference between the runtimes in this procedure.

**Label.** Verified. Scope: a Postgres crash, not a host power cut (test 03 Not tested).  
**Exclusive to Kiri.** No (parity).  
**Correction.** Earlier runs reported FAIL on both runtimes (40 and 45 missing). That was a harness defect. See section 10, items 1 and 2.

### FINDING F-02 — Memory limit enforced on both runtimes

**Condition.** The app service has `mem_limit` 256M. `POST /debug/alloc?mb=1024` touches every page.

**Evidence.** Test 14. Results: `results/<runtime>/14-oom`. Request connection drops. App `RestartCount=1`. Postgres and Redis keep running. Kiri reports exit code 137.

**Effect.** The limit kills the app and not the neighbors on both runtimes. Docker allows memory plus an equal amount of swap by default (512 MB here). A 400 MB test cannot show the limit.

**Label.** Verified.  
**Exclusive to Kiri.** No (parity).  
**Correction.** The earlier PARTIAL (F-03 in the first draft) came from the 400 MB value and from reading state after the restart.

### FINDING F-03 — Kiri idle CPU is lower

**Condition.** Mean CPU of engine processes over 180 s with the stack idle.

**Evidence.** Test 18. Docker Desktop 11.56% of one core. Kiri 1.38%. Method: process CPU time delta over the sample window, matching `docker` and `kiri` process names.

**Effect.** Docker Desktop costs a visible background load on a laptop. Kiri costs close to none. Does not include `vmmem` CPU, which the sampler does not attribute.

**Label.** Verified (one run).  
**Exclusive to Kiri.** The saving is on Kiri.

### FINDING F-04 — Kiri host-side process RAM is lower

**Condition.** The sum of Working Set for processes whose names match the engine is lower for Kiri than for Docker Desktop.

**Evidence.** Test 16. Docker Desktop 794 MB. Kiri 47 MB. Test 17 (with stack): 742 MB and 41 MB. `vmmem` (the WSL2 VM, the real RAM cost): idle 1633 MB and 908 MB (-44%). With stack 1730 MB and 957 MB (-45%).

**Effect.** The 94% figure is for host processes only. The real RAM saving is about 45%, or roughly 0.7 to 0.8 GB on this host. `vmmem` was read once per run.

**Label.** Verified (one run each).  
**Exclusive to Kiri.** The saving is on Kiri.

### FINDING F-05 — Single-container start is faster on Kiri

**Condition.** Median wall time for `docker run --rm alpine:latest true` is lower on Kiri.

**Evidence.** Test 19. Docker Desktop median 514.5 ms (min 458.8, max 539.6). Kiri median 117.7 ms (min 85.8, max 126.7). Delta about 77%. Ranges do not overlap.

**Effect.** A user who starts many short containers will wait less on Kiri. Test 20 (full stack to healthy) shows no meaningful difference (13.56 s vs 12.26 s).

**Label.** Verified.  
**Exclusive to Kiri.** The advantage is on Kiri.

### FINDING F-06 — App request latency is lower on Kiri in this k6 run

**Condition.** k6 p50 and p95 against `/health`, `/db`, and `/cache` are lower on Kiri.

**Evidence.** Test 21. Docker Desktop p50 1.0 ms, p95 2.6 ms. Kiri p50 0.5 ms, p95 1.7 ms. One measured run after warmup. Load was on the same host.

**Effect.** The percent delta is a candidate. The absolute times are both below 3 ms at p95. Section 7 also asks if the saving would change a decision. For this web stack, the saving is small in absolute time.

**Label.** Verified (one round).  
**Exclusive to Kiri.** The lower times are on Kiri.

### FINDING F-07 — pgbench throughput is the same on both runtimes

**Condition.** pgbench select-only and default (write) workloads, scale 10, 5 clients, 2 threads, 30 s, run inside the Postgres container. Five runs per runtime.

**Evidence.** Test 22. Read tps: Docker Desktop 62139.8 / 62235.1 / 62713.8 / 62781.0 / 63248.8 (median 62713.8). Kiri 61453.6 / 62923.8 / 63126.3 / 63402.3 / 64087.5 (median 63126.3). Write tps: Docker Desktop 1450.8 / 1709.3 / 1714.4 / 1717.3 / 1719.3 (median 1714.4). Kiri 1707.8 / 1719.6 / 1720.5 / 1721.7 / 1752.8 (median 1720.5). `compare.sh`: no meaningful difference for both.

**Effect.** Postgres throughput does not depend on the runtime in this setup.

**Label.** Verified (5 runs each).  
**Exclusive to Kiri.** No (parity).  
**Correction.** The first run reported 5858.8 / 966.7 (Docker Desktop) and 29843 / 1632.6 (Kiri), a 5x read gap. That was a harness defect. See section 10, item 5. The invalid runs are not part of the published results.

### FINDING F-08 — Redis benchmark shows no meaningful difference

**Condition.** Redis SET and GET ops/s stay in overlapping decision space.

**Evidence.** Test 23. Docker Desktop SET 161812 / GET 147929. Kiri SET 162866 / GET 141243. `compare.sh`: no meaningful difference.

**Effect.** For this Redis test, the runtime is not the limiter.

**Label.** Verified.  
**Exclusive to Kiri.** No.

### FINDING F-09 — Kiri has no Windows service for engine restart

**Condition.** Test 02 calls `Restart-Service` with name `kiri`. Windows has no service with that name.

**Evidence.** Test 02. Result PARTIAL. Observed: "Cannot find any service with service name 'kiri'". Design: Kiri Windows uses `kiri-win.exe` per user. It does not install a service (`kiri.ps1` states no service).

**Effect.** A person cannot restart Kiri with the same Service Control Manager procedure as Docker Desktop (`com.docker.service`). Test 02 is Not tested on Docker Desktop (no Administrator). Test 03 (reboot) is Not tested.

**Label.** Verified (no service). Lifecycle after reboot: Not tested.  
**Exclusive to Kiri.** Yes, for the missing service. Docker Desktop has `com.docker.service`.

### FINDING F-10 — Compose compatibility held for the tests that ran

**Condition.** Unmodified Compose up, health order, DNS, logs, and image build completed on Kiri.

**Evidence.** Tests 07, 08, 09, 31, 34. All PASS on Kiri. Hypothesis W4 predicted a gap in healthchecks or logging. This set did not show that gap.

**Effect.** For this stack, Kiri accepted the Docker workflow that the tests covered.

**Label.** Verified for IDs 07, 08, 09, 31, 34.  
**Exclusive to Kiri.** No (parity).

### FINDING F-11 — Install-size path for Kiri was wrong (fixed)

**Condition.** The first test 24 looked in `C:\Program Files\Kiri`. Kiri installs in `%LOCALAPPDATA%\Kiri`.

**Evidence.** Test 24 rewritten. It now records `images_gb`, `volumes_gb`, `cache_gb`, `install_mb`, `vhdx_mb`.

**Label.** Fixed.

### FINDING F-12 — Disk use, clean engine to clean engine

**Condition.** The first test 24 ran on a Docker Desktop host that held 18 GB of images and 7.8 GB of build cache from other work. That run is invalid for comparison (its raw numbers: Docker VHDX 20.8 GB, install 24.1 GB; Kiri VHDX 4.1 GB). It was repeated after both engines were reset to empty.

**Method.** Docker Desktop: volumes backed up, then WSL distro `docker-desktop` unregistered and `docker_data.vhdx` deleted. Docker Desktop re-created both (0 images, 0 volumes, 0 cache). Kiri: all test objects removed, Kiri restarted (frees layer storage), distro exported and re-imported so the VHDX is sized to content (76 MB). Stages: S0 empty; S1 after `docker load` of the app image plus stack up (Postgres and Redis pulled); S2 after test 34 (image build). Metric: total size of the WSL VHDX files under `%LOCALAPPDATA%\Docker\wsl` and `%LOCALAPPDATA%\Kiri\wsl`. Raw data: `results/<runtime>/24-disk/raw/disk-clean-stages.txt`.

**Evidence.**

| Stage | Docker Desktop | Kiri |
|---|---|---|
| S0 empty | 1464 MB | 108 MB |
| S1 stack up | 2360 MB | 972 MB |
| S2 after build | 3800 MB | 2796 MB |
| Program install | 3226 MB (+97 MB user data) | 239 MB |

`docker system df` at S1: Docker 850 MB images, 48 MB volumes. Kiri 635 MB images, 48 MB volumes. At S2 Docker shows 1.463 GB build cache; Kiri shows 0 cache and a 1.47 GB buildkit state volume. The df image sizes are not comparable (postgres:16: Docker 661 MB, Kiri 166 MB).

**Cause of Docker Desktop's fixed overhead.** Inside the engine VM (read-only look through a privileged container with `nsenter`), the data disk `/dev/sdh` held `/mnt/docker-desktop-disk/isocache/entries/docker-desktop.iso` (678,076,416 bytes) and `docker-wsl-cli.iso` (626,036,736 bytes): 1,304,113,152 bytes, 1,244 MiB, at the empty-engine disk size of 1,324 MB. `data/desktop-containerd` (2,221 MiB at S2) is the containerd image store (images and cache). Docker Desktop 4.44.2 uses the containerd image store. These ISOs are not images, volumes or cache, so `docker system df` shows 0 B and prune does not touch them. User reports (docker/desktop-feedback #375, Docker forum) say old ISO copies pile up after each update at about 1.5 GB per update; one report says 4.76 fixed the retention. Not reproduced here: the install was freshly reset, one copy of each.

**Effect.** After the full workflow Kiri's engine disk is about 26% smaller; with the program, about 3.0 GB against 7.1 GB. The gap is mostly fixed overhead. Growth S0 to S1: Docker +896 MB, Kiri +864 MB. Growth S1 to S2: Docker +1440 MB, Kiri +1824 MB. VHDX sizes are high-water marks. One run each. The two engines were emptied by different procedures.

**Label.** Verified (one run each).  
**Exclusive to Kiri.** The smaller footprint is on Kiri.

### FINDING F-15 — Kiri frees layer storage on restart, not on prune

**Condition.** After `docker system prune -a --volumes -f`, `docker volume prune -a -f` and `docker image prune -a -f`, `docker image ls` was empty. `docker system df` still showed 1.788 GB images, 100% reclaimable. `/var/lib/kiri/layers` held 96 directories (1.7 GB).

**Evidence.** Seen in the Kiri pass. After restarting `kiri-win.exe` and the `kiri` distro: 0 layers, `docker system df` 0 B. Output not saved to `results/`.

**Effect.** Disk is not returned until Kiri restarts. Data is not lost.

**Label.** Observed.  
**Exclusive to Kiri.** Yes.

### FINDING F-16 — A host port conflict kills the app container with no message on Kiri

**Condition.** Docker Desktop's stack held host port 8080 while the same stack started on Kiri.

**Evidence.** Kiri `kvd-app-1`: exit 137, start to finish 40 ms, `RestartCount=10`, no log output. Postgres and Redis (no published ports) ran fine. Freed port 8080: the app started and was healthy.

**Effect.** The cause is not visible from the container. Cause inferred from the port holder, not confirmed in Kiri's logs. Not compared with Docker Desktop's message in the same situation.

**Label.** Observed.  
**Exclusive to Kiri.** Not compared.

### FINDING F-14 — Kiri `compose up` can fail with a DNS bind error

**Condition.** On Kiri, `docker compose up` failed with `dns: dns bind: Address in use (os error 98)` after earlier stacks had been started and removed.

**Evidence.** Seen during the Kiri pass. The error text was not saved in `results/`; the count is not recorded. Recovery was a restart of `kiri-win.exe` and `wsl --terminate kiri`. `Kvd-Up` now retries up to 5 times.

**Effect.** A user can see a failed start that works on retry. Cause not investigated. Not seen on Docker Desktop.

**Label.** Observed (not Verified). Report it to the Kiri project with a reproduction before relying on Kiri for repeated up/down cycles.  
**Exclusive to Kiri.** Yes, in this run.

### FINDING F-13 — Both engines reach about 15k req/s; Kiri holds 400 VUs, Docker Desktop does not

**Condition.** k6 ramp on `GET /health`, VUs 10 to 400, load generator on the same host. Stable = p95 < 100 ms and fail < 1%.

**Evidence.** Test 38. Docker Desktop: p95 2.1 / 4.1 / 6.9 / 13.1 / 29.0 / 68.8 ms at 10/25/50/100/200/400 VUs; peak 15.4k req/s at 100 VUs; 2.1% failures at 400 VUs. Kiri: p95 1.3 / 4.0 / 12.2 / 25.5 / 48.2 / 66.5 ms; 13.9k to 15.2k req/s; 0.03% failures at 400 VUs.

**Effect.** Same throughput ceiling. Docker Desktop has lower latency at 50 to 200 VUs. Docker Desktop crosses the 1% failure line at 400 VUs; Kiri does not. The shared host (k6 and engine compete for CPU) limits the result. One run each.

**Label.** Verified (one run). Inconclusive for a ranking.

---

## 5. Hypotheses (Windows, W1–W7)

| ID | Statement | Result |
|---|---|---|
| W1 | Kiri is faster for container start | **Confirmed** for test 19. **Rejected** as a stack-start claim (test 20: no meaningful difference). |
| W2 | Kiri idle RAM is lower on the host process list | **Confirmed** for Working Set (tests 16, 17). Scope: host processes, not WSL2 VM. |
| W3 | App latency and throughput: no meaningful difference | **Rejected** for k6 percent rule (test 21). **Inconclusive** for decision size (absolute ms is small). Tests 22 (5 runs) and 23 confirm W3 for Postgres and Redis. |
| W4 | Compose works, but a gap occurs in healthchecks or logging | **Rejected** for tests 08 and 31. |
| W5 | Durability parity with Docker Desktop | **Confirmed** for a Postgres crash: both PASS 00 and 01 (0 missing), both PASS 13. Host power cut: Not tested. |
| W6 | Reboot recovery is worse on Kiri | **Inconclusive.** Test 03 Not tested. Test 02 shows no Kiri service. |
| W7 | Named-pipe access for an unprivileged user | **Inconclusive.** Test 28 ran as a privileged user on both. |

Linux hypotheses H1–H7: **Not tested** (this host is Windows).

---

## 6. Risk register (summary)

Full table: `report/risk-register.md`.

On Windows both tools use a VM. Risks about Linux isolation without a VM **do not apply** to this evaluation and are not in the register.

Observed on Windows:

- R3 (lifecycle): Verified in part (no Windows service). Reboot Not tested.
- R4 (feature gaps): Not observed in tests 08 and 31.
- R6 (storage path): Test 01 passes on both after correction (0 acknowledged writes lost).
- R1 (secrets in reports): Canary not found in Windows Event Log (test 29). Label: Not observed in Event Log.

---

## 7. Why Docker Desktop (if a person keeps it)

Docker Desktop has a Windows service. Many tools default to context `desktop-linux`. The install layout is documented. Docker has a long public history. That history includes isolation defects. This report does not claim Docker Desktop is free of faults. No test in this set failed on Docker Desktop after correction.

Keep Docker Desktop if the project needs the service, the default context, or a vendor support path that this PoC did not test.

---

## 8. What Kiri does well

1. Test 19: container start median 117.7 ms vs 514.5 ms.
2. Tests 07, 08, 09, 31, 34: this Compose stack works.
3. Test 16: fewer host-side engine processes in Working Set.
4. Tests 00 and 01: zero acknowledged writes lost, also after a Postgres crash.
5. Tests 16, 17, 18: `vmmem` about 45% lower, idle CPU 1.4% against 11.6% of one core.

---

## 9. Limitations

Not tested: 03, 04, 05, 06, 10, 11, 12, 15, 25, 26, 27, 30, 32, 33, 35, 36.  
Not tested: unprivileged pipe access, reboot, five-run performance protocol (only test 22 has five runs), repeated disk runs, Linux production host.  
Harness notes: see section 10.

Do not cite these Windows numbers as Linux production evidence.

---

## 10. Appendix

### Harness defects found and fixed

1. `docker kill` counts as a manual stop. The restart policy ignores it ([Docker docs](https://docs.docker.com/engine/containers/start-containers-automatically)). Tests 01 and 13 now crash Postgres with `pg_ctl stop -m immediate`.
2. `Kvd-WaitHealthy -AllowFail` leaked the `compose ps` table into its return value, so `-not $ok` was false. Test 01 then dumped rows from a dead database and counted every acknowledged write as missing (40 and 45 equal the number of writes acknowledged before the kill). `Kvd-Psql` now throws on a non-zero exit.
3. Test 14 used 400 MB. With `mem_limit` 256M and no `memswap_limit`, Docker allows 512 MB total ([Docker docs](https://docs.docker.com/engine/containers/resource_constraints/)). It now uses 1024 MB and reads `RestartCount`.
4. Earlier runs 00, 07, 29 and the first test 24 had script defects. Use the later runs.
5. Test 22 passed `-d appdb` to pgbench. In pgbench `-d` means debug, not database name. Every protocol message was printed (76 to 270 MB of text per run) and captured through the PowerShell pipeline, so tps measured output handling. The script now passes the database as a positional argument. Output is under 1 KB. The old runs are not part of the published results.

### Outcome rule used

Section 10 rule 1: no STOP on Kiri only. Rule 2: no BLOCKER on Kiri only without workaround. Rule 3: some resource gains are candidates (19, 16). Rule 4: outcome **B** for local development, not production.

### Version table

See `env/versions.md`.

### Result index

See `results/COMPARE.md` directory list.
