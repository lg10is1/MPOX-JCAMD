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


