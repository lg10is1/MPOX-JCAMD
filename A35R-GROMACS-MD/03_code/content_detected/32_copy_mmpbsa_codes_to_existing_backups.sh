#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Copy all gmx_MMPBSA-related scripts/codes/workflow files
# from original A35R-gromacs folder into existing MMPBSA backup folders.
###############################################################################

AMBER_ROOT="<USER_HOME>/1_projects/PRP-MPOX-JCAMD/JCAMD-R1/AMBER"

SRC="${AMBER_ROOT}/A35R-gromacs"

DESTS=(
  "${AMBER_ROOT}/A35R-gromacs-MMPBSA-minimal_20260526_130557"
  "${AMBER_ROOT}/A35R-gromacs-MMPBSA-backup_20260526_130531"
)

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

echo "============================================================"
echo "[INFO] Copy gmx_MMPBSA-related codes to existing backup folders"
echo "============================================================"
echo "[INFO] SRC=$SRC"
echo "[INFO] Date=$(date)"
echo "[INFO] Host=$(hostname)"
echo

if [[ ! -d "$SRC" ]]; then
  echo "[ERROR] Source folder does not exist:"
  echo "$SRC"
  exit 1
fi

for DEST in "${DESTS[@]}"; do
  if [[ ! -d "$DEST" ]]; then
    echo "[ERROR] Destination folder does not exist:"
    echo "$DEST"
    echo "[HINT] Please check the folder name."
    exit 1
  fi
done

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

copy_find_by_name() {
  local src_dir="$1"
  local dest_dir="$2"
  local name_pattern="$3"

  mkdir -p "$dest_dir"

  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi

  while IFS= read -r -d '' f; do
    rel="${f#$src_dir/}"
    mkdir -p "$dest_dir/$(dirname "$rel")"
    cp -p "$f" "$dest_dir/$rel"
    echo "[COPY] $f -> $dest_dir/$rel"
  done < <(find "$src_dir" -type f -iname "$name_pattern" -print0)
}

copy_find_by_content_keyword() {
  local src_dir="$1"
  local dest_dir="$2"
  local keyword_regex="$3"

  mkdir -p "$dest_dir"

  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi

  while IFS= read -r -d '' f; do
    if grep -Iq . "$f" 2>/dev/null && grep -Eiq "$keyword_regex" "$f" 2>/dev/null; then
      rel="${f#$src_dir/}"
      mkdir -p "$dest_dir/$(dirname "$rel")"
      cp -p "$f" "$dest_dir/$rel"
      echo "[COPY_KEYWORD] $f -> $dest_dir/$rel"
    fi
  done < <(
    find "$src_dir" -maxdepth 2 -type f \
      \( -name "*.sh" -o -name "*.slurm" -o -name "*.py" -o -name "*.in" -o -name "*.md" -o -name "*.txt" -o -name "*.path" \) \
      -print0
  )
}

###############################################################################
# Main copy loop
###############################################################################

for DEST in "${DESTS[@]}"; do
  echo
  echo "============================================================"
  echo "[DEST] $DEST"
  echo "============================================================"

  CODE_ROOT="$DEST/00_mmpbsa_codes_and_workflow"

  mkdir -p \
    "$CODE_ROOT/01_environment_check" \
    "$CODE_ROOT/02_prepare_inputs" \
    "$CODE_ROOT/03_slurm_run_scripts" \
    "$CODE_ROOT/04_debug_scripts" \
    "$CODE_ROOT/05_collect_parse_scripts" \
    "$CODE_ROOT/06_visualization_scripts" \
    "$CODE_ROOT/07_input_templates" \
    "$CODE_ROOT/08_path_files" \
    "$CODE_ROOT/09_per_rep_mmpbsa_inputs" \
    "$CODE_ROOT/10_logs_and_examples" \
    "$CODE_ROOT/99_manifest"

  ###########################################################################
  # 1. Environment/path files
  ###########################################################################

  echo "[STEP] Copy environment/path files"

  copy_glob_if_exists "$SRC/gmx_mmpbsa_container.path" "$CODE_ROOT/08_path_files"
  copy_glob_if_exists "$SRC/container_engine.path" "$CODE_ROOT/08_path_files"
  copy_glob_if_exists "$SRC/*mmpbsa*.path" "$CODE_ROOT/08_path_files"
  copy_glob_if_exists "$SRC/*MMPBSA*.path" "$CODE_ROOT/08_path_files"

  ###########################################################################
  # 2. Root-level mmpbsa scripts by filename
  ###########################################################################

  echo "[STEP] Copy root-level gmx_MMPBSA scripts by filename"

  copy_glob_if_exists "$SRC/*mmpbsa*.sh" "$CODE_ROOT/01_environment_check"
  copy_glob_if_exists "$SRC/*MMPBSA*.sh" "$CODE_ROOT/01_environment_check"

  copy_glob_if_exists "$SRC/*mmpbsa*.slurm" "$CODE_ROOT/03_slurm_run_scripts"
  copy_glob_if_exists "$SRC/*MMPBSA*.slurm" "$CODE_ROOT/03_slurm_run_scripts"

  copy_glob_if_exists "$SRC/*mmpbsa*.py" "$CODE_ROOT/05_collect_parse_scripts"
  copy_glob_if_exists "$SRC/*MMPBSA*.py" "$CODE_ROOT/05_collect_parse_scripts"

  ###########################################################################
  # 3. Known numbered scripts from this workflow
  ###########################################################################

  echo "[STEP] Copy known numbered MMPBSA workflow scripts"

  # Environment and input preparation
  copy_glob_if_exists "$SRC/20*.sh" "$CODE_ROOT/01_environment_check"
  copy_glob_if_exists "$SRC/20*.slurm" "$CODE_ROOT/01_environment_check"

  copy_glob_if_exists "$SRC/21*.sh" "$CODE_ROOT/02_prepare_inputs"
  copy_glob_if_exists "$SRC/21*.slurm" "$CODE_ROOT/02_prepare_inputs"

  # Debug and execution scripts
  copy_glob_if_exists "$SRC/22*.sh" "$CODE_ROOT/04_debug_scripts"
  copy_glob_if_exists "$SRC/22*.slurm" "$CODE_ROOT/04_debug_scripts"

  copy_glob_if_exists "$SRC/23*.sh" "$CODE_ROOT/03_slurm_run_scripts"
  copy_glob_if_exists "$SRC/23*.slurm" "$CODE_ROOT/03_slurm_run_scripts"

  copy_glob_if_exists "$SRC/24*.sh" "$CODE_ROOT/03_slurm_run_scripts"
  copy_glob_if_exists "$SRC/24*.slurm" "$CODE_ROOT/03_slurm_run_scripts"

  copy_glob_if_exists "$SRC/25*.sh" "$CODE_ROOT/03_slurm_run_scripts"
  copy_glob_if_exists "$SRC/25*.slurm" "$CODE_ROOT/03_slurm_run_scripts"

  copy_glob_if_exists "$SRC/26*.sh" "$CODE_ROOT/03_slurm_run_scripts"
  copy_glob_if_exists "$SRC/26*.slurm" "$CODE_ROOT/03_slurm_run_scripts"

  # Collection/parsing scripts
  copy_glob_if_exists "$SRC/27*.py" "$CODE_ROOT/05_collect_parse_scripts"
  copy_glob_if_exists "$SRC/27*.sh" "$CODE_ROOT/05_collect_parse_scripts"

  # Visualization script may contain both MD and MMPBSA plotting
  copy_glob_if_exists "$SRC/28*.py" "$CODE_ROOT/06_visualization_scripts"
  copy_glob_if_exists "$SRC/28*.sh" "$CODE_ROOT/06_visualization_scripts"

  ###########################################################################
  # 4. Copy any root script whose content mentions gmx_MMPBSA or MMPBSA
  ###########################################################################

  echo "[STEP] Copy scripts detected by content keyword"

  copy_find_by_content_keyword "$SRC" "$CODE_ROOT/10_logs_and_examples/content_detected_scripts" "gmx_MMPBSA|MMPBSA|mmpbsa|FINAL_RESULTS_MMPBSA|ΔTOTAL|DELTA_TOTAL"

  ###########################################################################
  # 5. Copy MMPBSA input templates from root and per-replicate folders
  ###########################################################################

  echo "[STEP] Copy MMPBSA input templates"

  copy_glob_if_exists "$SRC/*mmpbsa*.in" "$CODE_ROOT/07_input_templates"
  copy_glob_if_exists "$SRC/*MMPBSA*.in" "$CODE_ROOT/07_input_templates"
  copy_glob_if_exists "$SRC/*gb*.in" "$CODE_ROOT/07_input_templates"
  copy_glob_if_exists "$SRC/run1.sh" "$CODE_ROOT/07_input_templates"

  for SYS in "${SYSTEMS[@]}"; do
    for REP in "${REPS[@]}"; do
      REP_SRC="$SRC/gmx_mmpbsa_50_100ns/$SYS/$REP"
      REP_DEST="$CODE_ROOT/09_per_rep_mmpbsa_inputs/$SYS/$REP"

      mkdir -p "$REP_DEST"

      copy_file_if_exists "$REP_SRC/mmpbsa_gb_prod_pbr3.in" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/mmpbsa_gb_prod.in" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/mmpbsa_gb_test_debug_pbr3.in" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/mmpbsa_gb_test_debug.in" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/mmpbsa_index.ndx" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/mmpbsa_index.report.txt" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/run1.sh" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/topol.top" "$REP_DEST"
      copy_file_if_exists "$REP_SRC/md_100ns.tpr" "$REP_DEST"

      # Copy small logs useful for debugging, but not temporary GMXMMPBSA huge files.
      copy_file_if_exists "$REP_SRC/gmx_MMPBSA.log" "$CODE_ROOT/10_logs_and_examples/per_rep_logs/$SYS/$REP"
      copy_glob_if_exists "$REP_SRC/*stdout_stderr.log" "$CODE_ROOT/10_logs_and_examples/per_rep_logs/$SYS/$REP"
    done
  done

  ###########################################################################
  # 6. Copy MMPBSA summary tables and parser outputs if present
  ###########################################################################

  echo "[STEP] Copy MMPBSA summary folders"

  mkdir -p "$CODE_ROOT/05_collect_parse_scripts/summary_outputs_reference"

  if [[ -d "$SRC/gmx_mmpbsa_summary_delta_fixed" ]]; then
    rsync -a "$SRC/gmx_mmpbsa_summary_delta_fixed/" \
      "$CODE_ROOT/05_collect_parse_scripts/summary_outputs_reference/gmx_mmpbsa_summary_delta_fixed/"
  fi

  if [[ -d "$SRC/gmx_mmpbsa_summary_pbradii3" ]]; then
    rsync -a "$SRC/gmx_mmpbsa_summary_pbradii3/" \
      "$CODE_ROOT/05_collect_parse_scripts/summary_outputs_reference/gmx_mmpbsa_summary_pbradii3/"
  fi

  if [[ -d "$SRC/gmx_mmpbsa_summary_robust" ]]; then
    rsync -a "$SRC/gmx_mmpbsa_summary_robust/" \
      "$CODE_ROOT/05_collect_parse_scripts/summary_outputs_reference/gmx_mmpbsa_summary_robust/"
  fi

  ###########################################################################
  # 7. Copy MMPBSA-related figures/csv if generated
  ###########################################################################

  echo "[STEP] Copy MMPBSA visualization outputs if present"

  if [[ -d "$SRC/nature_figures_gmx_mmpbsa" ]]; then
    mkdir -p "$CODE_ROOT/06_visualization_scripts/nature_figures_reference"

    if [[ -d "$SRC/nature_figures_gmx_mmpbsa/csv" ]]; then
      rsync -a "$SRC/nature_figures_gmx_mmpbsa/csv/" \
        "$CODE_ROOT/06_visualization_scripts/nature_figures_reference/csv/"
    fi

    if [[ -d "$SRC/nature_figures_gmx_mmpbsa/figures_pdf/mmpbsa" ]]; then
      rsync -a "$SRC/nature_figures_gmx_mmpbsa/figures_pdf/mmpbsa/" \
        "$CODE_ROOT/06_visualization_scripts/nature_figures_reference/figures_pdf_mmpbsa/"
    fi

    if [[ -d "$SRC/nature_figures_gmx_mmpbsa/figures_png/mmpbsa" ]]; then
      rsync -a "$SRC/nature_figures_gmx_mmpbsa/figures_png/mmpbsa/" \
        "$CODE_ROOT/06_visualization_scripts/nature_figures_reference/figures_png_mmpbsa/"
    fi

    if [[ -d "$SRC/nature_figures_gmx_mmpbsa/figures_svg/mmpbsa" ]]; then
      rsync -a "$SRC/nature_figures_gmx_mmpbsa/figures_svg/mmpbsa/" \
        "$CODE_ROOT/06_visualization_scripts/nature_figures_reference/figures_svg_mmpbsa/"
    fi

    copy_file_if_exists "$SRC/nature_figures_gmx_mmpbsa/figure_legends_methods_reviewer_response.md" \
      "$CODE_ROOT/06_visualization_scripts/nature_figures_reference"
  fi

  ###########################################################################
  # 8. Generate README for MMPBSA code package
  ###########################################################################

  echo "[STEP] Generate README"

  cat > "$CODE_ROOT/README_gmx_MMPBSA_codes.md" <<EOF_README
# gmx_MMPBSA codes and workflow archive

This folder contains the gmx_MMPBSA-related scripts, SLURM jobs, input templates, parsing scripts, and visualization scripts copied from the original working directory.

## Original working directory

\`\`\`
$SRC
\`\`\`

## Current backup folder

\`\`\`
$DEST
\`\`\`

## Main subfolders

\`\`\`
00_mmpbsa_codes_and_workflow/
├── 01_environment_check/
├── 02_prepare_inputs/
├── 03_slurm_run_scripts/
├── 04_debug_scripts/
├── 05_collect_parse_scripts/
├── 06_visualization_scripts/
├── 07_input_templates/
├── 08_path_files/
├── 09_per_rep_mmpbsa_inputs/
├── 10_logs_and_examples/
└── 99_manifest/
\`\`\`

## Recommended order

1. Check environment:
   - \`01_environment_check/\`

2. Prepare gmx_MMPBSA input files:
   - \`02_prepare_inputs/\`

3. Run or debug gmx_MMPBSA:
   - \`03_slurm_run_scripts/\`
   - \`04_debug_scripts/\`

4. Parse final results:
   - \`05_collect_parse_scripts/\`

5. Generate figures:
   - \`06_visualization_scripts/\`

## Key result interpretation

The final binding free energy should be read from the section:

\`\`\`
Delta (Complex - Receptor - Ligand)
\`\`\`

The key term is:

\`\`\`
ΔTOTAL
\`\`\`

Do not use the \`TOTAL\` values under Complex, Receptor, or Ligand as binding free energy.

## Main gmx_MMPBSA result files

Per replicate:

\`\`\`
gmx_mmpbsa_50_100ns/<system>/<rep>/FINAL_RESULTS_MMPBSA_GB.dat
\`\`\`

Summary tables:

\`\`\`
gmx_mmpbsa_summary_delta_fixed/mmpbsa_delta_total_summary.csv
gmx_mmpbsa_summary_delta_fixed/mmpbsa_delta_summary_by_system.csv
gmx_mmpbsa_summary_delta_fixed/mmpbsa_delta_terms_by_rep_long.csv
gmx_mmpbsa_summary_delta_fixed/mmpbsa_delta_terms_by_rep_wide.csv
\`\`\`

EOF_README

  ###########################################################################
  # 9. Generate quick check script
  ###########################################################################

  cat > "$CODE_ROOT/99_manifest/check_mmpbsa_code_archive.sh" <<'EOF_CHECK'
#!/usr/bin/env bash
set -euo pipefail

ROOT=<REDACTED>

echo "============================================================"
echo "[INFO] gmx_MMPBSA code archive check"
echo "============================================================"
echo "[INFO] ROOT=$ROOT"
echo "[INFO] Date=$(date)"
echo

echo "============================================================"
echo "[1] Scripts by type"
echo "============================================================"
echo "Shell scripts:"
find "$ROOT" -type f -name "*.sh" | sort | sed 's#^#  #'
echo
echo "SLURM scripts:"
find "$ROOT" -type f -name "*.slurm" | sort | sed 's#^#  #'
echo
echo "Python scripts:"
find "$ROOT" -type f -name "*.py" | sort | sed 's#^#  #'
echo
echo "Input templates:"
find "$ROOT" -type f -name "*.in" | sort | sed 's#^#  #'
echo

echo "============================================================"
echo "[2] Search important keywords"
echo "============================================================"
grep -RInE "gmx_MMPBSA|MMPBSA|FINAL_RESULTS_MMPBSA|ΔTOTAL|DELTA_TOTAL" "$ROOT" \
  --include="*.sh" --include="*.slurm" --include="*.py" --include="*.in" --include="*.md" \
  | head -n 200 || true

echo
echo "============================================================"
echo "[3] Per-replicate input folders"
echo "============================================================"
find "$ROOT/09_per_rep_mmpbsa_inputs" -maxdepth 3 -type f | sort | head -n 200 || true

echo
echo "============================================================"
echo "[DONE] Check finished"
echo "============================================================"
EOF_CHECK

  chmod +x "$CODE_ROOT/99_manifest/check_mmpbsa_code_archive.sh"

  ###########################################################################
  # 10. Manifest and checksum
  ###########################################################################

  echo "[STEP] Generate manifest"

  (
    cd "$CODE_ROOT"
    find . -type f | sort > 99_manifest/MMPBSA_CODE_FILE_LIST.txt
    du -ah . | sort -h > 99_manifest/MMPBSA_CODE_SIZE_REPORT.txt
    find . -type f ! -path "./99_manifest/MMPBSA_CODE_SHA256SUMS.txt" -print0 \
      | sort -z \
      | xargs -0 sha256sum > 99_manifest/MMPBSA_CODE_SHA256SUMS.txt
  )

  bash "$CODE_ROOT/99_manifest/check_mmpbsa_code_archive.sh" \
    > "$CODE_ROOT/99_manifest/MMPBSA_CODE_ARCHIVE_CHECK.txt" 2>&1 || true

  echo
  echo "[DONE] Copied gmx_MMPBSA codes to:"
  echo "$CODE_ROOT"
  echo
  echo "[INFO] Code archive size:"
  du -sh "$CODE_ROOT"
  echo
  echo "[INFO] File count:"
  find "$CODE_ROOT" -type f | wc -l
  echo
  echo "[INFO] Check report:"
  echo "$CODE_ROOT/99_manifest/MMPBSA_CODE_ARCHIVE_CHECK.txt"

done

echo
echo "============================================================"
echo "[ALL DONE] gmx_MMPBSA code files copied to both backup folders"
echo "============================================================"
