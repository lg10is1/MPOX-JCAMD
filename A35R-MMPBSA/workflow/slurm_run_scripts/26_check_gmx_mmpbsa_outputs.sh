#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-<PROJECT_ROOT>}"
OUTROOT="${OUTROOT:-$BASE/gmx_mmpbsa_50_100ns}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

printf "%-10s %-5s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
  "system" "rep" "gb_dat" "gb_csv" "gbpb_dat" "decomp" "errors" "status"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$OUTROOT/$SYS/$REP"

    gb_dat="NO"; gb_csv="NO"; gbpb_dat="NO"; decomp="NO"; errors="NO"; status="PASS"

    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.dat" ]] && gb_dat="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.csv" ]] && gb_csv="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB_PB.dat" ]] && gbpb_dat="YES"
    [[ -s "$D/FINAL_DECOMP_MMPBSA_GB.dat" ]] && decomp="YES"

    if grep -R -iE "fatal|error|traceback|segmentation|nan|not finite|bad atom type|could not|failed" "$D"/*.log "$D"/*.dat 2>/dev/null | grep -v -i "estimated" >/dev/null 2>&1; then
      errors="YES"
      status="CHECK"
    fi

    if [[ "$gb_dat" == "NO" ]]; then
      status="MISSING_GB"
    fi

    printf "%-10s %-5s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
      "$SYS" "$REP" "$gb_dat" "$gb_csv" "$gbpb_dat" "$decomp" "$errors" "$status"
  done
done

echo
echo "[INFO] Dangerous keyword details:"
grep -R -iE "fatal|traceback|segmentation|nan|not finite|bad atom type|could not|failed" "$OUTROOT"/*/*/*.log "$OUTROOT"/*/*/*.dat 2>/dev/null || echo "No obvious dangerous keywords found."


