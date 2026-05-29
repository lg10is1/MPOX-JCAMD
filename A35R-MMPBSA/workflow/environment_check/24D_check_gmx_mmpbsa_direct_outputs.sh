#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>"
ROOT="$BASE/gmx_mmpbsa_50_100ns"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

cd "$BASE"

printf "%-10s %-5s %-8s %-8s %-8s %-8s %-s\n" \
  "system" "rep" "debug" "GB" "log" "status" "path"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/$SYS/$REP"

    DEBUG="NO"
    GB="NO"
    LOG="NO"
    STATUS="FAIL"

    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB_TEST.dat" ]] && DEBUG="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.dat" ]] && GB="YES"
    [[ -s "$D/mmpbsa_direct_prod_stdout_stderr.log" || -s "$D/mmpbsa_direct_debug_stdout_stderr.log" ]] && LOG="YES"

    if [[ "$GB" == "YES" ]]; then
      STATUS="PASS"
    elif [[ "$DEBUG" == "YES" ]]; then
      STATUS="DEBUG_ONLY"
    fi

    printf "%-10s %-5s %-8s %-8s %-8s %-8s %-s\n" \
      "$SYS" "$REP" "$DEBUG" "$GB" "$LOG" "$STATUS" "$D"
  done
done

echo
echo "============================================================"
echo "[INFO] Dangerous/error keyword scan"
echo "============================================================"

grep -RniE \
  "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation" \
  "$ROOT"/*/*/mmpbsa_direct_*stdout_stderr.log \
  "$ROOT"/*/*/gmx_MMPBSA.log \
  "$ROOT"/*/*/*.mdout 2>/dev/null || echo "No obvious error keywords found."

