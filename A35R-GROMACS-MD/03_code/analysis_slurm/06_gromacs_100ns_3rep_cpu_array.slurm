#!/bin/bash

#SBATCH --job-name=A35R_gmx_100ns_3rep
#SBATCH --partition=<REDACTED>
#SBATCH -N 3
#SBATCH --ntasks-per-node=64
#SBATCH --array=0-8
#SBATCH --output=logs/gmx_100ns_3rep_%A_%a.out
#SBATCH --error=logs/gmx_100ns_3rep_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

SYS_INDEX=$((SLURM_ARRAY_TASK_ID / 3))
REP_INDEX=$((SLURM_ARRAY_TASK_ID % 3))

SYS="${SYSTEMS[$SYS_INDEX]}"
REP="${REPS[$REP_INDEX]}"

cd "$BASE"

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

GMX="gmx_mpi"
NTASKS="${SLURM_NTASKS:-192}"
MPI_RUN="mpirun -np ${NTASKS}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=$BASE"
echo "[INFO] SYS=$SYS"
echo "[INFO] REP=$REP"
echo "[INFO] ARRAY_ID=$SLURM_ARRAY_TASK_ID"
echo "[INFO] SYS_INDEX=$SYS_INDEX"
echo "[INFO] REP_INDEX=$REP_INDEX"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"
echo "[INFO] SLURM_NNODES=${SLURM_NNODES:-NA}"
echo "[INFO] GMX=$GMX"
echo "[INFO] MPI_RUN=$MPI_RUN"

$GMX --version

IN_DIR="$BASE/gromacs_systems/$SYS"
OUT_DIR="$BASE/gmx_md100_3rep/$SYS/$REP"

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

mkdir -p "$OUT_DIR"

if [[ ! -f "$OUT_DIR/topol.top" ]]; then
  cp -av "$IN_DIR"/* "$OUT_DIR"/
fi

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
  drugs2263) BASE_SEED=226300 ;;
  drugs3003) BASE_SEED=300300 ;;
  drugs3523) BASE_SEED=352300 ;;
  *) BASE_SEED=100000 ;;
esac

SEED=$((BASE_SEED + REP_INDEX + 1))

NVT_MDP_LOCAL="nvt_100ps_${REP}_seeded.mdp"
make_seeded_mdp "$BASE/mdp/nvt_100ps.template.mdp" "$NVT_MDP_LOCAL" "$SEED"

echo "[INFO] Random seed for velocity generation: $SEED"

###############################################################################
# Step 1. Energy minimization
###############################################################################
if [[ ! -f em.gro ]]; then
  echo "[STEP] grompp EM: $SYS $REP"
  $GMX grompp \
    -f "$BASE/mdp/em.mdp" \
    -c conf.gro \
    -p topol.top \
    -n index.ndx \
    -o em.tpr \
    -po em_out.mdp \
    -maxwarn 1

  echo "[STEP] mdrun EM: $SYS $REP"
  echo "[NOTE] EM uses integrator=steep, so DO NOT use -dlb yes here."
  $MPI_RUN $GMX mdrun \
    -deffnm em \
    -v \
    -pin on \
    -ntomp 1
else
  echo "[SKIP] em.gro already exists"
fi

if [[ ! -f em.gro ]]; then
  echo "[ERROR] EM failed: em.gro not generated"
  exit 1
fi

###############################################################################
# Step 2. NVT 100 ps
###############################################################################
if [[ ! -f nvt_100ps.gro ]]; then
  echo "[STEP] grompp NVT 100 ps: $SYS $REP"
  $GMX grompp \
    -f "$NVT_MDP_LOCAL" \
    -c em.gro \
    -r em.gro \
    -p topol.top \
    -n index.ndx \
    -o nvt_100ps.tpr \
    -po nvt_100ps_out.mdp \
    -maxwarn 1

  echo "[STEP] mdrun NVT 100 ps: $SYS $REP"
  $MPI_RUN $GMX mdrun \
    -deffnm nvt_100ps \
    -dlb yes \
    -v \
    -pin on \
    -ntomp 1
else
  echo "[SKIP] nvt_100ps.gro already exists"
fi

if [[ ! -f nvt_100ps.gro ]]; then
  echo "[ERROR] NVT failed: nvt_100ps.gro not generated"
  exit 1
fi

###############################################################################
# Step 3. NPT 100 ps
###############################################################################
if [[ ! -f npt_100ps.gro ]]; then
  echo "[STEP] grompp NPT 100 ps: $SYS $REP"
  $GMX grompp \
    -f "$BASE/mdp/npt_100ps.mdp" \
    -c nvt_100ps.gro \
    -r nvt_100ps.gro \
    -t nvt_100ps.cpt \
    -p topol.top \
    -n index.ndx \
    -o npt_100ps.tpr \
    -po npt_100ps_out.mdp \
    -maxwarn 1

  echo "[STEP] mdrun NPT 100 ps: $SYS $REP"
  $MPI_RUN $GMX mdrun \
    -deffnm npt_100ps \
    -dlb yes \
    -v \
    -pin on \
    -ntomp 1
else
  echo "[SKIP] npt_100ps.gro already exists"
fi

if [[ ! -f npt_100ps.gro ]]; then
  echo "[ERROR] NPT failed: npt_100ps.gro not generated"
  exit 1
fi

###############################################################################
# Step 4. Production 100 ns
###############################################################################
if [[ ! -f md_100ns.tpr ]]; then
  echo "[STEP] grompp production 100 ns: $SYS $REP"
  $GMX grompp \
    -f "$BASE/mdp/md_100ns.mdp" \
    -c npt_100ps.gro \
    -t npt_100ps.cpt \
    -p topol.top \
    -n index.ndx \
    -o md_100ns.tpr \
    -po md_100ns_out.mdp \
    -maxwarn 1
else
  echo "[SKIP] md_100ns.tpr already exists"
fi

echo "[STEP] mdrun production 100 ns: $SYS $REP"

if [[ -f md_100ns.cpt ]]; then
  echo "[INFO] Checkpoint found. Continue from md_100ns.cpt"
  $MPI_RUN $GMX mdrun \
    -deffnm md_100ns \
    -cpi md_100ns.cpt \
    -append \
    -dlb yes \
    -v \
    -pin on \
    -ntomp 1
else
  echo "[INFO] No checkpoint found. Start new production run."
  $MPI_RUN $GMX mdrun \
    -deffnm md_100ns \
    -dlb yes \
    -v \
    -pin on \
    -ntomp 1
fi

if [[ ! -f md_100ns.gro && ! -f md_100ns.cpt ]]; then
  echo "[ERROR] production failed: neither md_100ns.gro nor md_100ns.cpt found"
  exit 1
fi

echo "[INFO] Production job finished at $(date)"
echo "[INFO] Output directory: $OUT_DIR"

echo "[INFO] Quick dangerous keyword check"
grep -iE "fatal|error|nan|shake|segmentation|abnormal|illegal|vlimit|constraint" ./*.log 2>/dev/null || true

