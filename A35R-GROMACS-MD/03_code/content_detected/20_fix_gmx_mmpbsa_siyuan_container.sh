#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

echo "[INFO] Fixing gmx_MMPBSA scripts for Siyuan container module..."
echo "[INFO] BASE=$BASE"

###############################################################################
# 20_check_gmx_mmpbsa_siyuan_module.sh
###############################################################################
cat > 20_check_gmx_mmpbsa_siyuan_module.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

echo "============================================================"
echo "[1] Basic information"
echo "============================================================"
pwd
hostname
date

echo
echo "============================================================"
echo "[2] Available gmx_MMPBSA modules"
echo "============================================================"
module avail gmx_mmpbsa 2>&1 || true
module avail gmx_MMPBSA 2>&1 || true

echo
echo "============================================================"
echo "[3] Load Siyuan container module"
echo "============================================================"
module load gmx_mmpbsa/1.5.2-gcc-9.3.0

echo "[INFO] Loaded modules:"
module list 2>&1 || true

echo
echo "============================================================"
echo "[4] Check wrapper command"
echo "============================================================"
echo "[INFO] Do NOT execute gmx_MMPBSA_1.5.2 here."
echo "[INFO] This wrapper expects ./run1.sh in the current calculation directory."

echo
printf "%-30s : " "gmx_MMPBSA_1.5.2"
command -v gmx_MMPBSA_1.5.2 || true

echo
echo "[INFO] All gmx_MMPBSA-like commands in PATH:"
compgen -c | grep -E "gmx.*MMPBSA|MMPBSA" | sort -u || true

echo
echo "============================================================"
echo "[5] Check GROMACS module for trajectory preprocessing"
echo "============================================================"
module load oneapi 2>/dev/null || true
module load gromacs/2021.3-intel-2021.4.0 2>/dev/null || true

printf "%-30s : " "gmx_mpi"
command -v gmx_mpi || true

if command -v gmx_mpi >/dev/null 2>&1; then
  gmx_mpi --version | head -n 25 || true
fi

echo
echo "============================================================"
echo "[6] Conclusion"
echo "============================================================"
echo "[OK] If gmx_MMPBSA_1.5.2 path is shown above, the module is usable."
echo "[OK] Real calculation must be submitted by SLURM and must create run1.sh in each run directory."
echo "[OK] Missing host command 'gmx_MMPBSA' is normal for this container version."
echo "[OK] Missing mpi4py in amber_rebuild is irrelevant for this container version."
EOS
chmod +x 20_check_gmx_mmpbsa_siyuan_module.sh

###############################################################################
# 22_test_gmx_mmpbsa_one_siyuan.slurm
###############################################################################
cat > 22_test_gmx_mmpbsa_one_siyuan.slurm <<'EOS'
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
EOS
chmod +x 22_test_gmx_mmpbsa_one_siyuan.slurm

###############################################################################
# 23_gmx_mmpbsa_array_gb_siyuan.slurm
###############################################################################
cat > 23_gmx_mmpbsa_array_gb_siyuan.slurm <<'EOS'
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
EOS
chmod +x 23_gmx_mmpbsa_array_gb_siyuan.slurm

###############################################################################
# 24_gmx_mmpbsa_array_gbpb_siyuan.slurm
###############################################################################
cat > 24_gmx_mmpbsa_array_gbpb_siyuan.slurm <<'EOS'
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
EOS
chmod +x 24_gmx_mmpbsa_array_gbpb_siyuan.slurm

###############################################################################
# 25_gmx_mmpbsa_array_decomp_gb_siyuan.slurm
###############################################################################
cat > 25_gmx_mmpbsa_array_decomp_gb_siyuan.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_decomp
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=32
#SBATCH --array=0-8
#SBATCH --output=mmpbsa_decomp_%A_%a.out
#SBATCH --error=mmpbsa_decomp_%A_%a.err

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
echo "[INFO] gmx_MMPBSA MM/GBSA residue decomposition"
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
  mmpbsa_decomp_gb.in \
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
  -i mmpbsa_decomp_gb.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_DECOMP_GB.dat \
  -do FINAL_DECOMP_MMPBSA_GB.dat \
  -eo FINAL_RESULTS_MMPBSA_DECOMP_GB.csv \
  -deo FINAL_DECOMP_MMPBSA_GB.csv \
  -nogui
EOF_RUN

chmod +x run1.sh
cat run1.sh

module load gmx_mmpbsa/1.5.2-gcc-9.3.0
module list 2>&1 || true
which gmx_MMPBSA_1.5.2

gmx_MMPBSA_1.5.2

ls -lh FINAL_RESULTS_MMPBSA_DECOMP_GB.dat FINAL_DECOMP_MMPBSA_GB.dat FINAL_DECOMP_MMPBSA_GB.csv 2>/dev/null || true
tail -n 160 FINAL_DECOMP_MMPBSA_GB.dat 2>/dev/null || true

echo "[DONE] Finished $SYS $REP at $(date)"
EOS
chmod +x 25_gmx_mmpbsa_array_decomp_gb_siyuan.slurm

echo
echo "[DONE] New Siyuan-compatible scripts generated:"
ls -lh \
  20_check_gmx_mmpbsa_siyuan_module.sh \
  22_test_gmx_mmpbsa_one_siyuan.slurm \
  23_gmx_mmpbsa_array_gb_siyuan.slurm \
  24_gmx_mmpbsa_array_gbpb_siyuan.slurm \
  25_gmx_mmpbsa_array_decomp_gb_siyuan.slurm
