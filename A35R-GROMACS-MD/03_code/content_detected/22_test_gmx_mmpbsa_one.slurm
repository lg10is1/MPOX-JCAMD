#!/bin/bash
#SBATCH --job-name=mmpbsa_test
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
#SBATCH --output=mmpbsa_test_%j.out
#SBATCH --error=mmpbsa_test_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

SYS="${SYS:-drugs3003}"
REP="${REP:-rep1}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] SYS=$SYS REP=$REP"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"

cd "$OUTROOT/$SYS/$REP"

echo "[INFO] Loading gmx_MMPBSA environment"
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

echo "[INFO] Executables:"
which gmx_MMPBSA || true
which gmx || true
which mpirun || true
gmx_MMPBSA -v || true

NPROC="${SLURM_NTASKS:-16}"

echo "[INFO] Running quick GB test on about 11 frames"
if gmx_MMPBSA -h >/dev/null 2>&1; then
  mpirun -np "$NPROC" gmx_MMPBSA \
    -O \
    -i mmpbsa_gb_test.in \
    -cs md_100ns.tpr \
    -ct mmpbsa_test_90_100_dt1000_fit.xtc \
    -ci mmpbsa_index.ndx \
    -cg 0 1 \
    -cp topol.top \
    -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
    -eo FINAL_RESULTS_MMPBSA_GB_TEST.csv \
    -nogui > mmpbsa_gb_test.progress.log 2>&1
else
  gmx_MMPBSA MPI \
    -O \
    -i mmpbsa_gb_test.in \
    -cs md_100ns.tpr \
    -ct mmpbsa_test_90_100_dt1000_fit.xtc \
    -ci mmpbsa_index.ndx \
    -cg 0 1 \
    -cp topol.top \
    -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
    -eo FINAL_RESULTS_MMPBSA_GB_TEST.csv \
    -nogui > mmpbsa_gb_test.progress.log 2>&1
fi

echo "[INFO] Finished at $(date)"
ls -lh FINAL_RESULTS_MMPBSA_GB_TEST.dat FINAL_RESULTS_MMPBSA_GB_TEST.csv mmpbsa_gb_test.progress.log || true

echo "[INFO] Tail result:"
tail -n 80 FINAL_RESULTS_MMPBSA_GB_TEST.dat || true
