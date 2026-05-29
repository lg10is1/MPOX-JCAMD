#!/bin/bash
#SBATCH --job-name=mmpbsa_dbg_direct
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --output=mmpbsa_direct_debug_%j.out
#SBATCH --error=mmpbsa_direct_debug_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

SYS="${SYS:-drugs3003}"
REP="${REP:-rep1}"

RUNDIR="$OUTROOT/$SYS/$REP"

echo "============================================================"
echo "[INFO] Direct-container gmx_MMPBSA 3-frame debug test"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=$BASE"
echo "[INFO] RUNDIR=$RUNDIR"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"
echo "[INFO] SLURM_JOB_ID=${SLURM_JOB_ID:-NA}"
echo "[INFO] SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK:-NA}"

export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing RUNDIR=$RUNDIR"
  echo "[HINT] Run: bash 21_prepare_gmx_mmpbsa_inputs_v2.sh"
  exit 1
fi

cd "$BASE"

if [[ ! -s "$BASE/gmx_mmpbsa_container.path" || ! -s "$BASE/container_engine.path" ]]; then
  echo "[ERROR] Missing container path files."
  echo "[HINT] Run first: bash 22C_find_gmx_mmpbsa_container.sh"
  exit 1
fi

SIF="$(cat "$BASE/gmx_mmpbsa_container.path")"
CTR="$(cat "$BASE/container_engine.path")"

if [[ ! -s "$SIF" ]]; then
  echo "[ERROR] Container image missing: $SIF"
  exit 1
fi

if [[ ! -x "$CTR" ]]; then
  echo "[ERROR] Container engine not executable: $CTR"
  exit 1
fi

cd "$RUNDIR"

echo
echo "============================================================"
echo "[1] Check required input files"
echo "============================================================"

for f in md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_test_90_100_dt1000_fit.xtc; do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing file: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo
echo "============================================================"
echo "[2] Check index groups"
echo "============================================================"
grep -n "^\[" mmpbsa_index.ndx || true
cat mmpbsa_index.report.txt 2>/dev/null || true

echo
echo "============================================================"
echo "[3] Clean old debug outputs"
echo "============================================================"

rm -rf _GMXMMPBSA_* \
       GMXMMPBSA_* \
       gmx_MMPBSA.log \
       FINAL_RESULTS_MMPBSA_GB_TEST.dat \
       FINAL_RESULTS_MMPBSA_GB_TEST.csv \
       mmpbsa_direct_debug_stdout_stderr.log \
       run_gmx_mmpbsa_direct_debug_inside_container.sh 2>/dev/null || true

echo
echo "============================================================"
echo "[4] Write 3-frame MM/GBSA input"
echo "============================================================"

cat > mmpbsa_gb_test_debug.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_debug",
  startframe=1,
  endframe=3,
  interval=1,
  verbose=3,
  keep_files=2,
  PBRadii=mbondi2,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

cat mmpbsa_gb_test_debug.in

echo
echo "=================
==========================================="
echo "[5] Write inside-container run script"
echo "============================================================"

cat > run_gmx_mmpbsa_direct_debug_inside_container.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "[inside] Direct gmx_MMPBSA debug calculation"
echo "============================================================"
echo "[inside] Date: $(date)"
echo "[inside] Host: $(hostname)"
echo "[inside] Initial PWD=$(pwd)"
echo "[inside] GMX_MMPBSA_RUNDIR=${GMX_MMPBSA_RUNDIR:-NA}"

cd "${GMX_MMPBSA_RUNDIR:?GMX_MMPBSA_RUNDIR is not set}"

echo "[inside] After cd PWD=$(pwd)"
echo "[inside] Files:"
ls -lh md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_test_90_100_dt1000_fit.xtc mmpbsa_gb_test_debug.in

echo
echo "[inside] Program paths:"
which gmx_MMPBSA || true
which MMPBSA.py || true
which cpptraj || true
which sander || true
which parmed || true
which python || true
which python3 || true

echo
echo "[inside] gmx_MMPBSA version/help check:"
gmx_MMPBSA --version 2>/dev/null || true

echo
echo "[inside] Start serial gmx_MMPBSA..."
gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_test_debug.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_test_90_100_dt1000_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
  -nogui \
  2>&1 | tee mmpbsa_direct_debug_stdout_stderr.log

echo "[inside] Finished serial gmx_MMPBSA at $(date)"
EOF_RUN

chmod +x run_gmx_mmpbsa_direct_debug_inside_container.sh

echo
echo "============================================================"
echo "[6] Run direct apptainer/singularity exec"
echo "============================================================"
echo "[INFO] CTR=$CTR"
echo "[INFO] SIF=$SIF"
echo "[INFO] RUNDIR=$RUNDIR"

"$CTR" exec \
  --bind <CLUSTER_FS>:<CLUSTER_FS> \
  --bind /tmp:/tmp \
  --env GMX_MMPBSA_RUNDIR="$RUNDIR" \
  "$SIF" \
  bash "$RUNDIR/run_gmx_mmpbsa_direct_debug_inside_container.sh"

echo
echo "============================================================"
echo "[7] Output check"
echo "============================================================"

if [[ ! -s "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.dat" ]]; then
  echo "[ERROR] FINAL_RESULTS_MMPBSA_GB_TEST.dat was not generated."
  echo "[INFO] Searching error messages:"
  grep -RniE \
    "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation" \
    "$RUNDIR" 2>/dev/null || true
  exit 1
fi

ls -lh "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.dat"
tail -n 160 "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.dat"

echo
echo "[DONE] Direct-container debug test finished at $(date)"
