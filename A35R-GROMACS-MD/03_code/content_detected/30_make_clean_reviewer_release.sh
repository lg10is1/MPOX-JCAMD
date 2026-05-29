#!/usr/bin/env bash
set -euo pipefail

###############################################################################
# Clean reviewer-release package for A35R GROMACS/MD/MMGBSA workflow
#
# Default:
#   - keep original A35R-gromacs untouched
#   - create a new clean folder
#   - copy scripts, topology, mdp, logs, analysis csv/xvg, figures, MM/GBSA results
#   - do NOT copy huge trajectories by default
#
# Optional:
#   COPY_TRAJ=1 bash 30_make_clean_reviewer_release.sh
#   COPY_RESTART=1 bash 30_make_clean_reviewer_release.sh
#   CREATE_TAR=1 bash 30_make_clean_reviewer_release.sh
###############################################################################

SRC="<PROJECT_ROOT>/gromacs-runs"
PARENT="$(dirname "$SRC")"

DATE_TAG="$(date +%Y%m%d_%H%M%S)"
DEST="${DEST:-$PARENT/A35R-gromacs-reviewer-release_$DATE_TAG}"

COPY_TRAJ="${COPY_TRAJ:-0}"
COPY_RESTART="${COPY_RESTART:-0}"
CREATE_TAR="${CREATE_TAR:-0}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

echo "============================================================"
echo "[INFO] Create clean reviewer-release folder"
echo "============================================================"
echo "[INFO] SRC=$SRC"
echo "[INFO] DEST=$DEST"
echo "[INFO] COPY_TRAJ=$COPY_TRAJ"
echo "[INFO] COPY_RESTART=$COPY_RESTART"
echo "[INFO] CREATE_TAR=$CREATE_TAR"
echo "[INFO] Date=$(date)"
echo "[INFO] Host=$(hostname)"

if [[ ! -d "$SRC" ]]; then
  echo "[ERROR] SRC does not exist: $SRC"
  exit 1
fi

if [[ -e "$DEST" ]]; then
  echo "[ERROR] DEST already exists: $DEST"
  echo "[HINT] Use another DEST, for example:"
  echo "       DEST=${DEST}_new bash 30_make_clean_reviewer_release.sh"
  exit 1
fi

mkdir -p "$DEST"

###############################################################################
# Helper functions
###############################################################################

copy_file() {
  local src_file="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  if [[ -e "$src_file" ]]; then
    cp -p "$src_file" "$dest_dir/"
  fi
}

copy_glob() {
  local pattern="$1"
  local dest_dir="$2"

  mkdir -p "$dest_dir"

  shopt -s nullglob
  local files=( $pattern )
  shopt -u nullglob

  local f
  for f in "${files[@]}"; do
    if [[ -f "$f" ]]; then
      cp -p "$f" "$dest_dir/"
    fi
  done
}

copy_dir_if_exists() {
  local src_dir="$1"
  local dest_dir="$2"

  if [[ -d "$src_dir" ]]; then
    mkdir -p "$dest_dir"
    rsync -a "$src_dir"/ "$dest_dir"/
  fi
}

copy_dir_small_results() {
  local src_dir="$1"
  local dest_dir="$2"

  if [[ ! -d "$src_dir" ]]; then
    return 0
  fi

  mkdir -p "$dest_dir"

  if [[ "$COPY_TRAJ" == "1" ]]; then
    rsync -a \
      --exclude="_GMXMMPBSA_*" \
      --exclude="GMXMMPBSA_*" \
      "$src_dir"/ "$dest_dir"/
  else
    rsync -a \
      --exclude="*.xtc" \
      --exclude="*.trr" \
      --exclude="*.dcd" \
      --exclude="*.nc" \
      --exclude="*.cpt" \
      --exclude="_GMXMMPBSA_*" \
      --exclude="GMXMMPBSA_*" \
      "$src_dir"/ "$dest_dir"/
  fi
}

###############################################################################
# 0. Create directory structure
###############################################################################

mkdir -p \
  "$DEST/00_project_overview" \
  "$DEST/01_input_core/amber_prmtop_inpcrd" \
  "$DEST/01_input_core/gromacs_initial_systems" \
  "$DEST/02_conversion_to_gromacs/scripts" \
  "$DEST/02_conversion_to_gromacs/converted_systems" \
  "$DEST/02_conversion_to_gromacs/conversion_reports" \
  "$DEST/03_gromacs_short_test/scripts" \
  "$DEST/03_gromacs_short_test/results" \
  "$DEST/03_gromacs_short_test/logs" \
  "$DEST/04_gromacs_100ns_md/scripts" \
  "$DEST/04_gromacs_100ns_md/production_metadata" \
  "$DEST/04_gromacs_100ns_md/final_structures" \
  "$DEST/04_gromacs_100ns_md/logs" \
  "$DEST/04_gromacs_100ns_md/trajectories_optional" \
  "$DEST/05_md_analysis/scripts" \
  "$DEST/05_md_analysis/per_rep_outputs" \
  "$DEST/05_md_analysis/combined_tables" \
  "$DEST/05_md_analysis/figures" \
  "$DEST/06_gmx_mmpbsa/scripts" \
  "$DEST/06_gmx_mmpbsa/per_rep_results" \
  "$DEST/06_gmx_mmpbsa/summary_tables" \
  "$DEST/06_gmx_mmpbsa/logs" \
  "$DEST/07_figures_for_manuscript" \
  "$DEST/08_manuscript_text" \
  "$DEST/09_all_scripts_backup/root_files" \
  "$DEST/10_quality_control" \
  "$DEST/99_manifest"

###############################################################################
# 1. Root-level workflow scripts and text files
###############################################################################

echo "[STEP] Copy root-level scripts and text files"

copy_glob "$SRC/*.sh"    "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.slurm" "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.py"    "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.mdp"   "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.md"    "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.txt"   "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.csv"   "$DEST/09_all_scripts_backup/root_files"
copy_glob "$SRC/*.json"  "$DEST/09_all_scripts_backup/root_files"

# Curated task-specific scripts
copy_glob "$SRC/00*.sh"    "$DEST/02_conversion_to_gromacs/scripts"
copy_glob "$SRC/01*.sh"    "$DEST/02_conversion_to_gromacs/scripts"
copy_glob "$SRC/02*.sh"    "$DEST/02_conversion_to_gromacs/scripts"
copy_glob "$SRC/03*.slurm" "$DEST/03_gromacs_short_test/scripts"
copy_glob "$SRC/04*.slurm" "$DEST/03_gromacs_short_test/scripts"
copy_glob "$SRC/05*.slurm" "$DEST/04_gromacs_100ns_md/scripts"
copy_glob "$SRC/06*.slurm" "$DEST/05_md_analysis/scripts"
copy_glob "$SRC/07*.py"    "$DEST/05_md_analysis/scripts"
copy_glob "$SRC/08*.py"    "$DEST/05_md_analysis/scripts"
copy_glob "$SRC/14*.sh"    "$DEST/05_md_analysis/scripts"
copy_glob "$SRC/20*.sh"    "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/21*.sh"    "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/22*.slurm" "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/23*.slurm" "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/24*.sh"    "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/27*.py"    "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/28*.py"    "$DEST/05_md_analysis/scripts"

###############################################################################
# 2. Input core and converted GROMACS systems
###############################################################################

echo "[STEP] Copy input core and converted systems"

# Possible Amber core inputs if they were copied into A35R-gromacs
for SYS in "${SYSTEMS[@]}"; do
  mkdir -p "$DEST/01_input_core/amber_prmtop_inpcrd/$SYS"

  copy_glob "$SRC/systems/$SYS/*.prmtop" "$DEST/01_input_core/amber_prmtop_inpcrd/$SYS"
  copy_glob "$SRC/systems/$SYS/*.inpcrd" "$DEST/01_input_core/amber_prmtop_inpcrd/$SYS"
  copy_glob "$SRC/systems/$SYS/*.rst7"   "$DEST/01_input_core/amber_prmtop_inpcrd/$SYS"
  copy_glob "$SRC/systems/$SYS/*summary*.txt" "$DEST/01_input_core/amber_prmtop_inpcrd/$SYS"
  copy_glob "$SRC/systems/$SYS/*flag" "$DEST/01_input_core/amber_prmtop_inpcrd/$SYS"

  # Converted GROMACS systems may be under gromacs_systems or gmx_test_cpu.
  mkdir -p "$DEST/02_conversion_to_gromacs/converted_systems/$SYS"

  copy_glob "$SRC/gromacs_systems/$SYS/conf.gro" "$DEST/02_conversion_to_gromacs/converted_systems/$SYS"
  copy_glob "$SRC/gromacs_systems/$SYS/topol.top" "$DEST/02_conversion_to_gromacs/converted_systems/$SYS"
  copy_glob "$SRC/gromacs_systems/$SYS/*.itp" "$DEST/02_conversion_to_gromacs/converted_systems/$SYS"
  copy_glob "$SRC/gromacs_systems/$SYS/index.ndx" "$DEST/02_conversion_to_gromacs/converted_systems/$SYS"
  copy_glob "$SRC/gromacs_systems/$SYS/conversion_report.*" "$DEST/02_conversion_to_gromacs/conversion_reports/$SYS"

  copy_glob "$SRC/gmx_test_cpu/$SYS/conf.gro" "$DEST/01_input_core/gromacs_initial_systems/$SYS"
  copy_glob "$SRC/gmx_test_cpu/$SYS/topol.top" "$DEST/01_input_core/gromacs_initial_systems/$SYS"
  copy_glob "$SRC/gmx_test_cpu/$SYS/index.ndx" "$DEST/01_input_core/gromacs_initial_systems/$SYS"
  copy_glob "$SRC/gmx_test_cpu/$SYS/*.itp" "$DEST/01_input_core/gromacs_initial_systems/$SYS"
  copy_glob "$SRC/gmx_test_cpu/$SYS/conversion_report.*" "$DEST/02_conversion_to_gromacs/conversion_reports/$SYS"
done

###############################################################################
# 3. Short GROMACS CPU test results
###############################################################################

echo "[STEP] Copy short GROMACS test results"

for SYS in "${SYSTEMS[@]}"; do
  D="$SRC/gmx_test_cpu/$SYS"
  OUT="$DEST/03_gromacs_short_test/results/$SYS"
  LOGOUT="$DEST/03_gromacs_short_test/logs/$SYS"

  mkdir -p "$OUT" "$LOGOUT"

  copy_glob "$D/*.log" "$LOGOUT"
  copy_glob "$D/*.out" "$LOGOUT"
  copy_glob "$D/*.err" "$LOGOUT"

  copy_file "$D/em.tpr" "$OUT"
  copy_file "$D/em.gro" "$OUT"
  copy_file "$D/em.edr" "$OUT"
  copy_file "$D/nvt_20ps.tpr" "$OUT"
  copy_file "$D/nvt_20ps.gro" "$OUT"
  copy_file "$D/nvt_20ps.edr" "$OUT"
  copy_file "$D/npt_20ps.tpr" "$OUT"
  copy_file "$D/npt_20ps.gro" "$OUT"
  copy_file "$D/npt_20ps.edr" "$OUT"
  copy_file "$D/md_20ps.tpr" "$OUT"
  copy_file "$D/md_20ps.gro" "$OUT"
  copy_file "$D/md_20ps.edr" "$OUT"

  if [[ "$COPY_TRAJ" == "1" ]]; then
    copy_glob "$D/*.xtc" "$OUT/trajectories"
    copy_glob "$D/*.trr" "$OUT/trajectories"
  fi

  if [[ "$COPY_RESTART" == "1" ]]; then
    copy_glob "$D/*.cpt" "$OUT/restarts"
  fi
done

###############################################################################
# 4. 100 ns MD production metadata, logs, final structures and optional trajectories
###############################################################################

echo "[STEP] Copy 100 ns MD production results"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$SRC/gmx_md100_3rep/$SYS/$REP"

    META="$DEST/04_gromacs_100ns_md/production_metadata/$SYS/$REP"
    FINAL="$DEST/04_gromacs_100ns_md/final_structures/$SYS/$REP"
    LOGDIR="$DEST/04_gromacs_100ns_md/logs/$SYS/$REP"
    TRAJDIR="$DEST/04_gromacs_100ns_md/trajectories_optional/$SYS/$REP"

    mkdir -p "$META" "$FINAL" "$LOGDIR"

    copy_file "$D/topol.top" "$META"
    copy_file "$D/index.ndx" "$META"
    copy_file "$D/md_100ns.tpr" "$META"
    copy_file "$D/md_100ns_out.mdp" "$META"
    copy_file "$D/md_100ns.mdp" "$META"

    copy_file "$D/md_100ns.gro" "$FINAL"
    copy_file "$D/md_100ns.edr" "$FINAL"

    copy_file "$D/md_100ns.log" "$LOGDIR"
    copy_glob "$D/*.out" "$LOGDIR"
    copy_glob "$D/*.err" "$LOGDIR"

    if [[ "$COPY_RESTART" == "1" ]]; then
      mkdir -p "$FINAL/restarts"
      copy_glob "$D/*.cpt" "$FINAL/restarts"
    fi

    if [[ "$COPY_TRAJ" == "1" ]]; then
      mkdir -p "$TRAJDIR"
      copy_glob "$D/*.xtc" "$TRAJDIR"
      copy_glob "$D/*.trr" "$TRAJDIR"
      copy_glob "$D/analysis/*.xtc" "$TRAJDIR/analysis_fit_xtc"
    fi
  done
done

###############################################################################
# 5. MD analysis outputs
###############################################################################

echo "[STEP] Copy MD analysis outputs"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$SRC/gmx_md100_3rep/$SYS/$REP/analysis"
    OUT="$DEST/05_md_analysis/per_rep_outputs/$SYS/$REP/analysis"

    if [[ "$COPY_TRAJ" == "1" ]]; then
      copy_dir_small_results "$D" "$OUT"
    else
      if [[ -d "$D" ]]; then
        mkdir -p "$OUT"
        rsync -a \
          --exclude="*.xtc" \
          --exclude="*.trr" \
          --exclude="*.dcd" \
          --exclude="*.nc" \
          --exclude="*.cpt" \
          "$D"/ "$OUT"/
      fi
    fi
  done
done

copy_dir_if_exists "$SRC/gmx_analysis_summary" "$DEST/05_md_analysis/combined_tables/gmx_analysis_summary"

copy_glob "$SRC/*analysis*summary*.csv" "$DEST/05_md_analysis/combined_tables"
copy_glob "$SRC/*analysis*summary*.txt" "$DEST/05_md_analysis/combined_tables"
copy_glob "$SRC/*check*gromacs*analysis*.sh" "$DEST/05_md_analysis/scripts"

###############################################################################
# 6. gmx_MMPBSA results
###############################################################################

echo "[STEP] Copy gmx_MMPBSA results"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$SRC/gmx_mmpbsa_50_100ns/$SYS/$REP"
    OUT="$DEST/06_gmx_mmpbSA_TMP_PLACEHOLDER"

    OUT="$DEST/06_gmx_mmpbsa/per_rep_results/$SYS/$REP"
    LOGOUT="$DEST/06_gmx_mmpbsa/logs/$SYS/$REP"

    mkdir -p "$OUT" "$LOGOUT"

    copy_file "$D/FINAL_RESULTS_MMPBSA_GB.dat" "$OUT"
    copy_file "$D/FINAL_RESULTS_MMPBSA_GB.csv" "$OUT"
    copy_file "$D/FINAL_RESULTS_MMPBSA_GB_TEST.dat" "$OUT"
    copy_file "$D/FINAL_RESULTS_MMPBSA_GB_TEST.csv" "$OUT"

    copy_file "$D/mmpbsa_index.ndx" "$OUT"
    copy_file "$D/mmpbsa_index.report.txt" "$OUT"
    copy_file "$D/mmpbsa_gb_prod_pbr3.in" "$OUT"
    copy_file "$D/mmpbsa_gb_test_debug_pbr3.in" "$OUT"
    copy_file "$D/mmpbsa_gb_prod.in" "$OUT"
    copy_file "$D/mmpbsa_gb_test_debug.in" "$OUT"

    copy_file "$D/topol.top" "$OUT"
    copy_file "$D/md_100ns.tpr" "$OUT"

    copy_file "$D/gmx_MMPBSA.log" "$LOGOUT"
    copy_glob "$D/*stdout_stderr.log" "$LOGOUT"
    copy_glob "$D/*.mdout" "$LOGOUT"

    if [[ "$COPY_TRAJ" == "1" ]]; then
      copy_glob "$D/*.xtc" "$OUT/trajectory_frames_used"
    fi
  done
done

copy_dir_if_exists "$SRC/gmx_mmpbsa_summary_delta_fixed" "$DEST/06_gmx_mmpbsa/summary_tables/gmx_mmpbsa_summary_delta_fixed"
copy_dir_if_exists "$SRC/gmx_mmpbsa_summary_pbradii3" "$DEST/06_gmx_mmpbsa/summary_tables/gmx_mmpbsa_summary_pbradii3"
copy_dir_if_exists "$SRC/gmx_mmpbsa_summary_robust" "$DEST/06_gmx_mmpbsa/summary_tables/gmx_mmpbsa_summary_robust"

copy_glob "$SRC/gmx_mmpbsa_container.path" "$DEST/06_gmx_mmpbsa/scripts"
copy_glob "$SRC/container_engine.path" "$DEST/06_gmx_mmpbsa/scripts"

###############################################################################
# 7. Figures and manuscript-ready outputs
###############################################################################

echo "[STEP] Copy figures and manuscript-ready outputs"

copy_dir_if_exists "$SRC/nature_figures_gmx_mmpbsa" "$DEST/07_figures_for_manuscript/nature_figures_gmx_mmpbsa"

if [[ -f "$SRC/nature_figures_gmx_mmpbsa/figure_legends_methods_reviewer_response.md" ]]; then
  cp -p "$SRC/nature_figures_gmx_mmpbsa/figure_legends_methods_reviewer_response.md" \
    "$DEST/08_manuscript_text/"
fi

copy_glob "$SRC/*reviewer*.md" "$DEST/08_manuscript_text"
copy_glob "$SRC/*methods*.md" "$DEST/08_manuscript_text"
copy_glob "$SRC/*figure*legend*.md" "$DEST/08_manuscript_text"

###############################################################################
# 8. Generate README and documentation
###############################################################################

echo "[STEP] Generate README and documentation"

cat > "$DEST/00_project_overview/README.md" <<EOF_README
# A35R GROMACS MD and gmx_MMPBSA reviewer-release package

## Purpose

This folder contains a cleaned and structured copy of the A35R-ligand GROMACS molecular dynamics and gmx_MMPBSA analysis workflow.

The original working directory was preserved and not modified:

\`\`\`
$SRC
\`\`\`

This clean release directory is:

\`\`\`
$DEST
\`\`\`

## Systems

Three A35R-ligand complexes were included:

1. drugs2263
2. drugs3003
3. drugs3523

Each ligand has three independent 100 ns GROMACS MD replicates:

\`\`\`
rep1
rep2
rep3
\`\`\`

## Main directory structure

\`\`\`
00_project_overview/
  README.md
  RUN_ORDER.md
  DIRECTORY_MAP.md

01_input_core/
  amber_prmtop_inpcrd/
  gromacs_initial_systems/

02_conversion_to_gromacs/
  scripts/
  converted_systems/
  conversion_reports/

03_gromacs_short_test/
  scripts/
  results/
  logs/

04_gromacs_100ns_md/
  scripts/
  production_metadata/
  final_structures/
  logs/
  trajectories_optional/

05_md_analysis/
  scripts/
  per_rep_outputs/
  combined_tables/
  figures/

06_gmx_mmpbsa/
  scripts/
  per_rep_results/
  summary_tables/
  logs/

07_figures_for_manuscript/
  nature_figures_gmx_mmpbsa/

08_manuscript_text/
  figure legends, methods text, and reviewer-response draft

09_all_scripts_backup/
  root_files/

10_quality_control/
  integrity checks and summaries

99_manifest/
  file manifest and checksums
\`\`\`

## Notes on trajectory files

By default, this release does not include large raw trajectory files such as \`.xtc\`, \`.trr\`, \`.nc\`, or restart files. This keeps the review package compact and focused on scripts, parameters, logs, processed analysis outputs, figures, and final MM/GBSA results.

A full trajectory release can be created from the original working directory using:

\`\`\`bash
COPY_TRAJ=1 COPY_RESTART=1 bash 30_make_clean_reviewer_release.sh
\`\`\`

## Main results

The key reviewer-facing outputs are:

- MD analysis summary:
  \`05_md_analysis/combined_tables/\`
- Per-replicate MD analysis:
  \`05_md_analysis/per_rep_outputs/\`
- MM/GBSA per-replicate results:
  \`06_gmx_mmpbsa/per_rep_results/\`
- MM/GBSA summary tables:
  \`06_gmx_mmpbsa/summary_tables/\`
- Manuscript-quality figures:
  \`07_figures_for_manuscript/\`
- Methods and reviewer-response draft:
  \`08_manuscript_text/\`

EOF_README

cat > "$DEST/00_project_overview/RUN_ORDER.md" <<'EOF_RUN'
# Suggested workflow order

The workflow was organized in the following order.

## 1. Amber to GROMACS conversion

Input:
- Amber `complex_solvated.prmtop`
- Amber `complex_solvated.inpcrd`

Output:
- `conf.gro`
- `topol.top`
- position restraint files
- `index.ndx`
- conversion reports

Relevant folder:
- `02_conversion_to_gromacs/`

## 2. Short GROMACS CPU test

Purpose:
- confirm that the converted system can pass EM, NVT, NPT, and short production MD
- identify possible topology, constraint, LINCS, or bad-contact problems

Relevant folder:
- `03_gromacs_short_test/`

## 3. 100 ns GROMACS MD with 3 replicates per ligand

Purpose:
- post-docking dynamic refinement
- assess whether docking poses remain stable after explicit-solvent MD
- generate trajectories for RMSD, RMSF, Rg, hydrogen-bond, distance, and contact analyses

Relevant folder:
- `04_gromacs_100ns_md/`

## 4. MD trajectory analysis

Metrics:
- protein backbone RMSD
- ligand heavy-atom RMSD
- protein backbone RMSF
- radius of gyration
- protein-ligand hydrogen bonds
- protein-ligand minimum distance
- protein-ligand contacts

Relevant folder:
- `05_md_analysis/`

## 5. gmx_MMPBSA binding energy calculation

Purpose:
- quantitative post-MD binding free-energy estimation
- energy decomposition into van der Waals, electrostatic, polar solvation, nonpolar solvation, gas-phase, solvation, and total binding terms

Relevant folder:
- `06_gmx_mmpbsa/`

## 6. Figure generation and manuscript text

Purpose:
- prepare Nature-style figures
- generate methods text
- prepare reviewer-response draft

Relevant folder:
- `07_figures_for_manuscript/`
- `08_manuscript_text/`
EOF_RUN

cat > "$DEST/00_project_overview/DIRECTORY_MAP.md" <<EOF_MAP
# Directory map

## 00_project_overview

General documentation of this cleaned release package.

## 01_input_core

Core starting files used for the GROMACS workflow.

## 02_conversion_to_gromacs

Scripts and outputs related to Amber-to-GROMACS conversion.

## 03_gromacs_short_test

Short CPU test results. These confirm that EM, NVT, NPT, and 20 ps production tests completed successfully.

## 04_gromacs_100ns_md

Production MD metadata, final structures, and logs for 100 ns simulations. Large trajectory files are only included if the package was created with \`COPY_TRAJ=1\`.

## 05_md_analysis

Per-replicate and combined MD analysis outputs.

## 06_gmx_mmpbsa

gmx_MMPBSA input files, logs, final results, and summary tables.

## 07_figures_for_manuscript

Manuscript-ready figures generated from MD and MM/GBSA outputs.

## 08_manuscript_text

Draft text for Methods, Results, figure legends, and reviewer responses.

## 09_all_scripts_backup

Backup of root-level scripts from the original working directory.

## 10_quality_control

Integrity-check scripts and copied file checks.

## 99_manifest

File list, size report, and checksum manifest.
EOF_MAP

cat > "$DEST/08_manuscript_text/METHODS_SUMMARY_FOR_REVIEWERS.md" <<'EOF_METHODS'
# Methods summary for reviewers

The three A35R-ligand complexes, drugs2263, drugs3003, and drugs3523, were first prepared in Amber/AmberTools. The ligand parameters were generated using GAFF2, and the solvated Amber systems were converted into GROMACS-compatible topology and coordinate files while preserving ligand parameters and charges.

For each ligand, the converted GROMACS system was subjected to energy minimization, NVT equilibration, NPT equilibration, and 100 ns production MD. Three independent production replicates were performed for each ligand using different random seeds. The production trajectories were processed with periodic boundary correction, centering, and fitting before downstream analyses.

Trajectory stability was evaluated using protein backbone RMSD, ligand heavy-atom RMSD, protein backbone RMSF, radius of gyration, protein-ligand hydrogen bonds, protein-ligand minimum distance, and protein-ligand contact number.

MM/GBSA binding free-energy estimation was performed using gmx_MMPBSA. The receptor and ligand groups were defined as Protein and LIG, respectively. The final binding free energy was calculated as:

ΔGbind = Gcomplex − Greceptor − Gligand

The final MM/GBSA binding free energy was reported as ΔTOTAL. Energy-decomposition terms included ΔVDWAALS, ΔEEL, ΔEGB, ΔESURF, ΔGGAS, and ΔGSOLV.
EOF_METHODS

cat > "$DEST/08_manuscript_text/REVIEWER_RESPONSE_SUMMARY.md" <<'EOF_RESPONSE'
# Reviewer-response summary

## Response to docking-score concern

We agree that docking scores alone have limited predictive power and should not be used as direct evidence of biological activity. In the revised workflow, docking scores were used only as an initial prioritization criterion. The three SPR-validated A35R ligands were further subjected to 100 ns GROMACS MD simulations with three independent replicates per ligand.

## Added post-docking refinement

The revised analysis now includes:
- protein backbone RMSD
- ligand heavy-atom RMSD
- protein backbone RMSF
- radius of gyration
- protein-ligand hydrogen bonds
- protein-ligand minimum distance
- protein-ligand contact number

These analyses assess whether the docking-derived binding poses remain stable after explicit-solvent MD relaxation.

## Added quantitative energy decomposition

MM/GBSA binding free-energy estimation was performed using equilibrated MD frames. The final binding free energy was calculated as:

ΔGbind = Gcomplex − Greceptor − Gligand

The reported ΔTOTAL values and energy-decomposition terms provide quantitative evidence beyond static docking poses and descriptive interaction diagrams.

## Revised interpretation

The proposed binding model should be presented as a docking-, SPR-, MD-, and MM/GBSA-supported model rather than a definitive structural mechanism. Further structural biology or mutagenesis experiments would be required for definitive mechanistic validation.
EOF_RESPONSE

###############################################################################
# 9. Quality-control scripts
###############################################################################

echo "[STEP] Generate quality-control scripts"

cat > "$DEST/10_quality_control/31_check_release_integrity.sh" <<'EOF_CHECK'
#!/usr/bin/env bash
set -euo pipefail

ROOT=<REDACTED>
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

echo "============================================================"
echo "[1] Release root"
echo "============================================================"
echo "$ROOT"
date
hostname

echo
echo "============================================================"
echo "[2] Basic directory check"
echo "============================================================"

for d in \
  00_project_overview \
  01_input_core \
  02_conversion_to_gromacs \
  03_gromacs_short_test \
  04_gromacs_100ns_md \
  05_md_analysis \
  06_gmx_mmpbsa \
  07_figures_for_manuscript \
  08_manuscript_text \
  09_all_scripts_backup \
  10_quality_control \
  99_manifest
do
  if [[ -d "$ROOT/$d" ]]; then
    echo "[OK] $d"
  else
    echo "[MISSING] $d"
  fi
done

echo
echo "============================================================"
echo "[3] Check 100 ns MD logs"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    LOG="$ROOT/04_gromacs_100ns_md/logs/$SYS/$REP/md_100ns.log"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -s "$LOG" ]]; then
      echo "NO_LOG"
      continue
    fi

    if grep -qi "Finished mdrun" "$LOG"; then
      echo "FINISHED"
    else
      echo "CHECK_LOG"
    fi
  done
done

echo
echo "============================================================"
echo "[4] Check MD analysis outputs"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$ROOT/05_md_analysis/per_rep_outputs/$SYS/$REP/analysis"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -d "$D" ]]; then
      echo "NO_ANALYSIS_DIR"
      continue
    fi

    NCSV="$(find "$D" -maxdepth 1 -type f -name "*.csv" | wc -l)"
    NXVG="$(find "$D" -maxdepth 1 -type f -name "*.xvg" | wc -l)"
    echo "csv=$NCSV xvg=$NXVG"
  done
done

echo
echo "============================================================"
echo "[5] Check MM/GBSA final results and ΔTOTAL"
echo "============================================================"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    F="$ROOT/06_gmx_mmpbsa/per_rep_results/$SYS/$REP/FINAL_RESULTS_MMPBSA_GB.dat"
    printf "%-10s %-5s " "$SYS" "$REP"

    if [[ ! -s "$F" ]]; then
      echo "NO_FINAL_DAT"
      continue
    fi

    if grep -q "ΔTOTAL" "$F"; then
      DT="$(grep "ΔTOTAL" "$F" | tail -n 1 | awk '{print $2}')"
      echo "DELTA_TOTAL=$DT"
    elif grep -q "DELTA_TOTAL" "$F"; then
      DT="$(grep "DELTA_TOTAL" "$F" | tail -n 1 | awk '{print $2}')"
      echo "DELTA_TOTAL=$DT"
    else
      echo "NO_DELTA_TOTAL_FOUND"
    fi
  done
done

echo
echo "============================================================"
echo "[6] Summary tables"
echo "============================================================"

find "$ROOT/05_md_analysis/combined_tables" "$ROOT/06_gmx_mmpbsa/summary_tables" \
  -type f \( -name "*.csv" -o -name "*.txt" -o -name "*.md" \) 2>/dev/null | sort

echo
echo "============================================================"
echo "[7] Figure files"
echo "============================================================"

find "$ROOT/07_figures_for_manuscript" \
  -type f \( -name "*.pdf" -o -name "*.png" -o -name "*.svg" \) 2>/dev/null | sort | head -n 200

echo
echo "============================================================"
echo "[DONE] Release integrity check finished"
echo "============================================================"
EOF_CHECK

chmod +x "$DEST/10_quality_control/31_check_release_integrity.sh"

###############################################################################
# 10. Generate file list, size report, and checksums
###############################################################################

echo "[STEP] Generate manifest"

(
  cd "$DEST"
  find . -type f | sort > 99_manifest/FILE_LIST.txt
  du -ah . | sort -h > 99_manifest/SIZE_REPORT.txt
  find . -type f ! -path "./99_manifest/SHA256SUMS.txt" -print0 | sort -z | xargs -0 sha256sum > 99_manifest/SHA256SUMS.txt
)

###############################################################################
# 11. Run integrity check once and save report
###############################################################################

echo "[STEP] Run release integrity check"

bash "$DEST/10_quality_control/31_check_release_integrity.sh" \
  > "$DEST/10_quality_control/release_integrity_check.txt" 2>&1 || true

###############################################################################
# 12. Optional tar.gz package
###############################################################################

if [[ "$CREATE_TAR" == "1" ]]; then
  echo "[STEP] Create tar.gz package"
  TAR_PATH="${DEST}.tar.gz"
  tar -czf "$TAR_PATH" -C "$(dirname "$DEST")" "$(basename "$DEST")"
  ls -lh "$TAR_PATH"
fi

###############################################################################
# 13. Final report
###############################################################################

echo
echo "============================================================"
echo "[DONE] Clean reviewer-release folder created"
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
echo "$DEST/10_quality_control/release_integrity_check.txt"
echo
echo "[INFO] Manifest:"
echo "$DEST/99_manifest/FILE_LIST.txt"
echo "$DEST/99_manifest/SIZE_REPORT.txt"
echo "$DEST/99_manifest/SHA256SUMS.txt"
echo
echo "[INFO] To inspect:"
echo "cd \"$DEST\""
echo "bash 10_quality_control/31_check_release_integrity.sh"
