#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>"
ROOT="$BASE/gmx_mmpbsa_50_100ns"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

cd "$BASE"

echo "============================================================"
echo "[INFO] Check gmx_MMPBSA PBRadii=3 outputs"
echo "============================================================"
date
echo

printf "%-10s %-5s %-9s %-9s %-9s %-9s %-s\n" \
  "system" "rep" "debugdat" "proddat" "prodcsv" "status" "path"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/$SYS/$REP"

    DEBUGDAT="NO"
    PRODDAT="NO"
    PRODCSV="NO"
    STATUS="FAIL"

    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB_TEST.dat" ]] && DEBUGDAT="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.dat" ]] && PRODDAT="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.csv" ]] && PRODCSV="YES"

    if [[ "$PRODDAT" == "YES" ]]; then
      STATUS="PASS"
    elif [[ "$DEBUGDAT" == "YES" ]]; then
      STATUS="DEBUG_ONLY"
    fi

    printf "%-10s %-5s %-9s %-9s %-9s %-9s %-s\n" \
      "$SYS" "$REP" "$DEBUGDAT" "$PRODDAT" "$PRODCSV" "$STATUS" "$D"
  done
done

echo
echo "============================================================"
echo "[INFO] Error keyword scan"
echo "============================================================"

grep -RniE \
  "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation|ValueError" \
  "$ROOT"/*/*/mmpbsa_pbr3_*stdout_stderr.log \
  "$ROOT"/*/*/gmx_MMPBSA.log \
  "$ROOT"/*/*/*.mdout 2>/dev/null || echo "No obvious error keywords found."


