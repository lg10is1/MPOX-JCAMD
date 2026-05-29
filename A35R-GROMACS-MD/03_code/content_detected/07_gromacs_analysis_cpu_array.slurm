#!/bin/bash
#SBATCH --job-name=A35R_gmx_analysis
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=64
#SBATCH --array=0-8
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -euo pipefail

# ================================================================
# 07_gromacs_analysis_cpu_array.slurm
# Purpose:
#   Analyze 100 ns trajectories:
#     - PBC nojump/center/fit
#     - protein backbone RMSD
#     - ligand heavy-atom RMSD
#     - protein backbone RMSF
#     - protein radius of gyration
#     - protein-ligand H-bonds
#     - protein-ligand minimum distance / contacts
#     - xvg -> csv
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

SYS_INDEX=$((SLURM_ARRAY_TASK_ID / 3))
REP_INDEX=$((SLURM_ARRAY_TASK_ID % 3))

SYS="${SYSTEMS[$SYS_INDEX]}"
REP="${REPS[$REP_INDEX]}"

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

export OMP_NUM_THREADS=1

mkdir -p "${BASE}/logs"
cd "${BASE}"

RUNDIR="${BASE}/gmx_md100_3rep/${SYS}/${REP}"
ANADIR="${RUNDIR}/analysis"
mkdir -p "${ANADIR}"

if [[ ! -s "${RUNDIR}/md_100ns.tpr" || ! -s "${RUNDIR}/md_100ns.xtc" ]]; then
  echo "[ERROR] Missing md_100ns.tpr or md_100ns.xtc in ${RUNDIR}" >&2
  exit 1
fi

cd "${RUNDIR}"

echo "[INFO] Analysis for ${SYS} ${REP} started at $(date)"

# 1) PBC processing
if [[ ! -s "${ANADIR}/md_100ns_nojump.xtc" ]]; then
  echo "[STEP] trjconv nojump"
  printf "System\n" | "${GMX_BIN}" trjconv \
    -s md_100ns.tpr \
    -f md_100ns.xtc \
    -n index.ndx \
    -o "${ANADIR}/md_100ns_nojump.xtc" \
    -pbc nojump
fi

if [[ ! -s "${ANADIR}/md_100ns_center.xtc" ]]; then
  echo "[STEP] trjconv center protein"
  printf "Protein\nSystem\n" | "${GMX_BIN}" trjconv \
    -s md_100ns.tpr \
    -f "${ANADIR}/md_100ns_nojump.xtc" \
    -n index.ndx \
    -o "${ANADIR}/md_100ns_center.xtc" \
    -pbc mol \
    -center \
    -ur compact
fi

if [[ ! -s "${ANADIR}/md_100ns_fit.xtc" ]]; then
  echo "[STEP] trjconv fit backbone"
  printf "Backbone\nSystem\n" | "${GMX_BIN}" trjconv \
    -s md_100ns.tpr \
    -f "${ANADIR}/md_100ns_center.xtc" \
    -n index.ndx \
    -o "${ANADIR}/md_100ns_fit.xtc" \
    -fit rot+trans
fi

# 2) RMSD backbone
echo "[STEP] protein backbone RMSD"
printf "Backbone\nBackbone\n" | "${GMX_BIN}" rms \
  -s md_100ns.tpr \
  -f "${ANADIR}/md_100ns_fit.xtc" \
  -n index.ndx \
  -o "${ANADIR}/rmsd_backbone.xvg" \
  -tu ns

# 3) Ligand heavy RMSD after protein fitting
echo "[STEP] ligand heavy-atom RMSD"
printf "Ligand_Heavy\nLigand_Heavy\n" | "${GMX_BIN}" rms \
  -s md_100ns.tpr \
  -f "${ANADIR}/md_100ns_fit.xtc" \
  -n index.ndx \
  -o "${ANADIR}/rmsd_ligand_heavy.xvg" \
  -tu ns || {
    echo "[WARN] Ligand_Heavy RMSD failed. Check index.ndx group Ligand_Heavy."
  }

# 4) RMSF backbone by residue
echo "[STEP] protein backbone RMSF"
printf "Backbone\n" | "${GMX_BIN}" rmsf \
  -s md_100ns.tpr \
  -f "${ANADIR}/md_100ns_fit.xtc" \
  -n index.ndx \
  -o "${ANADIR}/rmsf_backbone_residue.xvg" \
  -res || {
    echo "[WARN] RMSF failed."
  }

# 5) Radius of gyration
echo "[STEP] protein radius of gyration"
printf "Protein\n" | "${GMX_BIN}" gyrate \
  -s md_100ns.tpr \
  -f "${ANADIR}/md_100ns_fit.xtc" \
  -n index.ndx \
  -o "${ANADIR}/gyrate_protein.xvg" || {
    echo "[WARN] gyrate failed."
  }

# 6) H-bonds protein-ligand
echo "[STEP] protein-ligand hydrogen bonds"
printf "Protein\nLigand\n" | "${GMX_BIN}" hbond \
  -s md_100ns.tpr \
  -f "${ANADIR}/md_100ns_center.xtc" \
  -n index.ndx \
  -num "${ANADIR}/hbond_prot_lig.xvg" \
  -dist "${ANADIR}/hbond_dist_prot_lig.xvg" \
  -ang "${ANADIR}/hbond_ang_prot_lig.xvg" || {
    echo "[WARN] hbond failed. This can happen if ligand group has no donor/acceptor recognized by GROMACS."
  }

# 7) Minimum distance/contact
echo "[STEP] protein-ligand minimum distance and contacts"
printf "Protein\nLigand_Heavy\n" | "${GMX_BIN}" mindist \
  -s md_100ns.tpr \
  -f "${ANADIR}/md_100ns_center.xtc" \
  -n index.ndx \
  -od "${ANADIR}/mindist_prot_lig.xvg" \
  -on "${ANADIR}/contacts_prot_lig.xvg" \
  -d 0.35 \
  -group || {
    echo "[WARN] mindist failed."
  }

# 8) Convert XVG to CSV
echo "[STEP] xvg -> csv"
python3 "${BASE}/scripts/xvg_to_csv.py" "${ANADIR}"/*.xvg || true

echo "[DONE] Analysis finished for ${SYS} ${REP} at $(date)"
echo "[DONE] Results: ${ANADIR}"

