#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# 09_check_finished_and_extract_energy.sh
# Purpose:
#   Quickly check whether 100 ns jobs finished and extract basic energy terms.
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

OUT="${BASE}/gmx_md100_3rep/job_finish_status.tsv"
echo -e "system\trep\tmd_log_exists\tfinished\tlast_step_line" > "${OUT}"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    RUNDIR="${BASE}/gmx_md100_3rep/${SYS}/${REP}"
    LOG="${RUNDIR}/md_100ns.log"
    if [[ -s "${LOG}" ]]; then
      FINISHED="NO"
      grep -q "Finished mdrun" "${LOG}" && FINISHED="YES"
      LASTSTEP="$(grep -E '^\s*Step\s+Time|^\s*[0-9]+\s+[0-9.]+' "${LOG}" | tail -n 1 | tr '\t' ' ' | sed 's/  */ /g')"
      echo -e "${SYS}\t${REP}\tYES\t${FINISHED}\t${LASTSTEP}" >> "${OUT}"
    else
      echo -e "${SYS}\t${REP}\tNO\tNO\tNA" >> "${OUT}"
    fi
  done
done

cat "${OUT}"
echo "[DONE] Status written to ${OUT}"

