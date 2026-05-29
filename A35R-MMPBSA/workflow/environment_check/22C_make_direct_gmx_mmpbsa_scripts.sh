#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>"
cd "$BASE"

echo "[INFO] Creating direct-container gmx_MMPBSA scripts..."
echo "[INFO] BASE=$BASE"

###############################################################################
# 22C_find_gmx_mmpbsa_container.sh
###############################################################################
cat > 22C_find_gmx_mmpbsa_container.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>"
cd "$BASE"

echo "============================================================"
echo "[1] Basic information"
echo "============================================================"
pwd
hostname
date

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
  echo "[WARN] Cannot load gmx_mmpbsa/1.5.6-gcc-9.3.0, trying 1.5.2..."
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0
fi

module list 2>&1 || true

echo
echo "============================================================"
echo "[3] Locate wrapper"
echo "============================================================"

WRAP=""

if command -v gmx_MMPBSA_1.5.6 >/dev/null 2>&1; then
  WRAP="$(command -v gmx_MMPBSA_1.5.6)"
elif command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  WRAP="$(command -v gmx_MMPBSA_1.5.2)"
else
  echo "[ERROR] Cannot find gmx_MMPBSA_1.5.6 or gmx_MMPBSA_1.5.2"
  exit 1
fi

echo "[INFO] WRAP=$WRAP"
ls -lh "$WRAP"
file "$WRAP" || true

echo
echo "============================================================"
echo "[4] Show wrapper content, if text"
echo "============================================================"

head -n 80 "$WRAP" 2>/dev/null || true

echo
echo "============================================================"
echo "[5] Search container image path"
echo "============================================================"

SIF=""

# 1) Search wrapper as text
SIF="$(grep -Eo '/[^[:space:]"'"'"']+\.(sif|simg|img)' "$WRAP" 2>/dev/null | head -n 1 || true)"

# 2) Search wrapper strings
if [[ -z "$SIF" ]]; then
  SIF="$(strings "$WRAP" 2>/dev/null | grep -Eo '/[^[:space:]"'"'"']+\.(sif|simg|img)' | head -n 1 || true)"
fi

# 3) Search near wrapper directory
if [[ -z "$SIF" ]]; then
  WDIR="$(dirname "$WRAP")"
  SIF="$(find "$WDIR" "$(dirname "$WDIR")" -maxdepth 5 -type f \( -name "*.sif" -o -name "*.simg" -o -name "*.img" \) 2>/dev/null | head -n 1 || true)"
fi

# 4) Wider search under gmx_mmpbsa install directory
if [[ -z "$SIF" ]]; then
  INSTALL_ROOT="$(echo "$WRAP" | sed 's#/bin/.*##')"
  SIF="$(find "$INSTALL_ROOT" -type f \( -name "*.sif" -o -name "*.simg" -o -name "*.img" \) 2>/dev/null | head -n 1 || true)"
fi

# 5) Optional wider search under a user-supplied software root
if [[ -z "$SIF" ]]; then
  SIF="$(find "${GMX_MMPBSA_IMAGE_ROOT:-.}" -type f \( -name "*.sif" -o -name "*.simg" -o -name "*.img" \) 2>/dev/null | grep -Ei 'mmpbsa|gmx' | head -n 1 || true)"
fi

if [[ -z "$SIF" ]]; then
  echo "[ERROR] Cannot automatically locate gmx_MMPBSA container image."
  echo "[HINT] Please run:"
  echo "       grep -n . $WRAP"
  echo "       Set GMX_MMPBSA_IMAGE_ROOT and search for a gmx_MMPBSA container image."
  exit 1
fi

if [[ ! -s "$SIF" ]]; then
  echo "[ERROR] Detected image path does not exist or is empty:"
  echo "       $SIF"
  exit 1
fi

echo "[OK] Container image found:"
echo "$SIF"
ls -lh "$SIF"

echo "$SIF" > "$BASE/gmx_mmpbsa_container.path"

echo
echo "============================================================"
echo "[6] Check apptainer/singularity"
echo "============================================================"

if command -v apptainer >/dev/null 2>&1; then
  CTR="$(command -v apptainer)"
elif command -v singularity >/dev/null 2>&1; then
  CTR="$(command -v singularity)"
else
  echo "[ERROR] Neither apptainer nor singularity found."
  exit 1
fi

echo "[OK] Container engine: $CTR"
"$CTR" --version || true
echo "$CTR" > "$BASE/container_engine.path"

echo
echo "============================================================"
echo "[7] Quick command visibility inside container"
echo "============================================================"

"$CTR" exec \
  --bind <CLUSTER_FS>:<CLUSTER_FS> \
  "$SIF" \
  bash -lc '
    echo "[inside] PWD=$(pwd)"
    echo "[inside] PATH=$PATH"
    echo "[inside] gmx_MMPBSA:"
    which gmx_MMPBSA || true
    echo "[inside] MMPBSA.py:"
    which MMPBSA.py || true
    echo "[inside] cpptraj:"
    which cpptraj || true
    echo "[inside] sander:"
    which sander || true
    echo "[inside] python:"
    which python || true
    echo "[inside] python3:"
    which python3 || true
  '

echo
echo "============================================================"
echo "[DONE] Container detection finished"
echo "============================================================"
echo "[INFO] Image path saved to:"
echo "       $BASE/gmx_mmpbsa_container.path"
echo "[INFO] Engine path saved to:"
echo "       $BASE/container_engine.path"
EOS
chmod +x 22C_find_gmx_mmpbsa_container.sh


###############################################################################
# 22D_test_gmx_mmpbsa_direct_serial_debug.slurm
###############################################################################
cat > 22D_test_gmx_mmpbsa_direct_serial_debug.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_dbg_direct
#SBATCH --partition=<PARTITION>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --output=mmpbsa_direct_debug_%j.out
#SBATCH --error=mmpbsa_direct_debug_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>"
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
EOS
chmod +x 22D_test_gmx_mmpbsa_direct_serial_debug.slurm


###############################################################################
# 23D_gmx_mmpbsa_array_gb_direct_serial.slurm
###############################################################################
cat > 23D_gmx_mmpbsa_array_gb_direct_serial.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_gb_direct
#SBATCH --partition=<PARTITION>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --array=0-8%3
#SBATCH --output=mmpbsa_gb_direct_%A_%a.out
#SBATCH --error=mmpbsa_gb_direct_%A_%a.err

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
echo "[INFO] Direct-container gmx_MMPBSA MM/GBSA production"
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

for f in md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_50_100_dt500_fit.xtc; do
  if [[ ! -s "$f" ]]; then
    echo "[ERROR] Missing file: $PWD/$f"
    exit 1
  fi
  ls -lh "$f"
done

echo
echo "============================================================"
echo "[2] Clean old production outputs"
echo "============================================================"

rm -rf _GMXMMPBSA_* \
       GMXMMPBSA_* \
       gmx_MMPBSA.log \
       FINAL_RESULTS_MMPBSA_GB.dat \
       FINAL_RESULTS_MMPBSA_GB.csv \
       mmpbsa_direct_prod_stdout_stderr.log \
       run_gmx_mmpbsa_direct_prod_inside_container.sh 2>/dev/null || true

echo
echo "============================================================"
echo "[3] Write MM/GBSA production input"
echo "============================================================"

cat > mmpbsa_gb_prod.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_50_100ns",
  startframe=1,
  endframe=999999,
  interval=1,
  verbose=2,
  keep_files=0,
  PBRadii=mbondi2,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

cat mmpbsa_gb_prod.in

echo
echo "============================================================"
echo "[4] Write inside-container production script"
echo "============================================================"

cat > run_gmx_mmpbsa_direct_prod_inside_container.sh <<'EOF_RUN'
#!/bin/bash
set -euo pipefail

echo "============================================================"
echo "[inside] Direct gmx_MMPBSA MM/GBSA production"
echo "============================================================"
echo "[inside] Date: $(date)"
echo "[inside] Host: $(hostname)"
echo "[inside] Initial PWD=$(pwd)"
echo "[inside] GMX_MMPBSA_RUNDIR=${GMX_MMPBSA_RUNDIR:-NA}"

cd "${GMX_MMPBSA_RUNDIR:?GMX_MMPBSA_RUNDIR is not set}"

echo "[inside] After cd PWD=$(pwd)"
echo "[inside] Required files:"
ls -lh md_100ns.tpr topol.top mmpbsa_index.ndx mmpbsa_50_100_dt500_fit.xtc mmpbsa_gb_prod.in

echo
echo "[inside] Program paths:"
which gmx_MMPBSA || true
which MMPBSA.py || true
which cpptraj || true
which sander || true
which parmed || true

echo
echo "[inside] Start serial gmx_MMPBSA production..."
gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_prod.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB.dat \
  -nogui \
  2>&1 | tee mmpbsa_direct_prod_stdout_stderr.log

echo "[inside] Finished serial gmx_MMPBSA production at $(date)"
EOF_RUN

chmod +x run_gmx_mmpbsa_direct_prod_inside_container.sh

echo
echo "============================================================"
echo "[5] Run direct container"
echo "============================================================"
echo "[INFO] CTR=$CTR"
echo "[INFO] SIF=$SIF"
echo "[INFO] RUNDIR=$RUNDIR"

"$CTR" exec \
  --bind <CLUSTER_FS>:<CLUSTER_FS> \
  --bind /tmp:/tmp \
  --env GMX_MMPBSA_RUNDIR="$RUNDIR" \
  "$SIF" \
  bash "$RUNDIR/run_gmx_mmpbsa_direct_prod_inside_container.sh"

echo
echo "============================================================"
echo "[6] Output check"
echo "============================================================"

if [[ ! -s FINAL_RESULTS_MMPBSA_GB.dat ]]; then
  echo "[ERROR] FINAL_RESULTS_MMPBSA_GB.dat was not generated."
  echo "[INFO] Searching error messages:"
  grep -RniE \
    "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation" \
    . 2>/dev/null || true
  exit 1
fi

ls -lh FINAL_RESULTS_MMPBSA_GB.dat
tail -n 160 FINAL_RESULTS_MMPBSA_GB.dat

echo
echo "[DONE] Finished $SYS $REP at $(date)"
EOS
chmod +x 23D_gmx_mmpbsa_array_gb_direct_serial.slurm


###############################################################################
# 24D_check_gmx_mmpbsa_direct_outputs.sh
###############################################################################
cat > 24D_check_gmx_mmpbsa_direct_outputs.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>"
ROOT="$BASE/gmx_mmpbsa_50_100ns"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

cd "$BASE"

printf "%-10s %-5s %-8s %-8s %-8s %-8s %-s\n" \
  "system" "rep" "debug" "GB" "log" "status" "path"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/$SYS/$REP"

    DEBUG="NO"
    GB="NO"
    LOG="NO"
    STATUS="FAIL"

    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB_TEST.dat" ]] && DEBUG="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.dat" ]] && GB="YES"
    [[ -s "$D/mmpbsa_direct_prod_stdout_stderr.log" || -s "$D/mmpbsa_direct_debug_stdout_stderr.log" ]] && LOG="YES"

    if [[ "$GB" == "YES" ]]; then
      STATUS="PASS"
    elif [[ "$DEBUG" == "YES" ]]; then
      STATUS="DEBUG_ONLY"
    fi

    printf "%-10s %-5s %-8s %-8s %-8s %-8s %-s\n" \
      "$SYS" "$REP" "$DEBUG" "$GB" "$LOG" "$STATUS" "$D"
  done
done

echo
echo "============================================================"
echo "[INFO] Dangerous/error keyword scan"
echo "============================================================"

grep -RniE \
  "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation" \
  "$ROOT"/*/*/mmpbsa_direct_*stdout_stderr.log \
  "$ROOT"/*/*/gmx_MMPBSA.log \
  "$ROOT"/*/*/*.mdout 2>/dev/null || echo "No obvious error keywords found."
EOS
chmod +x 24D_check_gmx_mmpbsa_direct_outputs.sh


###############################################################################
# 27D_collect_gmx_mmpbsa_delta_total.py
###############################################################################
cat > 27D_collect_gmx_mmpbsa_delta_total.py <<'PY'
#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from statistics import mean, stdev

def parse_mmpbsa_dat(path: Path):
    """
    Parse FINAL_RESULTS_MMPBSA_GB.dat.
    Typical lines:
      VDWAALS          -xx.xx     sd     sem
      EEL              -xx.xx     sd     sem
      EGB               xx.xx     sd     sem
      ESURF             xx.xx     sd     sem
      DELTA TOTAL      -xx.xx     sd     sem
    """
    rows = {}
    if not path.exists():
        return rows

    for line in path.read_text(errors="ignore").splitlines():
        s = line.strip()
        if not s:
            continue

        # Match energy term with average, SD, SEM
        # Supports "DELTA TOTAL" as a two-word term.
        m = re.match(
            r"^(DELTA\s+TOTAL|VDWAALS|EEL|EGB|ESURF|GGAS|GSOLV|DELTA\s+G\s+gas|DELTA\s+G\s+solv)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?\s*"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?",
            s
        )
        if m:
            term = re.sub(r"\s+", "_", m.group(1).strip())
            avg = float(m.group(2))
            sd = float(m.group(3)) if m.group(3) is not None else None
            sem = float(m.group(4)) if m.group(4) is not None else None
            rows[term] = {"avg": avg, "sd": sd, "sem": sem}

    return rows

def safe_sd(vals):
    return stdev(vals) if len(vals) >= 2 else 0.0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    ap.add_argument("--out", default="gmx_mmpbsa_summary_direct")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    systems = ["drugs2263", "drugs3003", "drugs3523"]
    reps = ["rep1", "rep2", "rep3"]

    long_rows = []

    for sysname in systems:
        for rep in reps:
            dat = root / sysname / rep / "FINAL_RESULTS_MMPBSA_GB.dat"
            parsed = parse_mmpbsa_dat(dat)

            if not parsed:
                print(f"[MISS_OR_PARSE_FAIL] {dat}")
                continue

            for term, vals in parsed.items():
                long_rows.append({
                    "system": sysname,
                    "rep": rep,
                    "term": term,
                    "mean_kcal_per_mol": vals["avg"],
                    "sd_kcal_per_mol": vals["sd"],
                    "sem_kcal_per_mol": vals["sem"],
                    "source": str(dat),
                })

    long_csv = out / "mmpbsa_gb_terms_by_rep.csv"
    with long_csv.open("w", newline="") as f:
        fieldnames = [
            "system", "rep", "term",
            "mean_kcal_per_mol", "sd_kcal_per_mol", "sem_kcal_per_mol",
            "source"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(long_rows)

    print(f"[WRITE] {long_csv}")

    # System summary by term across 3 repeats
    summary_rows = []
    by_key = {}

    for row in long_rows:
        key = (row["system"], row["term"])
        by_key.setdefault(key, []).append(float(row["mean_kcal_per_mol"]))

    for (sysname, term), vals in sorted(by_key.items()):
        summary_rows.append({
            "system": sysname,
            "term": term,
            "replicate_mean_kcal_per_mol": mean(vals),
            "replicate_sd_kcal_per_mol": safe_sd(vals),
            "n_reps": len(vals),
        })

    summary_csv = out / "mmpbsa_gb_summary_by_system.csv"
    with summary_csv.open("w", newline="") as f:
        fieldnames = [
            "system", "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"[WRITE] {summary_csv}")

    # Extract DELTA_TOTAL only
    delta_rows = [r for r in summary_rows if r["term"] == "DELTA_TOTAL"]
    delta_csv = out / "mmpbsa_gb_delta_total_summary.csv"
    with delta_csv.open("w", newline="") as f:
        fieldnames = [
            "system", "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(delta_rows)

    print(f"[WRITE] {delta_csv}")

    print("\nDELTA_TOTAL summary:")
    for r in delta_rows:
        print(
            f"{r['system']}: "
            f"{r['replicate_mean_kcal_per_mol']:.3f} 卤 "
            f"{r['replicate_sd_kcal_per_mol']:.3f} kcal/mol "
            f"(n={r['n_reps']})"
        )

if __name__ == "__main__":
    main()
PY
chmod +x 27D_collect_gmx_mmpbsa_delta_total.py


echo
echo "============================================================"
echo "[DONE] Scripts created"
echo "============================================================"
ls -lh \
  22C_find_gmx_mmpbsa_container.sh \
  22D_test_gmx_mmpbsa_direct_serial_debug.slurm \
  23D_gmx_mmpbsa_array_gb_direct_serial.slurm \
  24D_check_gmx_mmpbsa_direct_outputs.sh \
  27D_collect_gmx_mmpbsa_delta_total.py

