#!/bin/bash
#SBATCH --job-name=mmpbsa_gb
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=32
#SBATCH --array=0-8
#SBATCH --output=mmpbsa_gb_%A_%a.out
#SBATCH --error=mmpbsa_gb_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

JOBS=(
"drugs2263 rep1"
"drugs2263 rep2"
"drugs2263 rep3"
"drugs3003 rep1"
"drugs3003 rep2"
"drugs3003 rep3"
"drugs3523 rep1"
"drugs3523 rep2"
"drugs3523 rep3"
)

read SYS REP <<< "${JOBS[$SLURM_ARRAY_TASK_ID]}"

echo "============================================================"
echo "[INFO] gmx_MMPBSA MM/GBSA production"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] Array task: $SLURM_ARRAY_TASK_ID"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"

RUNDIR="$OUTROOT/$SYS/$REP"

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing directory: $RUNDIR"
  exit 1
fi

cd "$RUNDIR"

echo
echo "============================================================"
echo "[INFO] Check required files"
echo "============================================================"
for f in \
  md_100ns.tpr \
  topol.top \
  mmpbsa_index.ndx \
  mmpbsa_gb_prod.in \
  mmpbsa_50_100_dt500_fit.xtc
do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing required file: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo
echo "============================================================"
echo "[INFO] Create run1.sh"
echo "============================================================"

cat > run1.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "[run1.sh] Inside gmx_MMPBSA container"
echo "[run1.sh] Working directory: $(pwd)"
echo "[run1.sh] Date: $(date)"

gmx_MMPBSA MPI \
  -O \
  -i mmpbsa_gb_prod.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB.csv \
  -nogui
EOF_RUN

chmod +x run1.sh
cat run1.sh

echo
echo "============================================================"
echo "[INFO] Run gmx_MMPBSA container"
echo "============================================================"
module load gmx_mmpbsa/1.5.2-gcc-9.3.0
module list 2>&1 || true

which gmx_MMPBSA_1.5.2 || {
  echo "[ERROR] gmx_MMPBSA_1.5.2 not found after module load."
  exit 1
}

gmx_MMPBSA_1.5.2

echo
echo "============================================================"
echo "[INFO] Output check"
echo "============================================================"
ls -lh FINAL_RESULTS_MMPBSA_GB.dat FINAL_RESULTS_MMPBSA_GB.csv 2>/dev/null || true
tail -n 120 FINAL_RESULTS_MMPBSA_GB.dat 2>/dev/null || true

echo
echo "[DONE] Finished $SYS $REP at $(date)"
