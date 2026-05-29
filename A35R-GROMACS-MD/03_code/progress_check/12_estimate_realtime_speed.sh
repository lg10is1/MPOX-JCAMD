#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
WAIT_SECONDS="${1:-600}"

cd "$BASE"

module purge >/dev/null 2>&1 || true
module load oneapi >/dev/null 2>&1 || true
module load gromacs/2021.3-intel-2021.4.0 >/dev/null 2>&1 || true

echo "[INFO] BASE=$BASE"
echo "[INFO] WAIT_SECONDS=$WAIT_SECONDS"
echo "[INFO] gmx_mpi path:"
which gmx_mpi || true

cat > .get_current_progress.py <<'PY'
#!/usr/bin/env python3
import os
import re
import subprocess
from pathlib import Path

BASE = Path("<PROJECT_ROOT>/gromacs-runs")
SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

def read_text(path):
    try:
        return Path(path).read_text(errors="ignore")
    except Exception:
        return ""

def get_progress_from_xtc(xtc):
    xtc = Path(xtc)
    if not xtc.exists() or xtc.stat().st_size == 0:
        return None

    try:
        p = subprocess.run(
            ["gmx_mpi", "check", "-f", str(xtc)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            timeout=120,
        )
        out = p.stdout

        # Most common GROMACS format:
        # Last frame       5967 time 59670.000
        m = re.search(r"Last frame\s+\d+\s+time\s+([0-9.Ee+-]+)", out)
        if m:
            return float(m.group(1)) / 1000.0

        # More tolerant fallback: find the last "time xxx"
        times = re.findall(r"\btime\s+([0-9.Ee+-]+)", out)
        if times:
            return float(times[-1]) / 1000.0

        # Save debug if parse failed
        debug = xtc.parent / "gmx_check_debug.txt"
        debug.write_text(out, errors="ignore")
        return None

    except Exception as e:
        debug = xtc.parent / "gmx_check_debug.txt"
        debug.write_text(f"gmx check failed: {e}\n", errors="ignore")
        return None

def get_progress_from_log(log):
    txt = read_text(log)
    if not txt:
        return None

    # Fallback if xtc parsing fails.
    # dt = 0.002 ps, so 50,000,000 steps = 100 ns.
    dt_ps = 0.002

    steps = []
    for m in re.finditer(r"\bstep\s+([0-9]+)\b", txt):
        try:
            steps.append(int(m.group(1)))
        except Exception:
            pass

    if steps:
        return max(steps) * dt_ps / 1000.0

    return None

print("system\trep\tcurrent_ns\txtc_MB\tcpt_MB\tstatus")

for sys in SYSTEMS:
    for rep in REPS:
        d = BASE / "gmx_md100_3rep" / sys / rep
        xtc = d / "md_100ns.xtc"
        cpt = d / "md_100ns.cpt"
        log = d / "md_100ns.log"

        current_ns = get_progress_from_xtc(xtc)
        source = "xtc"

        if current_ns is None:
            current_ns = get_progress_from_log(log)
            source = "log"

        if current_ns is None:
            current_ns = 0.0
            source = "none"

        xtc_mb = xtc.stat().st_size / 1024 / 1024 if xtc.exists() else 0.0
        cpt_mb = cpt.stat().st_size / 1024 / 1024 if cpt.exists() else 0.0

        if "Finished mdrun" in read_text(log):
            status = "FINISHED"
        elif d.exists():
            status = f"RUNNING_OR_PENDING_by_{source}"
        else:
            status = "NOT_STARTED"

        print(f"{sys}\t{rep}\t{current_ns:.3f}\t{xtc_mb:.1f}\t{cpt_mb:.1f}\t{status}")
PY

chmod +x .get_current_progress.py

echo
echo "[INFO] Taking first snapshot..."
python3 .get_current_progress.py | tee progress_snapshot_1.tsv

echo
echo "[INFO] Waiting ${WAIT_SECONDS} seconds for real-time speed estimation..."
sleep "$WAIT_SECONDS"

echo
echo "[INFO] Taking second snapshot..."

python3 .get_current_progress.py | tee progress_snapshot_2.tsv

echo
echo "======================================================"
echo "Realtime speed estimation"
echo "======================================================"

python3 - <<'PY'
#!/usr/bin/env python3
from pathlib import Path
import sys

WAIT_SECONDS = 600
try:
    # Read from bash env indirectly impossible here unless exported;
    # infer from snapshot interval not needed for default, user can edit below.
    pass
except Exception:
    pass

# Get actual wait seconds from shell-generated file is not needed;
# use environment if present.
import os
WAIT_SECONDS = int(os.environ.get("WAIT_SECONDS", "600"))

def read_tsv(path):
    rows = {}
    lines = Path(path).read_text().strip().splitlines()
    header = lines[0].split("\t")
    for line in lines[1:]:
        parts = line.split("\t")
        item = dict(zip(header, parts))
        key = (item["system"], item["rep"])
        rows[key] = item
    return rows

a = read_tsv("progress_snapshot_1.tsv")
b = read_tsv("progress_snapshot_2.tsv")

print("system\trep\tns_t1\tns_t2\tdelta_ns\tspeed_ns_per_day\tremaining_ns\test_remaining")

for key in sorted(b.keys()):
    sys_name, rep = key

    ns1 = float(a.get(key, {}).get("current_ns", 0.0))
    ns2 = float(b.get(key, {}).get("current_ns", 0.0))

    delta = ns2 - ns1
    speed = delta / (WAIT_SECONDS / 86400.0) if WAIT_SECONDS > 0 else 0.0
    remaining = max(0.0, 100.0 - ns2)

    if speed > 0:
        remaining_days = remaining / speed
        total_min = int(remaining_days * 24 * 60)
        h = total_min // 60
        m = total_min % 60
        est = f"{h}h {m}m"
    else:
        est = "NA"

    print(
        f"{sys_name}\t{rep}\t"
        f"{ns1:.3f}\t{ns2:.3f}\t{delta:.3f}\t"
        f"{speed:.2f}\t{remaining:.3f}\t{est}"
    )
PY

echo
echo "[INFO] If speed_ns_per_day is still 0, check one debug file, for example:"
echo "cat gmx_md100_3rep/drugs2263/rep1/gmx_check_debug.txt"
