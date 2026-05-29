#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
JOBID="${1:-58132653}"

cd "$BASE"

echo "============================================================"
echo "[1] SLURM squeue status for job: $JOBID"
echo "============================================================"
squeue -j "$JOBID" -o "%.18i %.9P %.35j %.8u %.2t %.12M %.12l %.6D %R" || true

echo
echo "============================================================"
echo "[2] SLURM sacct status for job: $JOBID"
echo "============================================================"
sacct -j "$JOBID" \
  --format=JobID%25,JobName%35,Partition,State,Elapsed,Timelimit,AllocNodes,AllocCPUS,ExitCode%12 || true

echo
echo "============================================================"
echo "[3] GROMACS 100 ns progress from output directories"
echo "============================================================"

module purge >/dev/null 2>&1 || true
module load oneapi >/dev/null 2>&1 || true
module load gromacs/2021.3-intel-2021.4.0 >/dev/null 2>&1 || true

python3 - <<'PY'
import os, re, glob, subprocess, math
from pathlib import Path
from datetime import timedelta

base = Path("<PROJECT_ROOT>/gromacs-runs")
systems = ["drugs2263", "drugs3003", "drugs3523"]
reps = ["rep1", "rep2", "rep3"]

def read_text(path):
    try:
        return Path(path).read_text(errors="ignore")
    except Exception:
        return ""

def file_size_mb(path):
    try:
        return os.path.getsize(path) / 1024 / 1024
    except Exception:
        return 0.0

def get_mdp_value(mdp_path, key, default=None):
    txt = read_text(mdp_path)
    for line in txt.splitlines():
        line2 = line.split(";")[0].strip()
        if not line2:
            continue
        if re.match(rf"^{re.escape(key)}\s*=", line2):
            return line2.split("=", 1)[1].strip()
    return default

def parse_performance(log_text):
    # GROMACS log summary usually has:
    # Performance:       86.913        0.276
    matches = re.findall(r"Performance:\s+([0-9.]+)\s+([0-9.]+)", log_text)
    if matches:
        ns_per_day = float(matches[-1][0])
        hour_per_ns = float(matches[-1][1])
        return ns_per_day, hour_per_ns
    return None, None

def parse_finished(log_text):
    return "Finished mdrun" in log_text

def parse_log_last_step(log_text):
    # Progress may appear in stderr, but sometimes log has step info.
    nums = []
    for m in re.finditer(r"\bstep\s+([0-9]+)\b", log_text):
        nums.append(int(m.group(1)))
    return max(nums) if nums else None

def parse_last_time_from_xtc(xtc_path):
    if not Path(xtc_path).exists():
        return None
    try:
        p = subprocess.run(
            ["gmx_mpi", "check", "-f", str(xtc_path)],
            input="",
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=60,
        )
        out = p.stdout
        # Examples may contain: Last frame          100 time 1000.000
        m = re.search(r"Last frame\s+\d+\s+time\s+([0-9.Ee+-]+)", out)
        if m:
            return float(m.group(1)) # ps
        # fallback: collect all "time" values
        vals = re.findall(r"\btime\s+([0-9.Ee+-]+)", out)
        if vals:
            return float(vals[-1])
    except Exception:
        return None
    return None

def fmt_time_days(days):
    if days is None or math.isnan(days) or math.isinf(days) or days < 0:
        return "NA"
    total_seconds = int(days * 86400)
    d = total_seconds // 86400
    h = (total_seconds % 86400) // 3600
    m = (total_seconds % 3600) // 60
    if d > 0:
        return f"{d}d {h}h {m}m"
    if h > 0:
        return f"{h}h {m}m"
    return f"{m}m"

print("system\trep\tstatus\tcurrent_ns\ttarget_ns\tprogress_%\tperf_ns_per_day\test_remaining\txtc_MB\tcpt_MB\tlog")

for sys in systems:
    for rep in reps:
        d = base / "gmx_md100_3rep" / sys / rep
        log = d / "md_100ns.log"
        xtc = d / "md_100ns.xtc"
        cpt = d / "md_100ns.cpt"
        mdp = d / "md_100ns_out.mdp"

        if not d.exists():
            print(f"{sys}\t{rep}\tNOT_STARTED\t0\t100\t0\tNA\tNA\t0\t0\t{log}")
            continue

        log_text = read_text(log)

        nsteps_raw = get_mdp_value(mdp, "nsteps", "50000000")
        dt_raw = get_mdp_value(mdp, "dt", "0.002")

        try:
            nsteps = int(float(nsteps_raw))
        except Exception:
            nsteps = 50000000

        try:
            dt_ps = float(dt_raw)
        except Exception:
            dt_ps = 0.002

        target_ns = nsteps * dt_ps / 1000.0

        current_ps = parse_last_time_from_xtc(xtc)
        if current_ps is not None:
            current_ns = current_ps / 1000.0
        else:
            step = parse_log_last_step(log_text)
            current_ns = step * dt_ps / 1000.0 if step is not None else 0.0

        finished = parse_finished(log_text)
        ns_per_day, hour_per_ns = parse_performance(log_text)

        if finished:
            status = "FINISHED"
            remaining = "0m"
            progress = 100.0
        else:
            status = "RUNNING_OR_PENDING"
            progress = min(100.0, current_ns / target_ns * 100.0) if target_ns > 0 else 0.0
            if ns_per_day and ns_per_day > 0:
                remaining_days = max(0.0, (target_ns - current_ns) / ns_per_day)
                remaining = fmt_time_days(remaining_days)
            else:
                remaining = "NA"

        print(
            f"{sys}\t{rep}\t{status}\t"
            f"{current_ns:.3f}\t{target_ns:.1f}\t{progress:.2f}\t"
            f"{ns_per_day if ns_per_day else 'NA'}\t{remaining}\t"
            f"{file_size_mb(xtc):.1f}\t{file_size_mb(cpt):.1f}\t{log}"
        )
PY

echo
echo "============================================================"
echo "[4] Recent SLURM stderr progress"
echo "============================================================"
ls -lh gmx_100ns_3rep_*.err 2>/dev/null || true

echo
echo "[INFO
] Latest progress lines from SLURM err files:"
for f in gmx_100ns_3rep_*.err; do
  [[ -f "$f" ]] || continue
  echo "---------------- $f ----------------"
  grep -E "step +[0-9]+|remaining wall clock time|Performance|Writing final coordinates|Fatal error|LINCS WARNING|not finite" "$f" 2>/dev/null | tail -n 12 || true
done

echo
echo "============================================================"
echo "[5] Dangerous keyword scan in 100 ns logs"
echo "============================================================"
grep -R -E "Fatal error|Segmentation fault|LINCS WARNING|Too many LINCS warnings|not finite|exploding|Water molecule starting at atom|domain decomposition error|1-4 interaction.*cut-off" \
  gmx_md100_3rep/*/*/*.log 2>/dev/null || echo "No real dangerous keywords found in md logs."
