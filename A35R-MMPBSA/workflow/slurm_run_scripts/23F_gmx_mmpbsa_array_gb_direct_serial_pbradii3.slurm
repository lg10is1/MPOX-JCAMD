#!/bin/bash
#SBATCH --job-name=mmpbsa_gb_pbr3
#SBATCH --partition=<PARTITION>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --array=0-8%9
#SBATCH --output=mmpbsa_gb_pbr3_%A_%a.out
#SBATCH --error=mmpbsa_gb_pbr3_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>"
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
RUNDIR="$OUTROOT/$SYS/$REP"

echo "============================================================"
echo "[INFO] gmx_MMPBSA MM/GBSA production with PBRadii=3"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] Array task: $SLURM_ARRAY_TASK_ID"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"
echo "[INFO] RUNDIR=$RUNDIR"
echo "[INFO] SLURM_JOB_ID=${SLURM_JOB_ID:-NA}"

export OMP_NUM_THREADS=1
export MKL_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing RUNDIR=$RUNDIR"
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

for f in md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_50_100_dt500_fit.xtc; do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing required file: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo
echo "============================================================"
echo "[2] Clean previous gmx_MMPBSA production files"
echo "============================================================"

rm -rf \
  _GMXMMPBSA_* \
  GMXMMPBSA_* \
  gmx_MMPBSA.log \
  FINAL_RESULTS_MMPBSA_GB.dat \
  FINAL_RESULTS_MMPBSA_GB.csv \
  mmpbsa_pbr3_prod_stdout_stderr.log \
  run_gmx_mmpbsa_pbr3_prod_inside_container.sh \
  COM.prmtop REC.prmtop LIG.prmtop \
  COM.inpcrd REC.inpcrd LIG.inpcrd \
  *.mdout \
  2>/dev/null || true

echo
echo "============================================================"
echo "[3] Write corrected MM/GBSA production input"
echo "============================================================"

cat > mmpbsa_gb_prod_pbr3.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_50_100ns_PBRadii3",
  startframe=1,
  endframe=999999,
  interval=1,
  verbose=2,
  keep_files=0,
  PBRadii=3,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

cat mmpbsa_gb_prod_pbr3.in

echo
echo "============================================================"
echo "[4] Write inside-container production script"
echo "============================================================"

cat > run_gmx_mmpbsa_pbr3_prod_inside_container.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "[inside] gmx_MMPBSA production calculation, PBRadii=3"
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
  mmpbsa_50_100_dt500_fit.xtc \
  mmpbsa_gb_prod_pbr3.in

echo
echo "[inside] Program paths:"
which gmx_MMPBSA || true
which MMPBSA.py || true
which cpptraj || true
which sander || true
which parmed || true

echo
echo "[inside] gmx_MMPBSA version:"
gmx_MMPBSA --version 2>/dev/null || true

echo
echo "[inside] Start serial gmx_MMPBSA production calculation..."

gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_prod_pbr3.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB.csv \
  -nogui \
  2>&1 | tee mmpbsa_pbr3_prod_stdout_stderr.log

echo
echo "[inside] Finished production calculation at $(date)"
EOF_RUN

chmod +x run_gmx_mmpbsa_pbr3_prod_inside_container.sh

echo
echo "============================================================"
echo "[5] Decide container bind mode"
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
  BIND_ARGS=(--bind <CLUSTER_FS>:<CLUSTER_FS> --bind /tmp:/tmp)
fi

echo
echo "============================================================"
echo "[6] Run direct container"
echo "============================================================"

"$CTR" exec \
  "${BIND_ARGS[@]}" \
  --env GMX_MMPBSA_RUNDIR="$RUNDIR" \
  "$SIF" \
  bash "$RUNDIR/run_gmx_mmpbsa_pbr3_prod_inside_container.sh"

echo
echo "============================================================"
echo "[7] Output check"
echo "============================================================"

if [[ ! -s "$RUNDIR/FINAL_RESULTS_MMPBSA_GB.dat" ]]; then
  echo "[ERROR] FINAL_RESULTS_MMPBSA_GB.dat was not generated."
  echo "[INFO] Searching error messages:"
  grep -RniE \
    "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation|ValueError" \
    "$RUNDIR" 2>/dev/null || true
  exit 1
fi

ls -lh "$RUNDIR/FINAL_RESULTS_MMPBSA_GB.dat"
ls -lh "$RUNDIR/FINAL_RESULTS_MMPBSA_GB.csv" 2>/dev/null || true

echo
echo "============================================================"
echo "[8] Tail of result"
echo "============================================================"
tail -n 180 "$RUNDIR/FINAL_RESULTS_MMPBSA_GB.dat"

echo
echo "[DONE] Finished $SYS $REP at $(date)"


