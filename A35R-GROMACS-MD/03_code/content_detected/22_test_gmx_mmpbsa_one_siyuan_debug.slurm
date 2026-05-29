#!/bin/bash
#SBATCH --job-name=mmpbsa_dbg
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=8
#SBATCH --output=mmpbsa_debug_%j.out
#SBATCH --error=mmpbsa_debug_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

SYS="${SYS:-drugs3003}"
REP="${REP:-rep1}"

echo "============================================================"
echo "[INFO] gmx_MMPBSA debug test"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=$BASE"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"
echo "[INFO] SLURM_JOB_ID=${SLURM_JOB_ID:-NA}"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"

ulimit -l unlimited || true
ulimit -s unlimited || true

RUNDIR="$OUTROOT/$SYS/$REP"

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing directory: $RUNDIR"
  echo "[HINT] Run: bash 21_prepare_gmx_mmpbsa_inputs_v2.sh"
  exit 1
fi

cd "$RUNDIR"

echo
echo "============================================================"
echo "[1] Clean previous failed gmx_MMPBSA temporary files"
echo "============================================================"
rm -rf _GMXMMPBSA_* \
       GMXMMPBSA_* \
       gmx_MMPBSA.log \
       FINAL_RESULTS_MMPBSA_GB_TEST.dat \
       FINAL_RESULTS_MMPBSA_GB_TEST.csv \
       mmpbsa_debug_stdout_stderr.log \
       mdout.mdp 2>/dev/null || true

echo
echo "============================================================"
echo "[2] Required files"
echo "============================================================"
for f in \
  md_100ns.tpr \
  topol.top \
  mmpbsa_index.ndx \
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
echo "[3] Index groups"
echo "============================================================"
grep -n "^\[" mmpbsa_index.ndx || true
cat mmpbsa_index.report.txt 2>/dev/null || true

echo
echo "============================================================"
echo "[4] Write minimal 3-frame MM/GBSA input"
echo "============================================================"
cat > mmpbsa_gb_test_debug.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_debug",
  startframe=1,
  endframe=3,
  interval=1,
  verbose=3,
  keep_files=2,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

cat mmpbsa_gb_test_debug.in

echo
echo "============================================================"
echo "[5] Create run1.sh"
echo "============================================================"
cat > run1.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "[run1.sh] Inside Siyuan gmx_MMPBSA container"
echo "[run1.sh] PWD=$(pwd)"
echo "[run1.sh] DATE=$(date)"
echo "[run1.sh] PATH=$PATH"

echo "[run1.sh] Which programs:"
which gmx_MMPBSA || true
which MMPBSA.py || true
which cpptraj || true
which sander || true
which ante-MMPBSA.py || true
which parmed || true
which python || true
which python3 || true

echo "[run1.sh] Start gmx_MMPBSA debug calculation"

gmx_MMPBSA MPI \
  -O \
  -i mmpbsa_gb_test_debug.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_test_90_100_dt1000_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
  -nogui \
  2>&1 | tee mmpbsa_debug_stdout_stderr.log

echo "[run1.sh] gmx_MMPBSA finished"
echo "[run1.sh] DATE=$(date)"
EOF_RUN

chmod +x run1.sh
cat run1.sh

echo
echo "============================================================"
echo "[6] Load gmx_MMPBSA module"
echo "============================================================"

set +e
module load gmx_mmpbsa/1.5.6-gcc-9.3.0 2>/dev/null
LOAD_STATUS=$?
set -e

if [[ "$LOAD_STATUS" -ne 0 ]]; then
  echo "[WARN] gmx_mmpbsa/1.5.6 failed, trying 1.5.2"
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0
fi

module list 2>&1 || true

WRAP=""
if command -v gmx_MMPBSA_1.5.6 >/dev/null 2>&1; then
  WRAP="$(command -v gmx_MMPBSA_1.5.6)"
elif command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  WRAP="$(command -v gmx_MMPBSA_1.5.2)"
else
  echo "[ERROR] Cannot find gmx_MMPBSA_1.5.6 or gmx_MMPBSA_1.5.2 after module load."
  exit 1
fi

echo "[INFO] Wrapper=$WRAP"

echo
echo "============================================================"
echo "[7] Run Siyuan wrapper"
echo "============================================================"
"$WRAP"

echo
echo "============================================================"
echo "[8] Output check"
echo "============================================================"
ls -lah
ls -lh FINAL_RESULTS_MMPBSA_GB_TEST.dat 2>/dev/null || {
  echo "[ERROR] FINAL_RESULTS_MMPBSA_GB_TEST.dat was not generated."
  echo "[INFO] Search error messages:"
  grep -RniE "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology" . 2>/dev/null || true
  exit 1
}

echo
echo "[INFO] Tail of FINAL_RESULTS_MMPBSA_GB_TEST.dat:"
tail -n 120 FINAL_RESULTS_MMPBSA_GB_TEST.dat

echo
echo "[DONE] gmx_MMPBSA debug test finished at $(date)"
