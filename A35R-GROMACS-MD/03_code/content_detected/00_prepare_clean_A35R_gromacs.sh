#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# 00_prepare_clean_A35R_gromacs.sh
# Purpose:
#   Copy only the core Amber-prepared data from the old messy A35R folder
#   into a clean A35R-gromacs folder.
#
# Run:
#   bash 00_prepare_clean_A35R_gromacs.sh
#
# Optional:
#   OLD_BASE=/path/to/A35R NEW_BASE=/path/to/A35R-gromacs bash 00_prepare_clean_A35R_gromacs.sh
#   CLEAN=1 bash 00_prepare_clean_A35R_gromacs.sh   # remove existing copied data in NEW_BASE first
# ================================================================

OLD_BASE="${OLD_BASE:-<USER_HOME>/1_projects/PRP-MPOX-JCAMD/JCAMD-R1/AMBER/A35R}"
NEW_BASE="${NEW_BASE:-<PROJECT_ROOT>/gromacs-runs}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")

echo "[INFO] OLD_BASE = ${OLD_BASE}"
echo "[INFO] NEW_BASE = ${NEW_BASE}"

if [[ ! -d "${OLD_BASE}" ]]; then
  echo "[ERROR] OLD_BASE does not exist: ${OLD_BASE}" >&2
  exit 1
fi

if [[ "${CLEAN:-0}" == "1" ]]; then
  echo "[WARN] CLEAN=1: removing previous copied data directories in ${NEW_BASE}"
  rm -rf "${NEW_BASE}/systems" \
         "${NEW_BASE}/ligand_params" \
         "${NEW_BASE}/amber_qc" \
         "${NEW_BASE}/gromacs_systems" \
         "${NEW_BASE}/gmx_test_cpu" \
         "${NEW_BASE}/gmx_md100_3rep" \
         "${NEW_BASE}/gmx_analysis_summary" \
         "${NEW_BASE}/mdp"
fi

mkdir -p "${NEW_BASE}"
mkdir -p "${NEW_BASE}/systems"
mkdir -p "${NEW_BASE}/ligand_params"
mkdir -p "${NEW_BASE}/amber_qc"
mkdir -p "${NEW_BASE}/logs"
mkdir -p "${NEW_BASE}/scripts"

copy_one() {
  local src="$1"
  local dst="$2"
  if [[ -e "${src}" ]]; then
    mkdir -p "$(dirname "${dst}")"
    cp -a "${src}" "${dst}"
    echo "[COPY] ${src} -> ${dst}"
  else
    echo "[MISS] ${src}" | tee -a "${NEW_BASE}/logs/prepare_missing_files.log"
  fi
}

copy_dir_if_exists() {
  local src="$1"
  local dst="$2"
  if [[ -d "${src}" ]]; then
    mkdir -p "$(dirname "${dst}")"
    rm -rf "${dst}"
    cp -a "${src}" "${dst}"
    echo "[COPYDIR] ${src} -> ${dst}"
  else
    echo "[MISSDIR] ${src}" | tee -a "${NEW_BASE}/logs/prepare_missing_files.log"
  fi
}

echo "[INFO] Copying receptor structure and global files..."
copy_one "${OLD_BASE}/A35R.pdb" "${NEW_BASE}/A35R.pdb"

# Copy optional global logs or test summaries without dragging the entire old folder.
for f in README README.txt notes.txt; do
  [[ -e "${OLD_BASE}/${f}" ]] && copy_one "${OLD_BASE}/${f}" "${NEW_BASE}/${f}"
done

echo "[INFO] Copying ligand parameter folders..."
for SYS in "${SYSTEMS[@]}"; do
  copy_dir_if_exists "${OLD_BASE}/ligand_params/${SYS}" "${NEW_BASE}/ligand_params/${SYS}"
done

echo "[INFO] Copying core Amber system files..."
CORE_FILES=(
  "complex_solvated.prmtop"
  "complex_solvated.inpcrd"
  "complex_dry.prmtop"
  "receptor.prmtop"
  "ligand.prmtop"
  "REBUILD_DONE.flag"
  "lig_prot_clash_summary.txt"
  "bad_contacts_summary.txt"
  "charge_check.txt"
)

for SYS in "${SYSTEMS[@]}"; do
  mkdir -p "${NEW_BASE}/systems/${SYS}"
  for f in "${CORE_FILES[@]}"; do
    copy_one "${OLD_BASE}/systems/${SYS}/${f}" "${NEW_BASE}/systems/${SYS}/${f}"
  done

  # Copy Amber short-test final files only, not the full noisy directory.
  mkdir -p "${NEW_BASE}/amber_qc/${SYS}"
  copy_one "${OLD_BASE}/test_md_short/${SYS}/03_prod_test_20ps.rst" "${NEW_BASE}/amber_qc/${SYS}/03_prod_test_20ps.rst"
  copy_one "${OLD_BASE}/test_md_short/${SYS}/03_prod_test_20ps.nc"  "${NEW_BASE}/amber_qc/${SYS}/03_prod_test_20ps.nc"
  copy_one "${OLD_BASE}/test_md_short/${SYS}/03_prod_test_20ps.out" "${NEW_BASE}/amber_qc/${SYS}/03_prod_test_20ps.out"
  copy_one "${OLD_BASE}/test_md_short/${SYS}/03_prod_test_20ps.mdout" "${NEW_BASE}/amber_qc/${SYS}/03_prod_test_20ps.mdout"
done

echo "[INFO] Writing manifest..."
{
  echo "A35R-gromacs clean project manifest"
  echo "Created: $(date)"
  echo "OLD_BASE=${OLD_BASE}"
  echo "NEW_BASE=${NEW_BASE}"
  echo
  echo "Copied files:"
  find "${NEW_BASE}" -maxdepth 4 -type f | sort
} > "${NEW_BASE}/MANIFEST_A35R_GROMACS.txt"

echo "[INFO] Checking required files..."
FAIL=0
for SYS in "${SYSTEMS[@]}"; do
  for f in complex_solvated.prmtop complex_solvated.inpcrd; do
    if [[ ! -s "${NEW_BASE}/systems/${SYS}/${f}" ]]; then
      echo "[ERROR] Required file missing or empty: ${NEW_BASE}/systems/${SYS}/${f}" >&2
      FAIL=1
    fi
  done
done

if [[ "${FAIL}" -ne 0 ]]; then
  echo "[ERROR] Some required files are missing. Check ${NEW_BASE}/logs/prepare_missing_files.log" >&2
  exit 1
fi

echo
echo "[DONE] Clean project is ready:"
echo "       ${NEW_BASE}"
echo
echo "Next:"
echo "  cd ${NEW_BASE}"
echo "  bash 01_check_cpu_gromacs_module.sh"
echo "  bash 02_convert_amber_to_gromacs_parmed.sh"
echo "  bash 03_make_gromacs_mdp_cpu.sh"

