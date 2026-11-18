"""Build results/COMPARE.md from results/<runtime>/<test>/metrics.json.

Usage: python tests/compare.py [out_path]
Never picks a verdict for you; it only tabulates and applies the delta rule.
"""
import glob
import json
import os
import sys
from collections import defaultdict

root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
results = os.path.join(root, "results")
out_path = sys.argv[1] if len(sys.argv) > 1 else os.path.join(results, "COMPARE.md")
rows = []
for path in sorted(glob.glob(os.path.join(results, "*", "*", "metrics.json"))):
    d = os.path.dirname(path)
    name = os.path.relpath(d, results).replace("\\", "/")
    try:
        with open(path, encoding="utf-8-sig") as f:
            m = json.load(f)
    except Exception as e:
        print("skip", path, e, file=sys.stderr)
        continue
    if m.get("quick"):
        continue
    m["_dir"] = name
    rows.append(m)

if not rows:
    open(out_path, "w", encoding="utf-8").write(
        "# COMPARE\n\nNo non-quick results found.\n"
    )
    sys.exit(0)

images = {r.get("app_image_id") for r in rows if r.get("app_image_id")}
images.discard("missing")
image_ok = len(images) <= 1

AREA = {
    "A": ["07", "08", "09", "34"],
    "B": ["14", "16", "17", "18", "19", "20", "21", "22", "23", "24", "38"],
    "C": ["00", "01", "02", "13"],
    "D": ["28", "29", "31"],
}
SEV = {
    "01": "STOP", "02": "STOP",
    "07": "BLOCKER", "08": "BLOCKER", "09": "BLOCKER", "13": "BLOCKER", "14": "BLOCKER",
    "28": "BLOCKER", "29": "BLOCKER",
}

by = defaultdict(lambda: defaultdict(list))
for r in rows:
    by[str(r.get("test_id"))][r.get("runtime")].append(r)

lines = []
lines.append("# COMPARE")
lines.append("")
lines.append("Human decides outcome A / B / C. This file does not.")
lines.append("")
if not image_ok:
    # Docker Desktop and Kiri report different IDs for the same loaded image
    # (manifest-list digest vs config digest), so one ID per runtime is expected.
    ids_by_runtime = defaultdict(set)
    for r in rows:
        if r.get("app_image_id") and r["app_image_id"] != "missing":
            ids_by_runtime[r.get("runtime")].add(r["app_image_id"])
    if any(len(v) > 1 for v in ids_by_runtime.values()):
        lines.append("**Warning:** one runtime ran more than one app image. Comparison is invalid.")
    else:
        lines.append("Note: the two engines report different IDs for the same app image (saved from one, loaded into the other). One ID per runtime is expected:")
    lines.append("")
    for rt in sorted(ids_by_runtime):
        for i in sorted(ids_by_runtime[rt]):
            lines.append(f"- {rt}: `{i}`")
    lines.append("")

def median(xs):
    xs = sorted(xs)
    n = len(xs)
    if n == 0:
        return None
    if n % 2:
        return xs[n // 2]
    return (xs[n // 2 - 1] + xs[n // 2]) / 2

def numeric_metrics(runs):
    keys = set()
    for r in runs:
        keys.update((r.get("metrics") or {}).keys())
    out = {}
    for k in keys:
        vals = []
        for r in runs:
            v = (r.get("metrics") or {}).get(k)
            if isinstance(v, (int, float)):
                vals.append(float(v))
        if vals:
            out[k] = vals
    return out

def verdict(dvals, kvals):
    dm, km = median(dvals), median(kvals)
    if dm is not None and dm == km:
        return "no meaningful difference"
    if dm is None or km is None or dm == 0:
        return "inconclusive"
    pct = abs(km - dm) / abs(dm) * 100
    dmin, dmax = min(dvals), max(dvals)
    kmin, kmax = min(kvals), max(kvals)
    overlap = not (dmax < kmin or kmax < dmin)
    if pct > 10 and not overlap:
        return f"candidate ({pct:.1f}% median delta, ranges do not overlap; still needs decision-size judgement)"
    return "no meaningful difference"

lines.append("## STOP / BLOCKER")
lines.append("")
stop_kiri_fail = []
blocker_kiri_fail = []
for tid in sorted(by.keys()):
    kruns = by[tid].get("kiri") or []
    druns = by[tid].get("docker") or []
    kfail = any(r.get("result") == "FAIL" for r in kruns)
    dfail = any(r.get("result") == "FAIL" for r in druns)
    sev = SEV.get(tid, "FINDING")
    if kfail and not dfail and sev == "STOP":
        stop_kiri_fail.append(tid)
    if kfail and not dfail and sev == "BLOCKER":
        blocker_kiri_fail.append(tid)
if stop_kiri_fail:
    lines.append(f"STOP failures on Kiri (not on Docker): {', '.join(stop_kiri_fail)}. Treat as not suitable for data-bearing use.")
else:
    lines.append("No STOP-only-on-Kiri failures in this tree.")
lines.append("")
if blocker_kiri_fail:
    lines.append(f"BLOCKER failures on Kiri (not on Docker): {', '.join(blocker_kiri_fail)}. Treat as not ready unless a documented, tested workaround exists.")
else:
    lines.append("No BLOCKER-only-on-Kiri failures in this tree.")
lines.append("")

def area_block(letter, title, ids):
    lines.append(f"## {letter}. {title}")
    lines.append("")
    lines.append("| ID | Docker | Kiri | Perf rule |")
    lines.append("|---|---|---|---|")
    for tid in ids:
        dr = by[tid].get("docker") or []
        kr = by[tid].get("kiri") or []
        def summary(runs):
            if not runs:
                return "—"
            rs = ",".join(sorted({r.get("result", "?") for r in runs}))
            return rs
        rule = "—"
        if dr and kr:
            dm = numeric_metrics(dr)
            km = numeric_metrics(kr)
            common = set(dm) & set(km)
            bits = []
            for k in sorted(common):
                bits.append(f"{k}: {verdict(dm[k], km[k])}")
            if bits:
                rule = "; ".join(bits)
        lines.append(f"| {tid} | {summary(dr)} | {summary(kr)} | {rule} |")
    lines.append("")

area_block("A", "Compatibility", AREA["A"])
area_block("B", "Resource usage", AREA["B"])
area_block("C", "Fault tolerance", AREA["C"])
area_block("D", "Security and operations", AREA["D"])

# extras like 00
extra = [t for t in sorted(by.keys()) if all(t not in AREA[a] for a in AREA)]
if extra:
    area_block("X", "Other recorded IDs", extra)

lines.append("## Directories")
lines.append("")
for r in sorted(rows, key=lambda x: x["_dir"]):
    lines.append(f"- `{r['_dir']}` test={r.get('test_id')} runtime={r.get('runtime')} result={r.get('result')}")
lines.append("")

open(out_path, "w", encoding="utf-8").write("\n".join(lines))
print(out_path)
