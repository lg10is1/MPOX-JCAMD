#!/bin/bash
#SBATCH --job-name=mmpbsa_dbg_pbr3
#SBATCH --partition=<PARTITION>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --output=mmpbsa_pbr3_debug_%j.out
#SBATCH --error=mmpbsa_pbr3_debug_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

SYS="${SYS:-drugs3003}"
REP="${REP:-rep1}"
RUNDIR="$OUTROOT/$SYS/$REP"

echo "============================================================"
echo "[INFO] gmx_MMPBSA 3-frame debug test with PBRadii=3"
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
  echo "[HINT] Please run the gmx_MMPBSA input preparation script first."
  exit 1
fi

if [[ ! -s "$BASE/gmx_mmpbsa_container.path" ]]; then
  echo "[ERROR] Missing $BASE/gmx_mmpbsa_container.path"
  echo "[HINT] Run: bash 22C_find_gmx_mmpbsa_container.sh"
  exit 1
fi

if [[ ! -s "$BASE/container_engine.path" ]]; then
  echo "[ERROR] Missing $BASE/container_engine.path"
  echo "[HINT] Run: bash 22C_find_gmx_mmpbsa_container.sh"
  exit 1
fi

SIF="$(cat "$BASE/gmx_mmpbsa_container.path")"
CTR="$(cat "$BASE/container_engine.path")"

if [[ ! -s "$SIF" ]]; then
  echo "[ERROR] Container image not found or empty: $SIF"
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
    echo "[ERROR] Missing required file: $PWD/$f"
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
echo "[3] Clean previous failed gmx_MMPBSA files"
echo "============================================================"

rm -rf \
  _GMXMMPBSA_* \
  GMXMMPBSA_* \
  gmx_MMPBSA.log \
  FINAL_RESULTS_MMPBSA_GB_TEST.dat \
  FINAL_RESULTS_MMPBSA_GB_TEST.csv \
  mmpbsa_pbr3_debug_stdout_stderr.log \
  run_gmx_mmpbsa_pbr3_debug_inside_container.sh \
  COM.prmtop REC.prmtop LIG.prmtop \
  COM.inpcrd REC.inpcrd LIG.inpcrd \
  *.mdout \
  2>/dev/null || true

echo
echo "============================================================"
echo "[4] Write corrected 3-frame MM/GBSA input"
echo "============================================================"

cat > mmpbsa_gb_test_debug_pbr3.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_debug_PBRadii3",
  startframe=1,
  endframe=3,
  interval=1,
  verbose=3,
  keep_files=2,
  PBRadii=3,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

cat mmpbsa_gb_test_debug_pbr3.in

echo
echo "============================================================"
echo "[5] Write inside-container run script"
echo "============================================================"

cat > run_gmx_mmpbsa_pbr3_debug_inside_container.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "[inside] gmx_MMPBSA debug calculation, PBRadii=3"
echo "============================================================"
echo "[inside] Date: $(date)"
echo "[inside] Host: $(hostname)"
echo "[inside] Initial PWD=$(pwd)"
echo "[inside] GMX_MMPBSA_RUNDIR=${GMX_MMPBSA_RUNDIR:-NA}"

cd "${GMX_MMPBSA_RUNDIR:?GMX_MMPBSA_RUNDIR is not set}"

echo "[inside] After cd PWD=$(pwd)"
echo "[inside] Required files:"
ls -lh \
  md_100ns.tpr \
  topol.top \
  mmpbsa_index.ndx \
  mmpbsa_test_90_100_dt1000_fit.xtc \
  mmpbsa_gb_test_debug_pbr3.in

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
echo "[inside] gmx_MMPBSA version:"
gmx_MMPBSA --version 2>/dev/null || true

echo
echo "[inside] Start serial gmx_MMPBSA debug calculation..."

gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_test_debug_pbr3.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_test_90_100_dt1000_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
  -eo FINAL_RESULTS_MMPBSA_GB_TEST.csv \
  -nogui \
  2>&1 | tee mmpbsa_pbr3_debug_stdout_stderr.log

echo
echo "[inside] Finished debug calculation at $(date)"
EOF_RUN

chmod +x run_gmx_mmpbsa_pbr3_debug_inside_container.sh

echo
echo "============================================================"
echo "[6] Decide container bind mode"
echo "============================================================"
echo "[INFO] CTR=$CTR"
echo "[INFO] SIF=$SIF"
echo "[INFO] RUNDIR=$RUNDIR"

unset APPTAINER_BIND || true
unset SINGULARITY_BIND || true

BIND_ARGS=()

set +e
"$CTR" exec "$SIF" bash -lc "test -s '$RUNDIR/topol.top' && test -s '$RUNDIR/mmpbsa_index.ndx'"
PRECHECK_STATUS=$?
set -e

if [[ "$PRECHECK_STATUS" -eq 0 ]]; then
  echo "[INFO] Container can already see RUNDIR. No extra bind is needed."
else
  echo "[WARN] Container cannot see RUNDIR without bind. Use explicit bind."
  BIND_ARGS=(--bind /dssg:/dssg --bind /tmp:/tmp)
fi

echo
echo "============================================================"
echo "[7] Run direct container"
echo "============================================================"

"$CTR" exec \
  "${BIND_ARGS[@]}" \
  --env GMX_MMPBSA_RUNDIR="$RUNDIR" \
  "$SIF" \
  bash "$RUNDIR/run_gmx_mmpbsa_pbr3_debug_inside_container.sh"

echo
echo "============================================================"
echo "[8] Output check"
echo "============================================================"

if [[ ! -s "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.dat" ]]; then
  echo "[ERROR] FINAL_RESULTS_MMPBSA_GB_TEST.dat was not generated."
  echo "[INFO] Searching error messages:"
  grep -RniE \
    "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation|ValueError" \
    "$RUNDIR" 2>/dev/null || true
  exit 1
fi

ls -lh "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.dat"
ls -lh "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.csv" 2>/dev/null || true

echo
echo "============================================================"
echo "[9] Tail of result"
echo "============================================================"
tail -n 180 "$RUNDIR/FINAL_RESULTS_MMPBSA_GB_TEST.dat"

echo
echo "[DONE] Debug test finished successfully at $(date)"


