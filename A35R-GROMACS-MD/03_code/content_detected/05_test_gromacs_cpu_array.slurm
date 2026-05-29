#!/bin/bash

#SBATCH --job-name=A35R_gmx_test_array
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=64
#SBATCH --array=0-2
#SBATCH --output=logs/gmx_test_array_%A_%a.out
#SBATCH --error=logs/gmx_test_array_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
SYS="${SYSTEMS[$SLURM_ARRAY_TASK_ID]}"

cd "$BASE"

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

GMX="gmx_mpi"
NTASKS="${SLURM_NTASKS:-64}"
MPI_RUN="mpirun -np ${NTASKS}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=$BASE"
echo "[INFO] SYS=$SYS"
echo "[INFO] ARRAY_ID=$SLURM_ARRAY_TASK_ID"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"
echo "[INFO] SLURM_NNODES=${SLURM_NNODES:-NA}"
echo "[INFO] GMX=$GMX"
echo "[INFO] MPI_RUN=$MPI_RUN"

$GMX --version

IN_DIR="$BASE/gromacs_systems/$SYS"
OUT_DIR="$BASE/gmx_test_cpu/$SYS"

if [[ ! -d "$IN_DIR" ]]; then
  echo "[ERROR] Missing input directory: $IN_DIR"
  exit 1
fi

for f in conf.gro topol.top index.ndx; do
  if [[ ! -f "$IN_DIR/$f" ]]; then
    echo "[ERROR] Missing required file: $IN_DIR/$f"
    exit 1
  fi
done

rm -rf "$OUT_DIR"
mkdir -p "$OUT_DIR"

cp -av "$IN_DIR"/* "$OUT_DIR"/
cd "$OUT_DIR"

make_seeded_mdp() {
  local in_mdp="$1"
  local out_mdp="$2"
  local seed="$3"

  if [[ ! -f "$in_mdp" ]]; then
    echo "[ERROR] Missing mdp template: $in_mdp"
    exit 1
  fi

  cp "$in_mdp" "$out_mdp"

  sed -i "s/GEN_SEED_PLACEHOLDER/${seed}/g" "$out_mdp" || true
  sed -i "s/GEN_SEED_REPLACE/${seed}/g" "$out_mdp" || true
  sed -i "s/__GEN_SEED__/${seed}/g" "$out_mdp" || true

  if grep -qE '^[[:space:]]*gen_seed[[:space:]]*=' "$out_mdp"; then
    sed -i "s/^[[:space:]]*gen_seed[[:space:]]*=.*/gen_seed                = ${seed}/" "$out_mdp"
  fi
}

case "$SYS" in
  drugs2263) SEED=226301 ;;
  drugs3003) SEED=300301 ;;
  drugs3523) SEED=352301 ;;
  *) SEED=$((100000 + SLURM_ARRAY_TASK_ID)) ;;
esac

NVT_MDP_LOCAL="nvt_20ps_seeded.mdp"
make_seeded_mdp "$BASE/mdp/nvt_20ps.template.mdp" "$NVT_MDP_LOCAL" "$SEED"

echo "[STEP] grompp EM: $SYS"
$GMX grompp \
  -f "$BASE/mdp/em.mdp" \
  -c conf.gro \
  -p topol.top \
  -n index.ndx \
  -o em.tpr \
  -po em_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun EM: $SYS"
echo "[NOTE] EM uses integrator=steep, so DO NOT use -dlb yes here."
$MPI_RUN $GMX mdrun \
  -deffnm em \
  -v \
  -pin on \
  -ntomp 1

if [[ ! -f em.gro ]]; then
  echo "[ERROR] EM failed: em.gro not generated"
  exit 1
fi

echo "[STEP] grompp NVT 20 ps: $SYS"
$GMX grompp \
  -f "$NVT_MDP_LOCAL" \
  -c em.gro \
  -r em.gro \
  -p topol.top \
  -n index.ndx \
  -o nvt_20ps.tpr \
  -po nvt_20ps_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun NVT 20 ps: $SYS"
$MPI_RUN $GMX mdrun \
  -deffnm nvt_20ps \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

if [[ ! -f nvt_20ps.gro ]]; then
  echo "[ERROR] NVT failed: nvt_20ps.gro not generated"
  exit 1
fi

echo "[STEP] grompp NPT 20 ps: $SYS"
$GMX grompp \
  -f "$BASE/mdp/npt_20ps.mdp" \
  -c nvt_20ps.gro \
  -r nvt_20ps.gro \
  -t nvt_20ps.cpt \
  -p topol.top \
  -n index.ndx \
  -o npt_20ps.tpr \
  -po npt_20ps_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun NPT 20 ps: $SYS"
$MPI_RUN $GMX mdrun \
  -deffnm npt_20ps \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

if [[ ! -f npt_20ps.gro ]]; then
  echo "[ERROR] NPT failed: npt_20ps.gro not generated"
  exit 1
fi

echo "[STEP] grompp production 20 ps: $SYS"
$GMX grompp \
  -f "$BASE/mdp/md_20ps.mdp" \
  -c npt_20ps.gro \
  -t npt_20ps.cpt \
  -p topol.top \
  -n index.ndx \
  -o md_20ps.tpr \
  -po md_20ps_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun production 20 ps: $SYS"
$MPI_RUN $GMX mdrun \
  -deffnm md_20ps \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

if [[ ! -f md_20ps.gro ]]; then
  echo "[ERROR] production test failed: md_20ps.gro not generated"
  exit 1
fi

echo "[INFO] Array test finished successfully at $(date)"
echo "[INFO] Output directory: $OUT_DIR"

echo "[INFO] Quick dangerous keyword check"
grep -iE "fatal|error|nan|shake|segmentation|abnormal|illegal|vlimit|constraint" ./*.log ./*.edr ./*.xvg 2>/dev/null || true

