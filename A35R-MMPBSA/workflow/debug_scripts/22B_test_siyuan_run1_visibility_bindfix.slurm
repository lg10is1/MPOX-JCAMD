#!/bin/bash
#SBATCH --job-name=mmpbsa_vis
#SBATCH --partition=<PARTITION>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --output=mmpbsa_visibility_%j.out
#SBATCH --error=mmpbsa_visibility_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

SYS="${SYS:-drugs3003}"
REP="${REP:-rep1}"

RUNDIR="$OUTROOT/$SYS/$REP"

echo "============================================================"
echo "[INFO] Siyuan gmx_MMPBSA container visibility test"
echo "============================================================"
echo "[INFO] Date: $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=$BASE"
echo "[INFO] RUNDIR=$RUNDIR"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"

if [[ ! -d "$RUNDIR" ]]; then
  echo "[ERROR] Missing RUNDIR=$RUNDIR"
  exit 1
fi

cd "$RUNDIR"

echo
echo "============================================================"
echo "[1] Check required files before container"
echo "============================================================"
for f in md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_test_90_100_dt1000_fit.xtc; do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo
echo "============================================================"
echo "[2] Load gmx_MMPBSA module"
echo "============================================================"

set +e
module purge 2>/dev/null
module load gmx_mmpbsa/1.5.6-gcc-9.3.0 2>/dev/null
LOAD_STATUS=$?
set -e

if [[ "$LOAD_STATUS" -ne 0 ]]; then
  echo "[WARN] gmx_mmpbsa/1.5.6 failed, trying 1.5.2"
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0
fi

module list 2>&1 || true

if command -v gmx_MMPBSA_1.5.6 >/dev/null 2>&1; then
  WRAP="$(command -v gmx_MMPBSA_1.5.6)"
elif command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  WRAP="$(command -v gmx_MMPBSA_1.5.2)"
else
  echo "[ERROR] Cannot find gmx_MMPBSA_1.5.6 or gmx_MMPBSA_1.5.2"
  exit 1
fi

echo "[INFO] Wrapper=$WRAP"

echo
echo "============================================================"
echo "[3] Force consistent Apptainer/Singularity bind paths"
echo "============================================================"

BIND_LIST="<CLUSTER_FS>:<CLUSTER_FS>,$BASE:$BASE,$RUNDIR:$RUNDIR,/tmp:/tmp"

export APPTAINER_BIND="$BIND_LIST"
export SINGULARITY_BIND="$BIND_LIST"
export APPTAINER_BINDPATH="$BIND_LIST"
export SINGULARITY_BINDPATH="$BIND_LIST"

export APPTAINERENV_GMX_MMPBSA_RUNDIR="$RUNDIR"
export SINGULARITYENV_GMX_MMPBSA_RUNDIR="$RUNDIR"

echo "[INFO] APPTAINER_BIND=$APPTAINER_BIND"
echo "[INFO] SINGULARITY_BIND=$SINGULARITY_BIND"
echo "[INFO] GMX_MMPBSA_RUNDIR=$RUNDIR"

echo
echo "============================================================"
echo "[4] Create run1.sh in both RUNDIR and BASE"
echo "============================================================"

cat > "$RUNDIR/run1.sh" <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "[run1.sh] Container visibility test"
echo "============================================================"
echo "[run1.sh] Date: $(date)"
echo "[run1.sh] Host: $(hostname)"
echo "[run1.sh] Initial PWD=$(pwd)"
echo "[run1.sh] GMX_MMPBSA_RUNDIR=${GMX_MMPBSA_RUNDIR:-NA}"

cd "${GMX_MMPBSA_RUNDIR:?GMX_MMPBSA_RUNDIR is not set}"

echo "[run1.sh] After cd PWD=$(pwd)"
echo "[run1.sh] Listing current directory:"
ls -lh

echo
echo "[run1.sh] Check required files inside container:"
for f in md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_test_90_100_dt1000_fit.xtc; do
  if [[ ! -s "$f" ]]; then
    echo "[run1.sh][ERROR] Missing file inside container: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo "RUN1_VISIBILITY_OK $(date)" > RUN1_VISIBILITY_OK.txt
echo "[run1.sh][OK] Container can see run1.sh and calculation files."
EOF_RUN

chmod +x "$RUNDIR/run1.sh"

cat > "$BASE/run1.sh" <<EOF_BASE_RUN
#!/bin/bash
set -euo pipefail
cd "$RUNDIR"
exec ./run1.sh
EOF_BASE_RUN

chmod +x "$BASE/run1.sh"

echo "[INFO] RUNDIR/run1.sh:"
ls -lh "$RUNDIR/run1.sh"
echo "[INFO] BASE/run1.sh:"
ls -lh "$BASE/run1.sh"

echo
echo "============================================================"
echo "[5] Run wrapper from RUNDIR"
echo "============================================================"

cd "$RUNDIR"
rm -f RUN1_VISIBILITY_OK.txt

"$WRAP"

echo
echo "============================================================"
echo "[6] Check visibility result"
echo "============================================================"

if [[ -s "$RUNDIR/RUN1_VISIBILITY_OK.txt" ]]; then
  cat "$RUNDIR/RUN1_VISIBILITY_OK.txt"
  echo "[OK] Container visibility test passed."
else
  echo "[ERROR] Container still cannot execute run1.sh correctly."
  exit 1
fi

echo "[DONE] Visibility test finished at $(date)"


