#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

echo "============================================================"
echo "[INFO] Creating PBRadii-fixed gmx_MMPBSA scripts"
echo "============================================================"
echo "[INFO] BASE=$BASE"

###############################################################################
# 22F_test_gmx_mmpbsa_direct_serial_debug_pbradii3.slurm
###############################################################################
cat > 22F_test_gmx_mmpbsa_direct_serial_debug_pbradii3.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_dbg_pbr3
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --output=mmpbsa_pbr3_debug_%j.out
#SBATCH --error=mmpbsa_pbr3_debug_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
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
  BIND_ARGS=(--bind <CLUSTER_FS>:<CLUSTER_FS> --bind /tmp:/tmp)
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
EOS
chmod +x 22F_test_gmx_mmpbsa_direct_serial_debug_pbradii3.slurm


###############################################################################
# 23F_gmx_mmpbsa_array_gb_direct_serial_pbradii3.slurm
###############################################################################
cat > 23F_gmx_mmpbsa_array_gb_direct_serial_pbradii3.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_gb_pbr3
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=4
#SBATCH --array=0-8%3
#SBATCH --output=mmpbsa_gb_pbr3_%A_%a.out
#SBATCH --error=mmpbsa_gb_pbr3_%A_%a.err

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
EOS
chmod +x 23F_gmx_mmpbsa_array_gb_direct_serial_pbradii3.slurm


###############################################################################
# 24F_check_gmx_mmpbsa_pbradii3_outputs.sh
###############################################################################
cat > 24F_check_gmx_mmpbsa_pbradii3_outputs.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
ROOT=<REDACTED>

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

cd "$BASE"

echo "============================================================"
echo "[INFO] Check gmx_MMPBSA PBRadii=3 outputs"
echo "============================================================"
date
echo

printf "%-10s %-5s %-9s %-9s %-9s %-9s %-s\n" \
  "system" "rep" "debugdat" "proddat" "prodcsv" "status" "path"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/$SYS/$REP"

    DEBUGDAT="NO"
    PRODDAT="NO"
    PRODCSV="NO"
    STATUS="FAIL"

    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB_TEST.dat" ]] && DEBUGDAT="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.dat" ]] && PRODDAT="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.csv" ]] && PRODCSV="YES"

    if [[ "$PRODDAT" == "YES" ]]; then
      STATUS="PASS"
    elif [[ "$DEBUGDAT" == "YES" ]]; then
      STATUS="DEBUG_ONLY"
    fi

    printf "%-10s %-5s %-9s %-9s %-9s %-9s %-s\n" \
      "$SYS" "$REP" "$DEBUGDAT" "$PRODDAT" "$PRODCSV" "$STATUS" "$D"
  done
done

echo
echo "============================================================"
echo "[INFO] Error keyword scan"
echo "============================================================"

grep -RniE \
  "MMPBSA_Error|Traceback|Fatal|ERROR|Error|not found|No such file|Cannot|could not|failed|ParmError|AmberError|InputError|cpptraj|sander|tleap|parmed|radii|PB Bomb|bad atom|molecule|topology|segmentation|ValueError" \
  "$ROOT"/*/*/mmpbsa_pbr3_*stdout_stderr.log \
  "$ROOT"/*/*/gmx_MMPBSA.log \
  "$ROOT"/*/*/*.mdout 2>/dev/null || echo "No obvious error keywords found."
EOS
chmod +x 24F_check_gmx_mmpbsa_pbradii3_outputs.sh


###############################################################################
# 27F_collect_gmx_mmpbsa_pbradii3_results.py
###############################################################################
cat > 27F_collect_gmx_mmpbsa_pbradii3_results.py <<'PY'
#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from statistics import mean, stdev

def parse_final_dat(path: Path):
    data = {}
    if not path.exists() or path.stat().st_size == 0:
        return data

    text = path.read_text(errors="ignore").splitlines()

    for line in text:
        s = line.strip()
        if not s:
            continue

        m = re.match(
            r"^(VDWAALS|EEL|EGB|ESURF|GGAS|GSOLV|DELTA\s+TOTAL)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?\s*"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?",
            s
        )

        if m:
            term = m.group(1).replace(" ", "_")
            avg = float(m.group(2))
            sd = float(m.group(3)) if m.group(3) is not None else None
            sem = float(m.group(4)) if m.group(4) is not None else None
            data[term] = {
                "mean_kcal_per_mol": avg,
                "sd_kcal_per_mol": sd,
                "sem_kcal_per_mol": sem,
            }

    return data

def safe_sd(values):
    if len(values) >= 2:
        return stdev(values)
    return 0.0

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    parser.add_argument("--out", default="gmx_mmpbsa_summary_pbradii3")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    systems = ["drugs2263", "drugs3003", "drugs3523"]
    reps = ["rep1", "rep2", "rep3"]

    long_rows = []

    for system in systems:
        for rep in reps:
            dat = root / system / rep / "FINAL_RESULTS_MMPBSA_GB.dat"
            parsed = parse_final_dat(dat)

            if not parsed:
                print(f"[MISS_OR_PARSE_FAIL] {dat}")
                continue

            for term, values in parsed.items():
                long_rows.append({
                    "system": system,
                    "rep": rep,
                    "term": term,
                    "mean_kcal_per_mol": values["mean_kcal_per_mol"],
                    "sd_kcal_per_mol": values["sd_kcal_per_mol"],
                    "sem_kcal_per_mol": values["sem_kcal_per_mol"],
                    "source": str(dat),
                })

    long_csv = out / "mmpbsa_gb_terms_by_rep.csv"
    with long_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "system",
                "rep",
                "term",
                "mean_kcal_per_mol",
                "sd_kcal_per_mol",
                "sem_kcal_per_mol",
                "source",
            ],
        )
        writer.writeheader()
        writer.writerows(long_rows)

    print(f"[WRITE] {long_csv}")

    grouped = {}
    for row in long_rows:
        grouped.setdefault((row["system"], row["term"]), []).append(
            float(row["mean_kcal_per_mol"])
        )

    summary_rows = []
    for (system, term), values in sorted(grouped.items()):
        summary_rows.append({
            "system": system,
            "term": term,
            "replicate_mean_kcal_per_mol": mean(values),
            "replicate_sd_kcal_per_mol": safe_sd(values),
            "n_reps": len(values),
        })

    summary_csv = out / "mmpbsa_gb_summary_by_system.csv"
    with summary_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "system",
                "term",
                "replicate_mean_kcal_per_mol",
                "replicate_sd_kcal_per_mol",
                "n_reps",
            ],
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"[WRITE] {summary_csv}")

    delta_rows = [r for r in summary_rows if r["term"] == "DELTA_TOTAL"]

    delta_csv = out / "mmpbsa_gb_delta_total_summary.csv"
    with delta_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "system",
                "term",
                "replicate_mean_kcal_per_mol",
                "replicate_sd_kcal_per_mol",
                "n_reps",
            ],
        )
        writer.writeheader()
        writer.writerows(delta_rows)

    print(f"[WRITE] {delta_csv}")

    print()
    print("DELTA_TOTAL summary:")
    if not delta_rows:
        print("[WARN] No DELTA_TOTAL rows parsed.")
    else:
        for r in delta_rows:
            print(
                f"{r['system']}: "
                f"{r['replicate_mean_kcal_per_mol']:.3f} ± "
                f"{r['replicate_sd_kcal_per_mol']:.3f} kcal/mol "
                f"(n={r['n_reps']})"
            )

if __name__ == "__main__":
    main()
PY
chmod +x 27F_collect_gmx_mmpbsa_pbradii3_results.py


echo
echo "============================================================"
echo "[DONE] Created fixed scripts"
echo "============================================================"
ls -lh \
  22F_test_gmx_mmpbsa_direct_serial_debug_pbradii3.slurm \
  23F_gmx_mmpbsa_array_gb_direct_serial_pbradii3.slurm \
  24F_check_gmx_mmpbsa_pbradii3_outputs.sh \
  27F_collect_gmx_mmpbsa_pbradii3_results.py
