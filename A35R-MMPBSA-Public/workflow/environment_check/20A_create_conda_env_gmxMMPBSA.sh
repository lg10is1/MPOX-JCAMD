#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "[INFO] Creating conda environment: gmxMMPBSA"
echo "============================================================"

if ! command -v conda >/dev/null 2>&1; then
  echo "[ERROR] conda not found in PATH."
  exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

conda create -n gmxMMPBSA python=3.11 -y
conda activate gmxMMPBSA

conda install -c conda-forge \
  "mpi4py=4.0.1" \
  "ambertools<24" \
  "numpy=1.26.4" \
  "matplotlib=3.7.3" \
  "scipy=1.14.1" \
  "pandas=1.5.3" \
  "seaborn=0.11.2" \
  "gromacs<2026" \
  pocl \
  -y

python -m pip install gmx_MMPBSA

echo
echo "============================================================"
echo "[INFO] Check installed tools"
echo "============================================================"
which gmx_MMPBSA
gmx_MMPBSA -v || true
which gmx
gmx --version | head -n 30 || true
echo "AMBERHOME=${AMBERHOME:-NA}"

echo
echo "[DONE] Conda environment gmxMMPBSA created."
echo "Use:"
echo "  conda activate gmxMMPBSA"

