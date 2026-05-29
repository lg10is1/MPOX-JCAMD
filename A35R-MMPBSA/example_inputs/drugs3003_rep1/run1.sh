#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "[run1.sh] Container visibility test"
echo "============================================================"
echo "[run1.sh] Date: $(date)"
echo "[run1.sh] Host: $(hostname)"
echo "[run1.sh] Initial PWD=$(pwd)"
echo "[run1.sh] GMX_MMPBSA_RUNDIR=${GMX_MMPBSA_RUNDIR:-NA}"

cd "${GMX_MMPBSA_RUNDIR:?GMX_MMPBSA_RUNDIR is not set}"

echo "[run1.sh] After cd PWD=$(pwd)"
echo "[run1.sh] Listing current directory:"
ls -lh

echo
echo "[run1.sh] Check required files inside container:"
for f in md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_test_90_100_dt1000_fit.xtc; do
  if [[ ! -s "$f" ]]; then
    echo "[run1.sh][ERROR] Missing file inside container: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo "RUN1_VISIBILITY_OK $(date)" > RUN1_VISIBILITY_OK.txt
echo "[run1.sh][OK] Container can see run1.sh and calculation files."


