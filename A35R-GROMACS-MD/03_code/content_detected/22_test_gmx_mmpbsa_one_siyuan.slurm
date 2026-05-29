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

echo "============================================================"
echo "[INFO] gmx_MMPBSA quick test"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=$BASE"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"

RUNDIR="$OUTROOT/$SYS/$REP"

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing directory: $RUNDIR"
  echo "[HINT] Please run: bash 21_prepare_gmx_mmpbsa_inputs.sh"
  exit 1
fi

cd "$RUNDIR"

echo
echo "============================================================"
echo "[INFO] Check required input files"
echo "============================================================"
for f in \
  md_100ns.tpr \
  topol.top \
  mmpbsa_index.ndx \
  mmpbsa_gb_test.in \
  mmpbsa_test_90_100_dt1000_fit.xtc
do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing required file: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo
echo "============================================================"
echo "[INFO] Create run1.sh for Siyuan gmx_MMPBSA container"
echo "============================================================"

cat > run1.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "[run1.sh] Inside gmx_MMPBSA container"
echo "[run1.sh] Working directory: $(pwd)"
echo "[run1.sh] Date: $(date)"

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
  -nogui
EOF_RUN

chmod +x run1.sh
cat run1.sh

echo
echo "============================================================"
echo "[INFO] Load and run Siyuan gmx_MMPBSA module"
echo "============================================================"
module load gmx_mmpbsa/1.5.2-gcc-9.3.0
module list 2>&1 || true

which gmx_MMPBSA_1.5.2 || {
  echo "[ERROR] gmx_MMPBSA_1.5.2 not found after module load."
  exit 1
}

echo "[INFO] Running gmx_MMPBSA_1.5.2 ..."
gmx_MMPBSA_1.5.2

echo
echo "============================================================"
echo "[INFO] Check outputs"
echo "============================================================"
ls -lh FINAL_RESULTS_MMPBSA_GB_TEST.dat FINAL_RESULTS_MMPBSA_GB_TEST.csv 2>/dev/null || true

echo
echo "[INFO] Tail of FINAL_RESULTS_MMPBSA_GB_TEST.dat:"
tail -n 100 FINAL_RESULTS_MMPBSA_GB_TEST.dat 2>/dev/null || true

echo
echo "[DONE] Quick test finished at $(date)"
