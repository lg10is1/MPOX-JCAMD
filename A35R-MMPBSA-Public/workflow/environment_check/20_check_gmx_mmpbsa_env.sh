#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-<PROJECT_ROOT>}"
cd "$BASE"

echo "============================================================"
echo "[1] Basic path"
echo "============================================================"
pwd
hostname
date

echo
echo "============================================================"
echo "[2] Try module information"
echo "============================================================"
if type module >/dev/null 2>&1; then
  module avail gmx 2>&1 | head -n 80 || true
  module avail gmx_mmpbsa 2>&1 || true
  module avail gmx_MMPBSA 2>&1 || true
else
  echo "[WARN] module command not available in current shell."
fi

echo
echo "============================================================"
echo "[3] Try to load common SJTU/Siyuan gmx_MMPBSA environment"
echo "============================================================"
set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  echo "[INFO] Found gmx_MMPBSA_1.5.2 wrapper. Running it once to initialize environment."
  gmx_MMPBSA_1.5.2 || true
fi

echo
echo "============================================================"
echo "[4] Executables"
echo "============================================================"
for exe in gmx_MMPBSA gmx_MMPBSA_test gmx gmx_mpi mpirun MMPBSA.py cpptraj antechamber parmchk2 python3; do
  printf "%-20s : " "$exe"
  command -v "$exe" || true
done

echo
echo "============================================================"
echo "[5] Versions"
echo "============================================================"
if command -v gmx_MMPBSA >/dev/null 2>&1; then
  gmx_MMPBSA -v || true
  gmx_MMPBSA -h | head -n 60 || true
else
  echo "[ERROR] gmx_MMPBSA not found."
  echo "        Please use either module load gmx_mmpbsa/... or create conda env with 20A_create_conda_env_gmxMMPBSA.sh"
fi

echo
if command -v gmx >/dev/null 2>&1; then
  echo "[INFO] gmx version:"
  gmx --version | head -n 40 || true
else
  echo "[WARN] ordinary gmx not found."
  echo "       gmx_MMPBSA MPI mode prefers ordinary gmx rather than gmx_mpi."
fi

echo
if command -v gmx_mpi >/dev/null 2>&1; then
  echo "[INFO] gmx_mpi version:"
  gmx_mpi --version | head -n 30 || true
fi

echo
echo "============================================================"
echo "[6] AMBERHOME / Python packages"
echo "============================================================"
echo "AMBERHOME=${AMBERHOME:-NA}"
python3 - <<'PY' || true
mods = ["numpy", "scipy", "pandas", "matplotlib", "mpi4py"]
for m in mods:
    try:
        mod = __import__(m)
        print(f"{m:12s}: OK  {getattr(mod, '__version__', 'NA')}")
    except Exception as e:
        print(f"{m:12s}: MISSING  {e}")
PY

echo
echo "============================================================"
echo "[7] gmx_MMPBSA create_input quick test"
echo "============================================================"
if command -v gmx_MMPBSA >/dev/null 2>&1; then
  mkdir -p gmx_mmpbsa_env_test
  cd gmx_mmpbsa_env_test
  gmx_MMPBSA --create_input gb >/dev/null 2>&1 || true
  ls -lh || true
  cd "$BASE"
fi

echo
echo "[DONE] Environment check finished."

