#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

module purge >/dev/null 2>&1 || true
module load oneapi >/dev/null 2>&1 || true
module load gromacs/2021.3-intel-2021.4.0 >/dev/null 2>&1 || true

OUTDIR="gmx_finish_check"
mkdir -p "$OUTDIR"

SUMMARY="$OUTDIR/finish_summary.tsv"
ENERGY_SUMMARY="$OUTDIR/energy_summary.tsv"
DANGER="$OUTDIR/dangerous_keywords.txt"

echo -e "system\trep\tfinished\tlast_time_ps\tlast_time_ns\tgro\txtc\tedr\tcpt\tlog\tstatus" > "$SUMMARY"
echo -e "system\trep\tTemperature_K\tPressure_bar\tDensity_kg_m3\tPotential_kJ_mol\tTotalEnergy_kJ_mol" > "$ENERGY_SUMMARY"
: > "$DANGER"

echo "============================================================"
echo "[INFO] Checking 9 production MD trajectories"
echo "============================================================"

for SYS in drugs2263 drugs3003 drugs3523
do
  for REP in rep1 rep2 rep3
  do
    D="gmx_md100_3rep/${SYS}/${REP}"
    echo
    echo "================ ${SYS} ${REP} ================"

    LOG="${D}/md_100ns.log"
    XTC="${D}/md_100ns.xtc"
    EDR="${D}/md_100ns.edr"
    GRO="${D}/md_100ns.gro"
    CPT="${D}/md_100ns.cpt"

    if [[ ! -d "$D" ]]; then
      echo "[ERROR] Missing directory: $D"
      echo -e "${SYS}\t${REP}\tNO\tNA\tNA\tNO\tNO\tNO\tNO\tNO\tMISSING_DIR" >> "$SUMMARY"
      continue
    fi

    FINISHED="NO"
    if [[ -f "$LOG" ]] && grep -q "Finished mdrun" "$LOG"; then
      FINISHED="YES"
    fi

    HAS_GRO="NO"; [[ -f "$GRO" ]] && HAS_GRO="YES"
    HAS_XTC="NO"; [[ -f "$XTC" ]] && HAS_XTC="YES"
    HAS_EDR="NO"; [[ -f "$EDR" ]] && HAS_EDR="YES"
    HAS_CPT="NO"; [[ -f "$CPT" ]] && HAS_CPT="YES"
    HAS_LOG="NO"; [[ -f "$LOG" ]] && HAS_LOG="YES"

    LAST_PS="NA"
    LAST_NS="NA"

    if [[ -f "$XTC" ]]; then
      CHECK_OUT="${OUTDIR}/${SYS}_${REP}_gmx_check_xtc.txt"
      gmx_mpi check -f "$XTC" > "$CHECK_OUT" 2>&1 || true

      LAST_PS=$(python3 - "$CHECK_OUT" <<'PY'
import re, sys
txt=open(sys.argv[1], errors="ignore").read()
m=re.search(r"Last frame\s+\d+\s+time\s+([0-9.Ee+-]+)", txt)
if m:
    print(m.group(1))
else:
    vals=re.findall(r"\btime\s+([0-9.Ee+-]+)", txt)
    print(vals[-1] if vals else "NA")
PY
)
      if [[ "$LAST_PS" != "NA" ]]; then
        LAST_NS=$(awk -v x="$LAST_PS" 'BEGIN{printf "%.3f", x/1000.0}')
      fi
    fi

    STATUS="UNKNOWN"
    if [[ "$FINISHED" == "YES" && "$HAS_GRO" == "YES" && "$HAS_XTC" == "YES" && "$HAS_EDR" == "YES" ]]; then
      STATUS="PASS_FINISHED"
    elif [[ "$FINISHED" == "NO" && "$HAS_CPT" == "YES" ]]; then
      STATUS="NOT_FINISHED_BUT_CAN_CONTINUE_FROM_CPT"
    else
      STATUS="CHECK_REQUIRED"
    fi

    echo "[Finished] $FINISHED"
    echo "[Last time] ${LAST_PS} ps = ${LAST_NS} ns"
    echo "[Files] gro=$HAS_GRO xtc=$HAS_XTC edr=$HAS_EDR cpt=$HAS_CPT log=$HAS_LOG"
    echo "[Status] $STATUS"

    echo -e "${SYS}\t${REP}\t${FINISHED}\t${LAST_PS}\t${LAST_NS}\t${HAS_GRO}\t${HAS_XTC}\t${HAS_EDR}\t${HAS_CPT}\t${HAS_LOG}\t${STATUS}" >> "$SUMMARY"

    if [[ -f "$LOG" ]]; then
      grep -E "Fatal error|Segmentation fault|LINCS WARNING|Too many LINCS warnings|not finite|exploding|Water molecule starting at atom|domain decomposition error|1-4 interaction.*cut-off" "$LOG" \
        >> "$DANGER" 2>/dev/null || true
    fi

    if [[ -f "$EDR" ]]; then
      ENERGY_TXT="${OUTDIR}/${SYS}_${REP}_energy_stats.txt"
      ENERGY_XVG="${OUTDIR}/${SYS}_${REP}_energy_check.xvg"

      printf "Temperature\nPressure\nDensity\nPotential\nTotal-Energy\n0\n" | \
        gmx_mpi energy -f "$EDR" -o "$ENERGY_XVG" > "$ENERGY_TXT" 2>&1 || true

      python3 - "$ENERGY_TXT" "$SYS" "$REP" >> "$ENERGY_SUMMARY" <<'PY'
import re, sys, math

path, system, rep = sys.argv[1], sys.argv[2], sys.argv[3]
txt = open(path, errors="ignore").read()

wanted = {
    "Temperature": "NA",
    "Pressure": "NA",
    "Density": "NA",
    "Potential": "NA",
    "Total Energy": "NA",
}

for line in txt.splitlines():
    s = line.strip()
    for key in list(wanted):
        if s.startswith(key):
            parts = s.split()
            if len(parts) >= 2:
                wanted[key] = parts[1]

print(
    f"{system}\t{rep}\t"
    f"{wanted['Temperature']}\t"
    f"{wanted['Pressure']}\t"
    f"{wanted['Density']}\t"
    f"{wanted['Potential']}\t"
    f"{wanted['Total Energy']}"
)
PY
    fi
  done
done

echo
echo "============================================================"
echo "[INFO] Finish summary"
echo "============================================================"
column -t "$SUMMARY" || cat "$SUMMARY"

echo
echo "============================================================"
echo "[INFO] Energy summary"
echo "============================================================"
column -t "$ENERGY_SUMMARY" || cat "$ENERGY_SUMMARY"

echo
echo "============================================================"
echo "[INFO] Dangerous keyword scan"
echo "============================================================"
if [[ -s "$DANGER" ]]; then
  cat "$DANGER"
  echo
  echo "[WARNING] Dangerous keywords found. Please inspect logs before analysis."
else
  echo "No real dangerous keywords found."
fi

echo
echo "[DONE] Results saved in: $OUTDIR/"
