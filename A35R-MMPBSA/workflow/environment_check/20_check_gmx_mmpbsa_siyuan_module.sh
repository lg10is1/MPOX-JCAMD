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
echo "[2] Available gmx_MMPBSA modules"
echo "============================================================"
module avail gmx_mmpbsa 2>&1 || true
module avail gmx_MMPBSA 2>&1 || true

echo
echo "============================================================"
echo "[3] Load Siyuan container module"
echo "============================================================"
module load gmx_mmpbsa/1.5.2-gcc-9.3.0

echo "[INFO] Loaded modules:"
module list 2>&1 || true

echo
echo "============================================================"
echo "[4] Check wrapper command"
echo "============================================================"
echo "[INFO] Do NOT execute gmx_MMPBSA_1.5.2 here."
echo "[INFO] This wrapper expects ./run1.sh in the current calculation directory."

echo
printf "%-30s : " "gmx_MMPBSA_1.5.2"
command -v gmx_MMPBSA_1.5.2 || true

echo
echo "[INFO] All gmx_MMPBSA-like commands in PATH:"
compgen -c | grep -E "gmx.*MMPBSA|MMPBSA" | sort -u || true

echo
echo "============================================================"
echo "[5] Check GROMACS module for trajectory preprocessing"
echo "============================================================"
module load oneapi 2>/dev/null || true
module load gromacs/2021.3-intel-2021.4.0 2>/dev/null || true

printf "%-30s : " "gmx_mpi"
command -v gmx_mpi || true

if command -v gmx_mpi >/dev/null 2>&1; then
  gmx_mpi --version | head -n 25 || true
fi

echo
echo "============================================================"
echo "[6] Conclusion"
echo "============================================================"
echo "[OK] If gmx_MMPBSA_1.5.2 path is shown above, the module is usable."
echo "[OK] Real calculation must be submitted by SLURM and must create run1.sh in each run directory."
echo "[OK] Missing host command 'gmx_MMPBSA' is normal for this container version."
echo "[OK] Missing mpi4py in amber_rebuild is irrelevant for this container version."

