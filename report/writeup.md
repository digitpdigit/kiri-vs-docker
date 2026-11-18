# Kiri vs Docker Desktop on Windows: what we tested and what it means

Date: 2026-11-17. Host: one Windows 11 PC (Intel i5-13400F, 31.8 GB RAM). Docker Desktop 4.44.2 (Engine 28.3.2) against Kiri 0.2.1 (Engine API 27.5.1).

---

## 1. Why we ran the test

Kiri is a young container runtime written in Rust. It serves the Docker Engine API, so the normal `docker` CLI, Compose and buildx work against it [1][2]. Its pitch is that it is lighter and faster than Docker Desktop. We wanted to know if that holds up on a real stack, and whether the lighter footprint costs anything in reliability.

The stack is a small Go web app, Postgres 16 and Redis 7, started with one Compose file. It is not a big system, but it uses what a normal dev setup uses: health checks, `depends_on`, service DNS, volumes, restart policies, memory limits and an image build.

We also had a narrower question from the start: is a Windows-only comparison worth anything? Our answer: yes for "which tool do I want on my laptop", no for "what should I run on a Linux server". On Windows both tools run their engine in a WSL2 virtual machine [3][4]. The Linux mode without a VM, which is Kiri's main idea [2], is not exercised here. That shaped everything below.

## 2. How we ran it

- **One host, one engine at a time.** Docker Desktop first, then it was stopped and Kiri was started. The two never ran together during a measurement.
- **Same inputs.** One Compose file and one app image. We saved the image from Docker Desktop and loaded it into Kiri. The two engines report different image IDs for it (manifest list vs config digest), so we cannot prove the images are identical from the IDs alone.
- **Automated tests.** Each test is a script that starts from a clean stack, runs the check, and records its raw output and metrics.
- **Tools.** `hyperfine` for start times, `k6` for HTTP load, `pgbench` and `redis-benchmark` for the databases, Windows process counters for CPU and RAM.
- **Durability test.** A write loop posts 200 rows at 10 per second. Halfway through, Postgres is crashed with `pg_ctl stop -m immediate`, which skips the shutdown checkpoint and forces WAL recovery on restart [5]. We did not use `docker kill`, because Docker treats that as a manual stop and the restart policy then does nothing [6]. Afterwards we compare the rows the app acknowledged (HTTP 201) with the rows in the database. Any acknowledged row that is missing is a failure.
- **Memory-limit test.** The app has a 256 MB limit. We allocate 1 GB and touch every page. We use 1 GB because with `--memory` set and no `--memory-swap`, Docker allows memory plus an equal amount of swap, so 512 MB in total [7].
- **Disk test.** Both engines were first reset to empty: Docker Desktop with a full reset of its engine, Kiri by removing everything and re-creating its WSL disk file. Then we measured the size of the engine's disk files on Windows at three points: empty, after loading the app image and starting the stack, and after building the app image from source. We also measured the size of each installed program.
- **Decision rule.** We only called a difference meaningful when it was above 10% on the median, the min-max ranges did not overlap, and the saving was big enough to matter to a person. Most performance numbers come from a single run.

## 3. What the test covers, and what it does not

**Covers**

- Compose workflows: up, down, logs, exec, health order, DNS by service name, `docker build`.
- Start time of one container and of the whole stack.
- Idle and loaded RAM and CPU on the Windows host, including the WSL2 VM.
- Disk use from an empty engine: after loading the images, with the stack running, and after a full image build.
- HTTP latency and throughput up to 400 concurrent users, Postgres and Redis benchmarks.
- Postgres crash recovery with a no-lost-write check, restart policies, and a memory limit being enforced.
- Basic security checks: who can open the engine pipe, and whether a planted secret leaks into the Windows Event Log.

**Does not cover**

- **Linux production.** Not tested at all. Kiri's native Linux mode runs without a VM [2], and we never ran it.
- **Host power loss and reboot.** Our crash test kills Postgres, not the machine. We did not test recovery after a reboot.
- **Unprivileged access to the engine pipe.** We ran as the same privileged user for both engines.
- **Engine restart as an admin task.** Kiri has no Windows service to restart [4]. We did not try Docker Desktop's service (no admin shell).
- **Disk over time.** One build and one run. We did not watch disk use grow over days or across updates, or how well either engine gives space back.
- **Statistical confidence.** One run for most numbers. Treat them as direction, not rating.
- **Load realism.** `k6` ran on the same PC as the engine, so they competed for CPU.
- **Other workloads.** One small web stack. No GPU, bind-mount-heavy, Kubernetes or multi-arch work.

## 4. How the test went

Docker Desktop ran first and the stack came up cleanly. Kiri was installed per user from its Windows installer with no admin prompt, and its Docker context appeared next to Docker Desktop's. Switching between them was a matter of stopping one and starting the other.

- **Compatibility was uneventful.** The unmodified Compose file, the health-check ordering, service DNS, log options and image build all worked on Kiri the first time they were tried.
- **The app image is distroless.** It has no shell, so a few checks (DNS lookup, user inspection) ran from the Postgres container or through `docker inspect` instead.
- **One start problem on Kiri.** `docker compose up` failed at least once with `dns bind: Address in use` after several stacks had been started and removed. Restarting Kiri and its WSL distro cleared it, and the script retried up to five times after that. We did not save the error text or count how often it happened. This is an observation, not a measured rate.
- **Restart behavior differs from what you might expect.** After the memory-limit test the app was already running again when we looked, because the restart policy had brought it back. The restart count, not the current state, shows the kill.
- **Kiri frees image layers on restart, not on prune.** After `docker image prune -a`, Kiri still held 96 layer directories (1.7 GB) and `docker system df` listed them as reclaimable. They were gone after restarting Kiri. Nothing is lost, but disk does not come back right away.
- **A port conflict looks like a crash on Kiri.** With another engine still holding host port 8080, the app container on Kiri was killed within milliseconds, exit code 137, with no log output, and then restarted in a loop. Free the port and it starts. The message does not say why.
- **Some things were skipped.** Reboot recovery, an unprivileged pipe user, and Docker Desktop's service restart needed a manual step or an admin shell. We did not do them.

## 5. Results

**Compatibility and reliability: no difference found.**

| Test | Docker Desktop | Kiri |
|---|---|---|
| Compose up/down/logs/exec, health order, DNS, image build | pass | pass |
| 200 writes, none lost (no failure injected) | 0 missing | 0 missing |
| Postgres crash during writes, then verify | 0 missing, 200 rows | 0 missing, 200 rows |
| Restart policy: app panic / Postgres crash | back in ~2 s / ~6 s | back in ~2 s / ~6 s |
| 1 GB allocation against a 256 MB limit | app killed, restarted once | app killed, restarted once |
| Secret in Windows Event Log | none | none |

**Resources: Kiri is lighter.**

| Metric | Docker Desktop | Kiri |
|---|---|---|
| Idle CPU, 180 s mean (% of one core) | 11.6 | 1.4 |
| RAM of the WSL2 VM (`vmmem`), idle | 1633 MB | 908 MB |
| RAM of the WSL2 VM, stack running | 1730 MB | 957 MB |
| Engine process RAM on Windows, idle | 794 MB | 47 MB |

The last row looks dramatic (-94%), but it leaves out the VM. The VM figure is the honest RAM cost: about 45% lower, roughly 0.7 to 0.8 GB on this PC. `vmmem` is how Windows shows the WSL2 VM. WSL caps it at 50% of host RAM unless `.wslconfig` says otherwise [8]. This PC has no `.wslconfig`, so neither VM was capped.

**Speed: Kiri starts containers faster. The stack itself is not faster.**

| Metric | Docker Desktop | Kiri |
|---|---|---|
| `docker run --rm alpine true`, median | 514 ms | 118 ms |
| Compose stack to healthy, median | 13.6 s | 12.3 s (no meaningful difference) |
| k6 mixed `/health`, `/db`, `/cache`, p50 / p95 | 1.0 / 2.6 ms | 0.5 / 1.7 ms |
| Redis SET / GET ops/s | 161,812 / 147,929 | 162,866 / 141,243 (no difference) |
| pgbench read / write tps, median of 5 runs | 62,714 / 1,714 | 63,126 / 1,721 (no difference) |

pgbench ran five times per engine (scale 10, 5 clients, 30 s each, run inside the Postgres container). Read tps ranged 62.1k to 63.2k on Docker Desktop and 61.5k to 64.1k on Kiri. Write tps was 1.71k to 1.72k on both, apart from one 1.45k run on Docker Desktop. The two engines overlap completely, so Postgres throughput is the same on both. The Postgres container does the work either way.

**Maximum load (k6 ramp on `GET /health`; stable means p95 under 100 ms and under 1% errors):**

| Virtual users | Docker Desktop p95 | Kiri p95 |
|---|---|---|
| 10 | 2.1 ms | 1.3 ms |
| 50 | 6.9 ms | 12.2 ms |
| 100 | 13.1 ms | 25.5 ms |
| 200 | 29.0 ms | 48.2 ms |
| 400 | 68.8 ms, 2.1% errors | 66.5 ms, 0.03% errors |

Both top out near 15,000 requests per second. Docker Desktop has lower latency in the middle of the range. At 400 users Docker Desktop crosses the 1% error line and Kiri does not. With the load generator on the same host, the ceiling is probably partly the PC, not the engines.

**Disk: Kiri uses less, mostly because it starts smaller.** We first reset both engines to empty. Then we measured the space each one takes on Windows: the size of its WSL2 disk files, and of the installed program. Three points in the workload:

| | Docker Desktop | Kiri | Difference |
|---|---|---|---|
| Engine disk, empty | 1,464 MB | 108 MB | -1,356 MB |
| Engine disk, app image loaded and stack running (Postgres and Redis pulled) | 2,360 MB | 972 MB | -1,388 MB |
| Engine disk, after building the app image from source (Go toolchain, build cache) | 3,800 MB | 2,796 MB | -1,004 MB |
| Program install | 3,226 MB | 239 MB | -2,987 MB |
| **Total after the build, program plus engine disk** | **7,123 MB** | **3,035 MB** | **-4,088 MB (-57%)** |

Docker Desktop's total includes 97 MB of its user data folder.

How to read it:

- **The saving is what Kiri does not have at rest.** The gap is about 1.4 GB when the engines are empty and when the stack runs. So storing the same images and volumes costs about the same on both. Docker Desktop grew 896 MB from empty to running stack, and Kiri 864 MB.
- **Docker Desktop's fixed 1.3 GB is its own system images.** We looked inside its engine VM. On the data disk, a folder called `isocache` holds two files: `docker-desktop.iso` (678 MB) and `docker-wsl-cli.iso` (626 MB), 1,304 MB together [15]. That matches the empty engine's 1.3 GB. They are not images, containers, volumes or build cache, so `docker system df` shows 0 B for them and `docker system prune` cannot remove them.
- **That cost may grow on a machine that gets updated.** Users report that older copies of these two files stay behind after each Docker Desktop update, adding about 1.5 GB per update, and one report says version 4.76 fixed the retention [15][16]. We saw one copy of each on this freshly reset 4.44.2 install, so we did not see the growth ourselves.
- **The build narrows the gap to 1.0 GB.** Kiri grew more during the build (+1,824 MB against +1,440 MB). Its build cache sits in a 1.47 GB volume owned by its builder container, while Docker Desktop reports its cache as 1.46 GB under "Build Cache".
- **The program itself is 92% smaller.** 239 MB against 3.2 GB.

What limits these numbers:

- They are file sizes, so they only show the high-water mark. When we tried to turn on sparse disk files for Kiri's WSL distro, WSL refused and warned of possible data corruption, so we expect these files not to shrink by themselves after a cleanup. We did not try this on Docker Desktop's distro.
- Kiri also returns freed image layers only after a restart (section 4), so after a prune its disk use can look higher than it needs to be for a while.
- The sizes that `docker system df` reports cannot be compared across the two. The same Postgres image shows as 661 MB on Docker Desktop and 166 MB on Kiri.
- One run each. The two engines were emptied by different procedures (a full reset for Docker Desktop, a removal plus a fresh WSL disk file for Kiri), so the first row compares the products as they start, not an identical disk.

## 6. What we take from it

1. **Kiri's real win on Windows is background cost.** About 0.7 GB less RAM and about 10 points less CPU of one core while idle. That is what a laptop user notices.
2. **Kiri also costs less disk on Windows, again in fixed overhead.** About 3.0 GB for Kiri against 7.1 GB for Docker Desktop, program plus engine disk, after the same workload. The program alone is 239 MB against 3.2 GB. Docker Desktop's engine disk starts with 1.3 GB of its own system images that no `docker` command shows or removes. What the workload adds is about the same on both, and a build adds a little more on Kiri.
3. **Single-container start is faster on Kiri, full-stack start is not.** In Compose work the time goes to Postgres and the app becoming healthy, not to the runtime.
4. **For HTTP, Redis and Postgres workloads the engine is not the limiter.** Throughput matches. Latency differences are a few milliseconds, and which engine is ahead depends on the load level.
5. **Resilience tests need care with Docker's own rules.** `docker kill` and `docker stop` count as manual stops and disable the restart policy, so a restart test has to crash the process from inside [6]. A memory limit with no swap setting is really twice the number you wrote [7]. Both apply to any runtime that follows the Docker API.
6. **Kiri on Windows is beta.** Its docs say so, and the installers are not code-signed [4]. We saw one start failure that needed a restart to clear.
7. **Kiri has no Windows service.** It starts when you sign in, per user, no admin [4]. That suits a laptop and is a gap if you expect a managed service.
8. **The VM is the same on both.** Kiri's main selling point on Linux, no VM and no `dockerd`, `containerd` or `runc` [2], only partly applies here. Kiri still runs without those components inside its WSL distro, which is probably where the CPU and RAM saving comes from. We did not prove that.

## 7. Recommendation for production use

Short version: **do not make a production decision from this test.**

- **Kiri on a production Linux server: not supported by our evidence.** We never ran it. Its Linux mode is a different configuration from the one we tested [2]. To consider it, repeat the tests on a Linux host with the same Compose file, several runs per measurement, a power-cut test and a reboot test.
- **Kiri on Windows for a developer laptop: reasonable to try.** It passed every compatibility and reliability test we ran, and it is lighter. Conditions: pin version 0.2.1, turn off auto-update while you evaluate, keep backups of anything in its volumes, and keep Docker Desktop installed so you can switch back with `docker context use desktop-linux`. Expect rough edges while it is in beta.
- **Docker Desktop as a production runtime: not what we tested, and not what Docker's server docs describe.** Their Linux install guide uses Docker Engine from the distribution's package repository and says the convenience script is not for production [9][10]. Desktop is aimed at Windows and Mac workstations.
- **Docker Desktop on developer machines: check the license.** It is free for personal use, education, open source, and companies under 250 employees and under US$10 million revenue. Larger companies need a paid subscription [11][12].
- **Windows servers:** if the target is Linux containers on Windows servers, neither tool is what we tested. Use a supported server configuration and test it directly.

The safest next step is to rerun the same tests on a Linux host, with Docker Engine against Kiri's native Linux mode. That is the comparison that matches how either would be used in production. Section 8 describes it.

## 8. What's next

Run the same tests on Linux. Same stack, same Compose file, same decision rule, on one Linux host with one engine at a time. Three setups:

1. **Docker Engine**, installed from Docker's package repository [9][10]. It runs on the host kernel with no VM. This is the production baseline.
2. **Kiri on Linux**, installed as a `.deb` or `.rpm` with its systemd service. Its agent runs as an ordinary root process beside the daemon, on the host kernel, with no VM [2].
3. **Docker Desktop for Linux**, optional. It is not a server product, but it is the closest match to what we tested on Windows.

**A correction to a tempting assumption.** It is easy to say that on Linux neither tool uses a VM, so the engine will not matter. That is only half true. Docker Desktop for Linux still runs its engine in a VM, using KVM and QEMU, and Docker says so openly, citing a consistent experience across platforms, kernel control and security [13][14]. Only Docker Engine and Kiri run without a VM on Linux.

**Hypotheses.** We have not tested these.

- **H1: Kiri against Docker Engine will show small differences.** Both run on the host kernel, and neither pays the VM tax that dominated our Windows RAM and CPU gap. We expect Compose compatibility, crash recovery, restart behavior, memory-limit enforcement and Postgres, Redis and HTTP throughput to match within noise. The two places we expect a gap are container start time and the idle footprint of the daemons. Kiri's own numbers (about 2.5 ms per container, a daemon of about 15 MB) are mostly measured against Docker Desktop [2], so they say little about Docker Engine.
- **H2: Kiri against Docker Desktop for Linux will show larger differences than on Windows**, in Kiri's favor, because only Docker Desktop carries a VM on Linux. We expect lower RAM, no separate VM disk image and faster start. Bind-mount-heavy work may also differ, since Docker Desktop shares files with its VM through VirtioFS [14].
- **H3: The differences that matter on Linux are not performance.** Without a VM, isolation comes from kernel namespaces, cgroups and seccomp, the same boundary Docker Engine has. Docker's own FAQ names the VM as a security benefit of Docker Desktop [14]. Kiri's agent replaces `runc`, `containerd` and `dockerd` [2], so its isolation, resource limits and socket permissions deserve direct testing.

A hypothesis counts as wrong if a measured difference passes the same rule we used here: above 10% on the median, ranges that do not overlap, and a saving large enough to matter.

**Add to the Linux run what Windows could not do:**

- five or more runs per measurement, with the load generator on a separate machine
- clean disks on every setup, as we did here, and several runs of the disk test, including how much space comes back after a prune
- a host reboot test and a power-cut test for Postgres
- an unprivileged user, using group access to the engine socket
- isolation checks: a container that tries to reach the host, device access, and the memory, CPU and process limits
- Kiri's service lifecycle under systemd: restart, upgrade and behavior after reboot

Until that run exists, treat Kiri on Linux as untested here.

---

## References

1. Kiri, "Containers", Kiri Docs. https://docs.runkiri.com/docker/containers/
2. Kiri, README and "How it works". https://github.com/libracoder/kiri and https://docs.runkiri.com/how-it-works/
3. Docker, "Docker Desktop WSL 2 backend on Windows". https://docs.docker.com/desktop/features/wsl/
4. Kiri, "Kiri on Windows" (beta, per-user install, WSL2, named pipe `\\.\pipe\kiri`). https://docs.runkiri.com/windows/
5. PostgreSQL, "Shutting Down the Server" (immediate shutdown, recovery by WAL replay). https://www.postgresql.org/docs/18/server-shutdown.html
6. Docker, "Start containers automatically" (restart policy is ignored after a manual stop). https://docs.docker.com/engine/containers/start-containers-automatically
7. Docker, "Resource constraints" (`--memory-swap` default is twice `--memory`). https://docs.docker.com/engine/containers/resource_constraints/
8. Microsoft, "Advanced settings configuration in WSL" (`.wslconfig`, default memory 50% of host RAM). https://learn.microsoft.com/en-us/windows/wsl/wsl-config
9. Docker, "Install Docker Engine". https://docs.docker.com/engine/install
10. Docker, "Install Docker Engine on Ubuntu" (convenience script not for production). https://docs.docker.com/engine/install/ubuntu/
11. Docker, "Docker Desktop license agreement". https://docs.docker.com/subscription-billing/desktop-license
12. Docker, "Docker Subscription Service Agreement". https://www.docker.com/legal/docker-subscription-service-agreement/
13. Docker, "Install Docker Desktop on Linux" (runs a VM, needs KVM, separate `desktop-linux` context). https://docs.docker.com/desktop/setup/install/linux/
14. Docker, "FAQs for Docker Desktop for Linux" (why it runs a VM, VirtioFS file sharing). https://docs.docker.com/desktop/troubleshoot-and-support/faqs/linuxfaqs
15. docker/desktop-feedback issue 375, "Docker Desktop WSL2 retains stale `isocache` ISO blobs across updates" (user report; describes `/mnt/docker-desktop-disk/isocache/entries`). https://github.com/docker/desktop-feedback/issues/375
16. Docker Community Forums, "Docker Desktop WSL2: VHDX grows by ~1.5GB after every update" (user report, includes a test on 4.76). https://forums.docker.com/t/docker-desktop-wsl2-vhdx-grows-by-1-5gb-after-every-update-no-way-to-reclaim-space/151729
