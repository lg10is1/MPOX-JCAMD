#!/usr/bin/env bash
set -euo pipefail

ROOT=<REDACTED>
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

echo "============================================================"
echo "[INFO] GROMACS analysis backup integrity check"
echo "============================================================"
echo "[INFO] ROOT=$ROOT"
echo "[INFO] Date=$(date)"
echo "[INFO] Host=$(hostname)"
echo

echo "============================================================"
echo "[1] Basic folder check"
echo "============================================================"

for D in \
  00_project_overview \
  01_gromacs_input_systems \
  02_short_test_results \
  03_100ns_md_metadata \
  04_100ns_md_logs \
  05_100ns_final_structures \
  06_per_rep_analysis_outputs \
  07_combined_analysis_tables \
  08_md_figures \
  09_scripts \
  10_quality_control \
  99_manifest
do
  if [[ -d "$ROOT/$D" ]]; then
    echo "[OK] $D"
  else
    echo "[MISSING] $D"
  fi
done

echo
echo "============================================================"
echo "[2] 100 ns MD logs"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    LOG="$ROOT/04_100ns_md_logs/$SYS/$REP/md_100ns.log"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -s "$LOG" ]]; then
      echo "NO_LOG"
      continue
    fi

    if grep -qi "Finished mdrun" "$LOG"; then
      PERF="$(grep -i 'Performance:' "$LOG" | tail -n 1 | awk '{print $2}' || true)"
      echo "FINISHED Performance_ns_per_day=${PERF:-NA}"
    else
      echo "CHECK_LOG_NOT_FINISHED"
    fi
  done
done

echo
echo "============================================================"
echo "[3] Dangerous keyword scan in MD logs"
echo "============================================================"

if grep -RniE "Fatal error|Segmentation fault|LINCS WARNING|Too many LINCS warnings|not finite|exploding|Water molecule starting at atom|domain decomposition error|1-4 interaction.*cut-off" \
  "$ROOT/04_100ns_md_logs" 2>/dev/null; then
  echo "[WARN] Dangerous keywords found. Please inspect above."
else
  echo "No obvious dangerous keywords found in copied MD logs."
fi

echo
echo "============================================================"
echo "[4] Per-replicate analysis files"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/06_per_rep_analysis_outputs/$SYS/$REP/analysis"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -d "$D" ]]; then
      echo "NO_ANALYSIS_DIR"
      continue
    fi

    NCSV="$(find "$D" -maxdepth 1 -type f -name "*.csv" | wc -l)"
    NXVG="$(find "$D" -maxdepth 1 -type f -name "*.xvg" | wc -l)"
    NPDF="$(find "$D" -maxdepth 1 -type f -name "*.pdf" | wc -l)"
    echo "csv=$NCSV xvg=$NXVG pdf=$NPDF"
  done
done

echo
echo "============================================================"
echo "[5] Combined tables"
echo "============================================================"

find "$ROOT/07_combined_analysis_tables" \
  -type f \( -name "*.csv" -o -name "*.txt" -o -name "*.md" \) 2>/dev/null | sort

echo
echo "============================================================"
echo "[6] MD figure files"
echo "============================================================"

find "$ROOT/08_md_figures" \
  -type f \( -name "*.pdf" -o -name "*.png" -o -name "*.svg" \) 2>/dev/null | sort | head -n 200

echo
echo "============================================================"
echo "[7] Script files"
echo "============================================================"

find "$ROOT/09_scripts" \
  -type f \( -name "*.sh" -o -name "*.slurm" -o -name "*.py" -o -name "*.mdp" \) 2>/dev/null | sort | head -n 200

echo
echo "============================================================"
echo "[DONE] Integrity check finished"
echo "============================================================"
