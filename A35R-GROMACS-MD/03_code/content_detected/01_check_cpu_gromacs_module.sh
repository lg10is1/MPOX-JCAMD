#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# 01_check_cpu_gromacs_module.sh
# Purpose:
#   Check CPU GROMACS module environment on this HPC.
#   This version is for gromacs/2021.3-intel-2021.4.0 + gmx_mpi.
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
GMX_MODULE_ONEAPI="${GMX_MODULE_ONEAPI:-oneapi}"
GMX_MODULE_GROMACS="${GMX_MODULE_GROMACS:-gromacs/2021.3-intel-2021.4.0}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"

mkdir -p "${BASE}/logs"

echo "[INFO] BASE = ${BASE}"
echo "[INFO] Loading modules..."
set +u
module purge || true
module load "${GMX_MODULE_ONEAPI}"
module load "${GMX_MODULE_GROMACS}"
set -u

echo "[INFO] Checking commands..."
command -v "${GMX_BIN}" | tee "${BASE}/logs/gmx_mpi_path.txt"

echo "[INFO] GROMACS version:"
"${GMX_BIN}" --version | tee "${BASE}/logs/gromacs_version.txt"

echo "[INFO] MPI command check:"
if command -v mpirun >/dev/null 2>&1; then
  which mpirun | tee "${BASE}/logs/mpirun_path.txt"
  mpirun --version | head -n 20 | tee "${BASE}/logs/mpirun_version_head.txt" || true
else
  echo "[WARN] mpirun not found after module load." | tee "${BASE}/logs/mpirun_missing.log"
fi

echo "[INFO] CPU information:"
{
  echo "Date: $(date)"
  echo
  echo "Hostname: $(hostname)"
  echo
  echo "lscpu:"
  lscpu || true
  echo
  echo "Loaded modules:"
  module list 2>&1 || true
} | tee "${BASE}/logs/cpu_gromacs_environment.txt"

echo "[INFO] Checking project directories:"
for d in systems ligand_params; do
  if [[ -d "${BASE}/${d}" ]]; then
    echo "[OK] ${BASE}/${d}"
  else
    echo "[WARN] Missing ${BASE}/${d}"
  fi
done

echo "[DONE] CPU GROMACS module check finished."

