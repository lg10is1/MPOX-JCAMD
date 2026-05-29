#!/bin/bash
#SBATCH --job-name=mmpbsa_gbpb
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
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

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] SYS=$SYS REP=$REP"

cd "$OUTROOT/$SYS/$REP"

set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  gmx_MMPBSA_1.5.2 || true
fi

if ! command -v gmx_MMPBSA >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base)"
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate gmxMMPBSA
  fi
fi

which gmx_MMPBSA
NPROC="${SLURM_NTASKS:-16}"

echo "[INFO] Running production MM/GBSA + MM/PBSA on 50-100 ns trajectory"
mpirun -np "$NPROC" gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_pb_prod.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB_PB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB_PB.csv \
  -nogui > mmpbsa_gb_pb.progress.log 2>&1

echo "[INFO] Finished at $(date)"
ls -lh FINAL_RESULTS_MMPBSA_GB_PB.dat FINAL_RESULTS_MMPBSA_GB_PB.csv mmpbsa_gb_pb.progress.log || true
tail -n 120 FINAL_RESULTS_MMPBSA_GB_PB.dat || true
