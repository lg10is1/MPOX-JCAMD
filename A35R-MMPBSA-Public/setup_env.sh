#!/usr/bin/env bash
set -euo pipefail

ENV_NAME="${ENV_NAME:-a35r-mmpbsa}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v conda >/dev/null 2>&1; then
  echo "conda is required to create the documented environment." >&2
  exit 1
fi

eval "$(conda shell.bash hook)"
conda env create --name "$ENV_NAME" --file "$SCRIPT_DIR/environment.yml"
conda activate "$ENV_NAME"

gmx --version | head -n 5
gmx_MMPBSA --version
python --version

