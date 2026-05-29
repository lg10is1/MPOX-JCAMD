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
