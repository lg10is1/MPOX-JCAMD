#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
RUNDIR="${1:-$BASE/gmx_mmpbsa_50_100ns/drugs3003/rep1}"

cd "$BASE"

echo "============================================================"
echo "[1] Basic information"
echo "============================================================"
echo "BASE=$BASE"
echo "RUNDIR=$RUNDIR"
hostname
date
pwd

echo
echo "============================================================"
echo "[2] SLURM test out/err files"
echo "============================================================"
ls -ltrh mmpbsa_test_*.out mmpbsa_test_*.err 2>/dev/null || true

echo
echo "============================================================"
echo "[3] Last 200 lines of latest SLURM out"
echo "============================================================"
LATEST_OUT=$(ls -t mmpbsa_test_*.out 2>/dev/null | head -n 1 || true)
if [[ -n "${LATEST_OUT:-}" ]]; then
  echo "[INFO] Latest OUT=$LATEST_OUT"
  tail -n 200 "$LATEST_OUT" || true
else
  echo "[WARN] No mmpbsa_test_*.out found."
fi

echo
echo "============================================================"
echo "[4] Last 200 lines of latest SLURM err"
echo "============================================================"
LATEST_ERR=$(ls -t mmpbsa_test_*.err 2>/dev/null | head -n 1 || true)
if [[ -n "${LATEST_ERR:-}" ]]; then
  echo "[INFO] Latest ERR=$LATEST_ERR"
  tail -n 200 "$LATEST_ERR" || true
else
  echo "[WARN] No mmpbsa_test_*.err found."
fi

echo
echo "============================================================"
echo "[5] Search real error keywords in SLURM logs"
echo "============================================================"
grep -RniE \
  "MMPBSA_Error|GMXMMPBSA|Traceback|Fatal|ERROR|Error|exception|Exception|not found|No such file|Cannot|could not|failed|Failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|antechamber|parmed|radii|PB Bomb|bad atom|molecule|topology" \
  mmpbsa_test_*.out mmpbsa_test_*.err 2>/dev/null || true

echo
echo "============================================================"
echo "[6] Run directory file list"
echo "============================================================"
if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing RUNDIR=$RUNDIR"
  exit 1
fi

cd "$RUNDIR"
pwd
ls -lah

echo
echo "============================================================"
echo "[7] Check required files"
echo "============================================================"
for f in \
  run1.sh \
  md_100ns.tpr \
  topol.top \
  mmpbsa_index.ndx \
  mmpbsa_gb_test.in \
  mmpbsa_test_90_100_dt1000_fit.xtc
do
  if [[ -s "$f" ]]; then
    echo "[OK] $f"
    ls -lh "$f"
  else
    echo "[MISS] $f"
  fi
done

echo
echo "============================================================"
echo "[8] Show run1.sh"
echo "============================================================"
cat run1.sh 2>/dev/null || true

echo
echo "============================================================"
echo "[9] Show mmpbsa input"
echo "============================================================"
cat mmpbsa_gb_test.in 2>/dev/null || true

echo
echo "============================================================"
echo "[10] Index group headers and report"
echo "============================================================"
grep -n "^\[" mmpbsa_index.ndx 2>/dev/null || true
echo
cat mmpbsa_index.report.txt 2>/dev/null || true

echo
echo "============================================================"
echo "[11] Search gmx_MMPBSA internal logs"
echo "============================================================"
find . -maxdepth 2 -type f \( \
  -name "*MMPBSA*.log" -o \
  -name "gmx_MMPBSA.log" -o \
  -name "_GMXMMPBSA*.log" -o \
  -name "*.out" -o \
  -name "*.err" -o \
  -name "*.mdout" \
\) -print | sort || true

echo
echo "============================================================"
echo "[12] Real error keywords inside run directory"
echo "============================================================"
grep -RniE \
  "MMPBSA_Error|GMXMMPBSA|Traceback|Fatal|ERROR|Error|exception|Exception|not found|No such file|Cannot|could not|failed|Failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|antechamber|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation" \
  . 2>/dev/null || true

echo
echo "============================================================"
echo "[13] Check trajectory readability"
echo "============================================================"
set +e
if type module >/dev/null 2>&1; then
  module load oneapi 2>/dev/null
  module load gromacs/2021.3-intel-2021.4.0 2>/dev/null
fi

if command -v gmx_mpi >/dev/null 2>&1; then
  GMX=gmx_mpi
elif command -v gmx >/dev/null 2>&1; then
  GMX=gmx
else
  GMX=""
fi

if [[ -n "$GMX" ]]; then
  echo "[INFO] GMX=$GMX"
  $GMX check -f mmpbsa_test_90_100_dt1000_fit.xtc 2>&1 | tail -n 80
else
  echo "[WARN] gmx/gmx_mpi not found."
fi
set -e

echo
echo "============================================================"
echo "[14] Check topology include files"
echo "============================================================"
echo "[INFO] #include lines in topol.top:"
grep -n '^[[:space:]]*#include' topol.top 2>/dev/null || true

echo
echo "[INFO] Missing local include files, if any:"
python3 - <<'PY'
from pathlib import Path
import re
top=Path("topol.top")
if not top.exists():
    raise SystemExit
for line in top.read_text(errors="ignore").splitlines():
    m=re.search(r'#include\s+["<]([^">]+)[">]', line)
    if not m:
        continue
    inc=m.group(1)
    p=Path(inc)
    if not p.is_absolute():
        p=Path(".")/p
    if not p.exists():
        print(f"[MISSING_INCLUDE] {inc}")
PY

echo
echo "============================================================"
echo "[DONE] Diagnosis finished"
echo "============================================================"
