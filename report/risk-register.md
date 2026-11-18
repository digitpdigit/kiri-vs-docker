# Risk register — Windows evaluation (2026-11-17)

Scope: Docker Desktop 4.44.2 vs Kiri 0.2.1 on one Windows 11 host. Only risks that the Windows tests could address are listed.

Not covered: Linux isolation without a VM, release churn and auto-update, project support and governance. No test addressed them.

| ID | Risk | Why exclusive to Kiri | Evidence | Status | Docker contrast |
|---|---|---|---|---|---|
| R1 | Secrets in crash reports / extra desktop surface | Kiri desktop features | Test 29: canary not in Event Log | Not observed in Event Log | Same test PASS |
| R2 | Recent fixes for core bugs | Kiri release notes | Tests 07, 34 PASS | Not observed in this set | Same PASS |
| R3 | Desktop lifecycle, no service | `kiri-win.exe`, no SCM service | Test 02 PARTIAL | Verified (no service). Reboot not tested | `com.docker.service` exists (restart not run; no admin) |
| R4 | Missing Compose features | Documented gaps | Tests 08, 31 PASS | Not observed | Same PASS |
| R5 | Tools that assume Docker socket | Pipe vs socket | Test 28: connects on both (privileged user) | Not observed for this CLI | Docker named pipe works |
| R6 | Unproven volume path for Postgres | Kiri storage | Tests 00, 01 PASS (0 acknowledged writes lost) | Not observed | Same PASS |
