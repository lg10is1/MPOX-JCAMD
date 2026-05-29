#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Backup GROMACS MD production + analysis outputs into a new clean folder.
#
# Default:
#   - copy scripts, logs, tpr/gro/edr, analysis csv/xvg, summary tables, MD figures
#   - do NOT copy large trajectories or checkpoint files
#
# Optional:
#   COPY_TRAJ=1 COPY_RESTART=1 bash 33_backup_gromacs_md_analysis.sh
#   CREATE_TAR=1 bash 33_backup_gromacs_md_analysis.sh
###############################################################################

AMBER_ROOT="<USER_HOME>/1_projects/PRP-MPOX-JCAMD/JCAMD-R1/AMBER"
SRC="${AMBER_ROOT}/A35R-gromacs"

DATE_TAG="$(date +%Y%m%d_%H%M%S)"
DEST="${DEST:-${AMBER_ROOT}/A35R-gromacs-GROMACS-analysis-backup_${DATE_TAG}}"

COPY_TRAJ="${COPY_TRAJ:-0}"
COPY_RESTART="${COPY_RESTART:-0}"
CREATE_TAR="${CREATE_TAR:-0}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

echo "============================================================"
echo "[INFO] Backup GROMACS MD analysis"
echo "============================================================"
echo "[INFO] SRC=$SRC"
echo "[INFO] DEST=$DEST"
echo "[INFO] COPY_TRAJ=$COPY_TRAJ"
echo "[INFO] COPY_RESTART=$COPY_RESTART"
echo "[INFO] CREATE_TAR=$CREATE_TAR"
echo "[INFO] Date=$(date)"
echo "[INFO] Host=$(hostname)"
echo

if [[ ! -d "$SRC" ]]; then
  echo "[ERROR] Source directory does not exist:"
  echo "$SRC"
  exit 1
fi

if [[ -e "$DEST" ]]; then
  echo "[ERROR] Destination already exists:"
  echo "$DEST"
  echo "[HINT] Use another destination, for example:"
  echo "DEST=${DEST}_new bash 33_backup_gromacs_md_analysis.sh"
  exit 1
fi

mkdir -p "$DEST"

###############################################################################
# Helper functions
###############################################################################

copy_file_if_exists() {
  local src_file="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  if [[ -f "$src_file" ]]; then
    cp -p "$src_file" "$dest_dir"/
    echo "[COPY] $src_file -> $dest_dir/"
  fi
}

copy_glob_if_exists() {
  local pattern="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  shopt -s nullglob
  local files=( $pattern )
  shopt -u nullglob

  local f
  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      cp -p "$f" "$dest_dir"/
      echo "[COPY] $f -> $dest_dir/"
    fi
  done
}

copy_dir_if_exists() {
  local src_dir="$1"
  local dest_dir="$2"

  if [[ -d "$src_dir" ]]; then
    mkdir -p "$dest_dir"
    rsync -a "$src_dir"/ "$dest_dir"/
    echo "[RSYNC] $src_dir/ -> $dest_dir/"
  fi
}

###############################################################################
# Directory structure
###############################################################################

mkdir -p \
  "$DEST/00_project_overview" \
  "$DEST/01_gromacs_input_systems" \
  "$DEST/02_short_test_results" \
  "$DEST/03_100ns_md_metadata" \
  "$DEST/04_100ns_md_logs" \
  "$DEST/05_100ns_final_structures" \
  "$DEST/06_per_rep_analysis_outputs" \
  "$DEST/07_combined_analysis_tables" \
  "$DEST/08_md_figures" \
  "$DEST/09_scripts" \
  "$DEST/10_quality_control" \
  "$DEST/11_optional_trajectories" \
  "$DEST/99_manifest"

###############################################################################
# 1. Copy GROMACS input systems
###############################################################################

echo
echo "============================================================"
echo "[STEP 1] Copy GROMACS input systems"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  IN_SRC="$SRC/gmx_test_cpu/$SYS"
  IN_DEST="$DEST/01_gromacs_input_systems/$SYS"

  mkdir -p "$IN_DEST"

  copy_file_if_exists "$IN_SRC/conf.gro" "$IN_DEST"
  copy_file_if_exists "$IN_SRC/topol.top" "$IN_DEST"
  copy_file_if_exists "$IN_SRC/index.ndx" "$IN_DEST"

  copy_glob_if_exists "$IN_SRC/*.itp" "$IN_DEST"
  copy_glob_if_exists "$IN_SRC/conversion_report.*" "$IN_DEST"
done

###############################################################################
# 2. Copy short test results
###############################################################################

echo
echo "============================================================"
echo "[STEP 2] Copy short GROMACS CPU test results"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  D="$SRC/gmx_test_cpu/$SYS"
  OUT="$DEST/02_short_test_results/$SYS"
  mkdir -p "$OUT"

  copy_file_if_exists "$D/em.tpr" "$OUT"
  copy_file_if_exists "$D/em.gro" "$OUT"
  copy_file_if_exists "$D/em.edr" "$OUT"
  copy_file_if_exists "$D/em.log" "$OUT"

  copy_file_if_exists "$D/nvt_20ps.tpr" "$OUT"
  copy_file_if_exists "$D/nvt_20ps.gro" "$OUT"
  copy_file_if_exists "$D/nvt_20ps.edr" "$OUT"
  copy_file_if_exists "$D/nvt_20ps.log" "$OUT"

  copy_file_if_exists "$D/npt_20ps.tpr" "$OUT"
  copy_file_if_exists "$D/npt_20ps.gro" "$OUT"
  copy_file_if_exists "$D/npt_20ps.edr" "$OUT"
  copy_file_if_exists "$D/npt_20ps.log" "$OUT"

  copy_file_if_exists "$D/md_20ps.tpr" "$OUT"
  copy_file_if_exists "$D/md_20ps.gro" "$OUT"
  copy_file_if_exists "$D/md_20ps.edr" "$OUT"
  copy_file_if_exists "$D/md_20ps.log" "$OUT"

  copy_glob_if_exists "$D/*_out.mdp" "$OUT"
  copy_glob_if_exists "$D/*seeded.mdp" "$OUT"

  if [[ "$COPY_TRAJ" == "1" ]]; then
    mkdir -p "$OUT/trajectories"
    copy_glob_if_exists "$D/*.xtc" "$OUT/trajectories"
    copy_glob_if_exists "$D/*.trr" "$OUT/trajectories"
  fi

  if [[ "$COPY_RESTART" == "1" ]]; then
    mkdir -p "$OUT/restarts"
    copy_glob_if_exists "$D/*.cpt" "$OUT/restarts"
  fi
done

###############################################################################
# 3. Copy 100 ns production metadata, logs, final structures
###############################################################################

echo
echo "============================================================"
echo "[STEP 3] Copy 100 ns MD production metadata/logs/final structures"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$SRC/gmx_md100_3rep/$SYS/$REP"

    META="$DEST/03_100ns_md_metadata/$SYS/$REP"
    LOGD="$DEST/04_100ns_md_logs/$SYS/$REP"
    FINAL="$DEST/05_100ns_final_structures/$SYS/$REP"
    TRAJ="$DEST/11_optional_trajectories/$SYS/$REP"

    mkdir -p "$META" "$LOGD" "$FINAL"

    copy_file_if_exists "$D/topol.top" "$META"
    copy_file_if_exists "$D/index.ndx" "$META"
    copy_file_if_exists "$D/md_100ns.tpr" "$META"
    copy_file_if_exists "$D/md_100ns.mdp" "$META"
    copy_file_if_exists "$D/md_100ns_out.mdp" "$META"
    copy_file_if_exists "$D/npt_20ps.gro" "$META"
    copy_file_if_exists "$D/nvt_20ps.gro" "$META"
    copy_file_if_exists "$D/em.gro" "$META"

    copy_file_if_exists "$D/md_100ns.log" "$LOGD"
    copy_glob_if_exists "$D/*.out" "$LOGD"
    copy_glob_if_exists "$D/*.err" "$LOGD"

    copy_file_if_exists "$D/md_100ns.gro" "$FINAL"
    copy_file_if_exists "$D/md_100ns.edr" "$FINAL"

    if [[ "$COPY_RESTART" == "1" ]]; then
      mkdir -p "$FINAL/restarts"
      copy_glob_if_exists "$D/*.cpt" "$FINAL/restarts"
    fi

    if [[ "$COPY_TRAJ" == "1" ]]; then
      mkdir -p "$TRAJ"
      copy_glob_if_exists "$D/*.xtc" "$TRAJ"
      copy_glob_if_exists "$D/*.trr" "$TRAJ"
      copy_glob_if_exists "$D/analysis/*.xtc" "$TRAJ/analysis_processed_xtc"
    fi
  done
done

###############################################################################
# 4. Copy per-replicate analysis outputs
###############################################################################

echo
echo "============================================================"
echo "[STEP 4] Copy per-replicate GROMACS analysis outputs"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    A_SRC="$SRC/gmx_md100_3rep/$SYS/$REP/analysis"
    A_DEST="$DEST/06_per_rep_analysis_outputs/$SYS/$REP/analysis"

    if [[ -d "$A_SRC" ]]; then
      mkdir -p "$A_DEST"

      if [[ "$COPY_TRAJ" == "1" ]]; then
        rsync -a "$A_SRC"/ "$A_DEST"/
      else
        rsync -a \
          --exclude="*.xtc" \
          --exclude="*.trr" \
          --exclude="*.dcd" \
          --exclude="*.nc" \
          --exclude="*.cpt" \
          "$A_SRC"/ "$A_DEST"/
      fi

      echo "[RSYNC] $A_SRC/ -> $A_DEST/"
    else
      echo "[WARN] Missing analysis directory: $A_SRC"
    fi
  done
done

###############################################################################
# 5. Copy combined analysis summary tables
###############################################################################

echo
echo "============================================================"
echo "[STEP 5] Copy combined analysis summary tables"
echo "============================================================"

copy_dir_if_exists "$SRC/gmx_analysis_summary" "$DEST/07_combined_analysis_tables/gmx_analysis_summary"

if [[ -d "$SRC/nature_figures_gmx_mmpbsa/csv" ]]; then
  mkdir -p "$DEST/07_combined_analysis_tables/nature_figures_csv"
  rsync -a \
    --exclude="*mmpbsa*" \
    --exclude="*MMPBSA*" \
    "$SRC/nature_figures_gmx_mmpbsa/csv"/ \
    "$DEST/07_combined_analysis_tables/nature_figures_csv"/
fi

copy_glob_if_exists "$SRC/*rmsd*.csv" "$DEST/07_combined_analysis_tables/root_csv"
copy_glob_if_exists "$SRC/*rmsf*.csv" "$DEST/07_combined_analysis_tables/root_csv"
copy_glob_if_exists "$SRC/*gyrate*.csv" "$DEST/07_combined_analysis_tables/root_csv"
copy_glob_if_exists "$SRC/*hbond*.csv" "$DEST/07_combined_analysis_tables/root_csv"
copy_glob_if_exists "$SRC/*mindist*.csv" "$DEST/07_combined_analysis_tables/root_csv"
copy_glob_if_exists "$SRC/*contacts*.csv" "$DEST/07_combined_analysis_tables/root_csv"
copy_glob_if_exists "$SRC/*summary*.csv" "$DEST/07_combined_analysis_tables/root_csv"

###############################################################################
# 6. Copy MD figures only
###############################################################################

echo
echo "============================================================"
echo "[STEP 6] Copy Nature-style MD figures"
echo "============================================================"

FIG_SRC="$SRC/nature_figures_gmx_mmpbsa"

if [[ -d "$FIG_SRC" ]]; then
  # Copy MD-specific figure folders, excluding mmpbsa figures.
  copy_dir_if_exists "$FIG_SRC/figures_pdf/md_three_reps_separate_panels" \
    "$DEST/08_md_figures/figures_pdf/md_three_reps_separate_panels"

  copy_dir_if_exists "$FIG_SRC/figures_pdf/md_each_rep_single_panel" \
    "$DEST/08_md_figures/figures_pdf/md_each_rep_single_panel"

  copy_dir_if_exists "$FIG_SRC/figures_pdf/md_summary_bars" \
    "$DEST/08_md_figures/figures_pdf/md_summary_bars"

  copy_dir_if_exists "$FIG_SRC/figures_png/md_three_reps_separate_panels" \
    "$DEST/08_md_figures/figures_png/md_three_reps_separate_panels"

  copy_dir_if_exists "$FIG_SRC/figures_png/md_each_rep_single_panel" \
    "$DEST/08_md_figures/figures_png/md_each_rep_single_panel"

  copy_dir_if_exists "$FIG_SRC/figures_png/md_summary_bars" \
    "$DEST/08_md_figures/figures_png/md_summary_bars"

  copy_dir_if_exists "$FIG_SRC/figures_svg/md_three_reps_separate_panels" \
    "$DEST/08_md_figures/figures_svg/md_three_reps_separate_panels"

  copy_dir_if_exists "$FIG_SRC/figures_svg/md_each_rep_single_panel" \
    "$DEST/08_md_figures/figures_svg/md_each_rep_single_panel"

  copy_dir_if_exists "$FIG_SRC/figures_svg/md_summary_bars" \
    "$DEST/08_md_figures/figures_svg/md_summary_bars"

  copy_file_if_exists "$FIG_SRC/figure_legends_methods_reviewer_response.md" \
    "$DEST/08_md_figures"
else
  echo "[WARN] Missing figure source folder: $FIG_SRC"
fi

###############################################################################
# 7. Copy GROMACS analysis scripts
###############################################################################

echo
echo "============================================================"
echo "[STEP 7] Copy GROMACS/MD analysis scripts"
echo "============================================================"

# Main analysis and plotting scripts
copy_glob_if_exists "$SRC/06*.slurm" "$DEST/09_scripts/analysis_slurm"
copy_glob_if_exists "$SRC/07*.py" "$DEST/09_scripts/collect_plot_python"
copy_glob_if_exists "$SRC/08*.py" "$DEST/09_scripts/collect_plot_python"
copy_glob_if_exists "$SRC/14*.sh" "$DEST/09_scripts/check_scripts"
copy_glob_if_exists "$SRC/15*.sh" "$DEST/09_scripts/check_scripts"
copy_glob_if_exists "$SRC/16*.sh" "$DEST/09_scripts/check_scripts"
copy_glob_if_exists "$SRC/28*.py" "$DEST/09_scripts/nature_plotting"

# Production and progress scripts useful for context
copy_glob_if_exists "$SRC/05*.slurm" "$DEST/09_scripts/production_slurm"
copy_glob_if_exists "$SRC/11*.sh" "$DEST/09_scripts/progress_check"
copy_glob_if_exists "$SRC/12*.sh" "$DEST/09_scripts/progress_check"
copy_glob_if_exists "$SRC/13*.sh" "$DEST/09_scripts/progress_check"

# Root-level files detected by content keywords
mkdir -p "$DEST/09_scripts/content_detected"
while IFS= read -r -d '' f; do
  if grep -Iq . "$f" 2>/dev/null && \
     grep -Eiq "gmx|gromacs|rmsd|rmsf|gyrate|hbond|mindist|contacts|trjconv|make_ndx|energy" "$f" 2>/dev/null; then
    cp -p "$f" "$DEST/09_scripts/content_detected/"
    echo "[COPY_KEYWORD] $f -> $DEST/09_scripts/content_detected/"
  fi
done < <(
  find "$SRC" -maxdepth 1 -type f \
    \( -name "*.sh" -o -name "*.slurm" -o -name "*.py" -o -name "*.mdp" -o -name "*.md" -o -name "*.txt" \) \
    -print0
)

###############################################################################
# 8. Generate README and methods description
###############################################################################

echo
echo "============================================================"
echo "[STEP 8] Generate README and documentation"
echo "============================================================"

cat > "$DEST/00_project_overview/README_GROMACS_ANALYSIS_BACKUP.md" <<EOF_README
# A35R GROMACS MD analysis backup

This folder is a clean backup of GROMACS MD production metadata, trajectory-analysis outputs, summary tables, figures, and scripts.

## Original working directory

\`\`\`
$SRC
\`\`\`

## Backup directory

\`\`\`
$DEST
\`\`\`

## Systems

- drugs2263
- drugs3003
- drugs3523

Each system contains three independent 100 ns MD replicates:

- rep1
- rep2
- rep3

## Directory structure

\`\`\`
00_project_overview/
01_gromacs_input_systems/
02_short_test_results/
03_100ns_md_metadata/
04_100ns_md_logs/
05_100ns_final_structures/
06_per_rep_analysis_outputs/
07_combined_analysis_tables/
08_md_figures/
09_scripts/
10_quality_control/
11_optional_trajectories/
99_manifest/
\`\`\`

## Main MD analysis metrics

The backup includes:

1. Protein backbone RMSD
2. Ligand heavy-atom RMSD
3. Protein backbone RMSF
4. Radius of gyration
5. Protein-ligand hydrogen bonds
6. Protein-ligand minimum distance
7. Protein-ligand contact number

## Notes on large files

By default, large trajectory files such as \`.xtc\`, \`.trr\`, and checkpoint files are not copied.

To create a full backup including trajectories and checkpoints, run:

\`\`\`bash
COPY_TRAJ=1 COPY_RESTART=1 bash 33_backup_gromacs_md_analysis.sh
\`\`\`

## Reviewer-facing key folders

- Per-replicate analysis outputs:
  \`06_per_rep_analysis_outputs/\`

- Combined summary tables:
  \`07_combined_analysis_tables/\`

- Manuscript-ready MD figures:
  \`08_md_figures/\`

- Scripts:
  \`09_scripts/\`

- Integrity report:
  \`10_quality_control/gromacs_analysis_backup_integrity_check.txt\`

EOF_README

cat > "$DEST/00_project_overview/METHODS_GROMACS_MD_ANALYSIS.md" <<'EOF_METHODS'
# Methods text for GROMACS MD analysis

Molecular dynamics simulations were performed to evaluate the post-docking stability of the A35R-ligand complexes. Three candidate ligands, drugs2263, drugs3003, and drugs3523, were simulated in complex with A35R. Each system was subjected to energy minimization, NVT equilibration, NPT equilibration, and 100 ns production MD. Three independent production replicates were performed for each ligand.

The production trajectories were processed with periodic boundary correction, centering, and least-squares fitting prior to analysis. Protein backbone RMSD was calculated to assess global conformational stability of A35R. Ligand heavy-atom RMSD was calculated to evaluate whether the docked binding pose was maintained during MD. Residue-level RMSF was used to assess local protein flexibility. The radius of gyration was used to evaluate protein compactness. Protein-ligand hydrogen bonds, minimum distance, and contact number were calculated to characterize the persistence of ligand-pocket interactions.

The three replicates for each ligand were analyzed independently, and replicate-level statistics were summarized for comparison among the three A35R-ligand complexes.
EOF_METHODS

###############################################################################
# 9. Generate quality-control script
###############################################################################

cat > "$DEST/10_quality_control/34_check_gromacs_analysis_backup.sh" <<'EOF_CHECK'
#!/usr/bin/env bash
set -euo pipefail

ROOT=<REDACTED>
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

echo "============================================================"
echo "[INFO] GROMACS analysis backup integrity check"
echo "============================================================"
echo "[INFO] ROOT=$ROOT"
echo "[INFO] Date=$(date)"
echo "[INFO] Host=$(hostname)"
echo

echo "============================================================"
echo "[1] Basic folder check"
echo "============================================================"

for D in \
  00_project_overview \
  01_gromacs_input_systems \
  02_short_test_results \
  03_100ns_md_metadata \
  04_100ns_md_logs \
  05_100ns_final_structures \
  06_per_rep_analysis_outputs \
  07_combined_analysis_tables \
  08_md_figures \
  09_scripts \
  10_quality_control \
  99_manifest
do
  if [[ -d "$ROOT/$D" ]]; then
    echo "[OK] $D"
  else
    echo "[MISSING] $D"
  fi
done

echo
echo "============================================================"
echo "[2] 100 ns MD logs"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    LOG="$ROOT/04_100ns_md_logs/$SYS/$REP/md_100ns.log"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -s "$LOG" ]]; then
      echo "NO_LOG"
      continue
    fi

    if grep -qi "Finished mdrun" "$LOG"; then
      PERF="$(grep -i 'Performance:' "$LOG" | tail -n 1 | awk '{print $2}' || true)"
      echo "FINISHED Performance_ns_per_day=${PERF:-NA}"
    else
      echo "CHECK_LOG_NOT_FINISHED"
    fi
  done
done

echo
echo "============================================================"
echo "[3] Dangerous keyword scan in MD logs"
echo "============================================================"

if grep -RniE "Fatal error|Segmentation fault|LINCS WARNING|Too many LINCS warnings|not finite|exploding|Water molecule starting at atom|domain decomposition error|1-4 interaction.*cut-off" \
  "$ROOT/04_100ns_md_logs" 2>/dev/null; then
  echo "[WARN] Dangerous keywords found. Please inspect above."
else
  echo "No obvious dangerous keywords found in copied MD logs."
fi

echo
echo "============================================================"
echo "[4] Per-replicate analysis files"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/06_per_rep_analysis_outputs/$SYS/$REP/analysis"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -d "$D" ]]; then
      echo "NO_ANALYSIS_DIR"
      continue
    fi

    NCSV="$(find "$D" -maxdepth 1 -type f -name "*.csv" | wc -l)"
    NXVG="$(find "$D" -maxdepth 1 -type f -name "*.xvg" | wc -l)"
    NPDF="$(find "$D" -maxdepth 1 -type f -name "*.pdf" | wc -l)"
    echo "csv=$NCSV xvg=$NXVG pdf=$NPDF"
  done
done

echo
echo "============================================================"
echo "[5] Combined tables"
echo "============================================================"

find "$ROOT/07_combined_analysis_tables" \
  -type f \( -name "*.csv" -o -name "*.txt" -o -name "*.md" \) 2>/dev/null | sort

echo
echo "============================================================"
echo "[6] MD figure files"
echo "============================================================"

find "$ROOT/08_md_figures" \
  -type f \( -name "*.pdf" -o -name "*.png" -o -name "*.svg" \) 2>/dev/null | sort | head -n 200

echo
echo "============================================================"
echo "[7] Script files"
echo "============================================================"

find "$ROOT/09_scripts" \
  -type f \( -name "*.sh" -o -name "*.slurm" -o -name "*.py" -o -name "*.mdp" \) 2>/dev/null | sort | head -n 200

echo
echo "============================================================"
echo "[DONE] Integrity check finished"
echo "============================================================"
EOF_CHECK

chmod +x "$DEST/10_quality_control/34_check_gromacs_analysis_backup.sh"

###############################################################################
# 10. Generate manifest and checksum
###############################################################################

echo
echo "============================================================"
echo "[STEP 9] Generate manifest and checksum"
echo "============================================================"

(
  cd "$DEST"
  find . -type f | sort > 99_manifest/GROMACS_ANALYSIS_FILE_LIST.txt
  du -ah . | sort -h > 99_manifest/GROMACS_ANALYSIS_SIZE_REPORT.txt
  find . -type f ! -path "./99_manifest/GROMACS_ANALYSIS_SHA256SUMS.txt" -print0 \
    | sort -z \
    | xargs -0 sha256sum > 99_manifest/GROMACS_ANALYSIS_SHA256SUMS.txt
)

bash "$DEST/10_quality_control/34_check_gromacs_analysis_backup.sh" \
  > "$DEST/10_quality_control/gromacs_analysis_backup_integrity_check.txt" 2>&1 || true

###############################################################################
# 11. Optional tar.gz
###############################################################################

if [[ "$CREATE_TAR" == "1" ]]; then
  echo
  echo "============================================================"
  echo "[STEP 10] Create tar.gz archive"
  echo "============================================================"

  TAR_PATH="${DEST}.tar.gz"
  tar -czf "$TAR_PATH" -C "$(dirname "$DEST")" "$(basename "$DEST")"
  ls -lh "$TAR_PATH"
fi

###############################################################################
# 12. Final report
###############################################################################

echo
echo "============================================================"
echo "[DONE] GROMACS MD analysis backup created"
echo "============================================================"
echo "[RESULT] DEST=$DEST"
echo
echo "[INFO] Directory size:"
du -sh "$DEST"
echo
echo "[INFO] File count:"
find "$DEST" -type f | wc -l
echo
echo "[INFO] Integrity report:"
echo "$DEST/10_quality_control/gromacs_analysis_backup_integrity_check.txt"
echo
echo "[INFO] Manifest files:"
echo "$DEST/99_manifest/GROMACS_ANALYSIS_FILE_LIST.txt"
echo "$DEST/99_manifest/GROMACS_ANALYSIS_SIZE_REPORT.txt"
echo "$DEST/99_manifest/GROMACS_ANALYSIS_SHA256SUMS.txt"
echo
echo "[INFO] To inspect:"
echo "cd \"$DEST\""
echo "bash 10_quality_control/34_check_gromacs_analysis_backup.sh"
