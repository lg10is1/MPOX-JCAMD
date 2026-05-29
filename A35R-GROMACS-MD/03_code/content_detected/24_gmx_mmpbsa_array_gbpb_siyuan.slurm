#!/bin/bash
#SBATCH --job-name=mmpbsa_gbpb
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=32
#SBATCH --array=0-8
#SBATCH --output=mmpbsa_gbpb_%A_%a.out
#SBATCH --error=mmpbsa_gbpb_%A_%a.err

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
echo "[INFO] gmx_MMPBSA MM/GBSA + MM/PBSA production"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] Array task: $SLURM_ARRAY_TASK_ID"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"

RUNDIR="$OUTROOT/$SYS/$REP"

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing directory: $RUNDIR"
  exit 1
fi

cd "$RUNDIR"

for f in \
  md_100ns.tpr \
  topol.top \
  mmpbsa_index.ndx \
  mmpbsa_gb_pb_prod.in \
  mmpbsa_50_100_dt500_fit.xtc
do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing required file: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

cat > run1.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "[run1.sh] Inside gmx_MMPBSA container"
echo "[run1.sh] Working directory: $(pwd)"
echo "[run1.sh] Date: $(date)"

gmx_MMPBSA MPI \
  -O \
  -i mmpbsa_gb_pb_prod.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB_PB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB_PB.csv \
  -nogui
EOF_RUN

chmod +x run1.sh
cat run1.sh

module load gmx_mmpbsa/1.5.2-gcc-9.3.0
module list 2>&1 || true
which gmx_MMPBSA_1.5.2

gmx_MMPBSA_1.5.2

ls -lh FINAL_RESULTS_MMPBSA_GB_PB.dat FINAL_RESULTS_MMPBSA_GB_PB.csv 2>/dev/null || true
tail -n 160 FINAL_RESULTS_MMPBSA_GB_PB.dat 2>/dev/null || true

echo "[DONE] Finished $SYS $REP at $(date)"
