#!/usr/bin/env bash
set -euo pipefail

NEW_BASE="${NEW_BASE:-<PROJECT_ROOT>/gromacs-runs}"
mkdir -p "${NEW_BASE}/scripts" "${NEW_BASE}/logs"
cd "${NEW_BASE}"

echo "[INFO] Creating A35R GROMACS CPU workflow scripts in: ${NEW_BASE}"

mkdir -p "$(dirname '00_prepare_clean_A35R_gromacs.sh')"
cat > '00_prepare_clean_A35R_gromacs.sh' <<'__A35R_SCRIPT_EOF__'
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

__A35R_SCRIPT_EOF__
chmod +x '00_prepare_clean_A35R_gromacs.sh'
mkdir -p "$(dirname '01_check_cpu_gromacs_module.sh')"
cat > '01_check_cpu_gromacs_module.sh' <<'__A35R_SCRIPT_EOF__'
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

__A35R_SCRIPT_EOF__
chmod +x '01_check_cpu_gromacs_module.sh'
mkdir -p "$(dirname '02_convert_amber_to_gromacs_parmed.sh')"
cat > '02_convert_amber_to_gromacs_parmed.sh' <<'__A35R_SCRIPT_EOF__'
#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# 02_convert_amber_to_gromacs_parmed.sh
# Purpose:
#   Convert Amber prmtop/inpcrd to GROMACS topol.top/conf.gro
#   using ParmEd, preserving Amber/GAFF2 parameters as much as possible.
#
# Why ParmEd:
#   Your inputs are already complete Amber systems:
#     systems/${SYS}/complex_solvated.prmtop
#     systems/${SYS}/complex_solvated.inpcrd
#   ParmEd directly reads these files and exports GROMACS topology/coordinates.
#
# Requirement:
#   conda activate an environment with parmed installed.
#   Example:
#     conda activate ambertools_local
#     python -c "import parmed"
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")

mkdir -p "${BASE}/gromacs_systems" "${BASE}/logs" "${BASE}/scripts"

echo "[INFO] BASE = ${BASE}"

python - <<'PY'
import sys
try:
    import parmed
    print("[OK] ParmEd import succeeded:", parmed.__version__)
except Exception as e:
    print("[ERROR] ParmEd is not available in current Python environment.", file=sys.stderr)
    print("        Please run: conda activate ambertools_local", file=sys.stderr)
    print("        Then test: python -c 'import parmed; print(parmed.__version__)'", file=sys.stderr)
    print("        Original error:", repr(e), file=sys.stderr)
    sys.exit(1)
PY

cat > "${BASE}/scripts/convert_one_with_parmed.py" <<'PY'
#!/usr/bin/env python3
import os
import sys
import math
import json
from pathlib import Path

import parmed as pmd

PROTEIN_RESNAMES = {
    "ALA","ARG","ASN","ASP","CYS","CYX","CYM","GLN","GLU","GLH","GLY","HIS","HID","HIE","HIP",
    "ILE","LEU","LYS","LYN","MET","PHE","PRO","SER","THR","TRP","TYR","VAL",
    "ASH","ACE","NME","NHE"
}
WATER_RESNAMES = {"WAT","HOH","SOL","TIP3","TIP3P","H2O"}
ION_RESNAMES = {
    "NA","Na","NA+","K","K+","CL","Cl","CL-","MG","MG2","MG2+","CA","CA2","CA2+",
    "ZN","ZN2","ZN2+","MN","MN2","FE","FE2","FE3","CU","CU1","CU2"
}
BACKBONE_NAMES = {"N","CA","C","O","OXT"}

def atom_element_guess(atom):
    elem = getattr(atom, "atomic_number", 0)
    if elem and elem > 0:
        return elem
    name = atom.name.strip()
    if not name:
        return 0
    # Amber/Gromacs atom names can start with digits.
    ch = "".join([c for c in name if c.isalpha()])
    if not ch:
        return 0
    if ch.upper().startswith("H"):
        return 1
    return 6

def residue_name(atom):
    try:
        return atom.residue.name.strip()
    except Exception:
        return ""

def is_protein(atom):
    return residue_name(atom) in PROTEIN_RESNAMES

def is_water(atom):
    return residue_name(atom) in WATER_RESNAMES

def is_ion(atom):
    return residue_name(atom) in ION_RESNAMES

def is_ligand(atom):
    return (not is_protein(atom)) and (not is_water(atom)) and (not is_ion(atom))

def write_index(path, groups):
    with open(path, "w") as f:
        for name, idxs in groups.items():
            idxs = [int(x) for x in idxs if int(x) > 0]
            f.write(f"[ {name} ]\n")
            for i in range(0, len(idxs), 15):
                f.write(" ".join(str(x) for x in idxs[i:i+15]) + "\n")
            f.write("\n")

def write_posre(path, atom_indices, fc=1000):
    # These are global atom indices. They are safe only if the converted topology
    # has the restrained atoms in the same local moleculetype numbering.
    # The run scripts therefore treat position restraints as optional.
    with open(path, "w") as f:
        f.write("; Position restraints generated from converted Amber system\n")
        f.write("; Columns: atom  type  fx  fy  fz\n")
        f.write("[ position_restraints ]\n")
        for i in atom_indices:
            f.write(f"{int(i):8d}  1  {fc:8.1f}  {fc:8.1f}  {fc:8.1f}\n")

def summarize_structure(struct):
    total_charge = sum(a.charge for a in struct.atoms)
    residues = {}
    for a in struct.atoms:
        rn = residue_name(a)
        residues[rn] = residues.get(rn, 0) + 1
    protein_atoms = [a.idx + 1 for a in struct.atoms if is_protein(a)]
    ligand_atoms = [a.idx + 1 for a in struct.atoms if is_ligand(a)]
    ligand_heavy = [a.idx + 1 for a in struct.atoms if is_ligand(a) and atom_element_guess(a) != 1]
    backbone = [a.idx + 1 for a in struct.atoms if is_protein(a) and a.name.strip() in BACKBONE_NAMES]
    water_atoms = [a.idx + 1 for a in struct.atoms if is_water(a)]
    ion_atoms = [a.idx + 1 for a in struct.atoms if is_ion(a)]
    nonwater = [a.idx + 1 for a in struct.atoms if not is_water(a)]
    return {
        "n_atoms": len(struct.atoms),
        "n_residues": len(struct.residues),
        "total_charge": total_charge,
        "total_charge_rounded": round(total_charge),
        "charge_abs_diff_from_integer": abs(total_charge - round(total_charge)),
        "residue_atom_counts": residues,
        "n_protein_atoms": len(protein_atoms),
        "n_backbone_atoms": len(backbone),
        "n_ligand_atoms": len(ligand_atoms),
        "n_ligand_heavy_atoms": len(ligand_heavy),
        "n_water_atoms": len(water_atoms),
        "n_ion_atoms": len(ion_atoms),
        "n_nonwater_atoms": len(nonwater),
        "groups": {
            "System": list(range(1, len(struct.atoms)+1)),
            "Protein": protein_atoms,
            "Backbone": backbone,
            "Ligand": ligand_atoms,
            "Ligand_Heavy": ligand_heavy,
            "Water": water_atoms,
            "Ions": ion_atoms,
            "Non-Water": nonwater,
            "Protein_Ligand": protein_atoms + ligand_atoms,
        }
    }

def main():
    if len(sys.argv) != 5:
        print("Usage: convert_one_with_parmed.py SYS prmtop inpcrd outdir", file=sys.stderr)
        sys.exit(2)

    sysname, prmtop, inpcrd, outdir = sys.argv[1:]
    prmtop = Path(prmtop)
    inpcrd = Path(inpcrd)
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    if not prmtop.is_file():
        raise FileNotFoundError(prmtop)
    if not inpcrd.is_file():
        raise FileNotFoundError(inpcrd)

    print(f"[INFO] Loading Amber files for {sysname}")
    struct = pmd.load_file(str(prmtop), xyz=str(inpcrd))
    summary_before = summarize_structure(struct)

    top = outdir / "topol.top"
    gro = outdir / "conf.gro"

    print(f"[INFO] Saving GROMACS topology: {top}")
    struct.save(str(top), format="gromacs", overwrite=True)

    print(f"[INFO] Saving GROMACS coordinate: {gro}")
    struct.save(str(gro), overwrite=True)

    print("[INFO] Reloading converted GROMACS files for validation")
    gmx_struct = pmd.load_file(str(top), xyz=str(gro))
    summary_after = summarize_structure(gmx_struct)

    ndx = outdir / "index.ndx"
    write_index(ndx, summary_before["groups"])

    write_posre(outdir / "posre_Protein.itp", summary_before["groups"]["Protein"], fc=1000)
    write_posre(outdir / "posre_Backbone.itp", summary_before["groups"]["Backbone"], fc=1000)
    write_posre(outdir / "posre_Ligand_Heavy.itp", summary_before["groups"]["Ligand_Heavy"], fc=1000)
    write_posre(outdir / "posre_Protein_Ligand.itp", summary_before["groups"]["Protein_Ligand"], fc=1000)

    report = {
        "system": sysname,
        "input_prmtop": str(prmtop),
        "input_inpcrd": str(inpcrd),
        "output_topol": str(top),
        "output_conf": str(gro),
        "amber_summary": {k:v for k,v in summary_before.items() if k != "groups"},
        "gromacs_reloaded_summary": {k:v for k,v in summary_after.items() if k != "groups"},
        "atom_count_match": summary_before["n_atoms"] == summary_after["n_atoms"],
        "charge_difference_after_reload": summary_after["total_charge"] - summary_before["total_charge"],
        "notes": [
            "ParmEd conversion keeps the Amber-derived force-field parameters in the exported GROMACS topology.",
            "Position restraint files are generated for convenience but are not automatically inserted into topol.top.",
            "Equilibration scripts below use unrestrained NVT/NPT by default for maximum compatibility after Amber-to-GROMACS conversion.",
            "If you want restraints, inspect topol.top carefully and insert the posre include under the correct moleculetype."
        ],
    }

    with open(outdir / "conversion_report.json", "w") as f:
        json.dump(report, f, indent=2, sort_keys=True)

    with open(outdir / "conversion_report.txt", "w") as f:
        f.write(f"System: {sysname}\n")
        f.write(f"Input prmtop: {prmtop}\n")
        f.write(f"Input inpcrd: {inpcrd}\n")
        f.write(f"Output topol.top: {top}\n")
        f.write(f"Output conf.gro: {gro}\n\n")
        f.write("Amber summary before conversion\n")
        for k, v in report["amber_summary"].items():
            f.write(f"  {k}: {v}\n")
        f.write("\nGROMACS reloaded summary\n")
        for k, v in report["gromacs_reloaded_summary"].items():
            f.write(f"  {k}: {v}\n")
        f.write("\nValidation\n")
        f.write(f"  atom_count_match: {report['atom_count_match']}\n")
        f.write(f"  charge_difference_after_reload: {report['charge_difference_after_reload']:.12g}\n")
        f.write("\nImportant notes\n")
        for note in report["notes"]:
            f.write(f"  - {note}\n")

    if not report["atom_count_match"]:
        raise RuntimeError(f"Atom count mismatch after conversion for {sysname}")

    if abs(report["charge_difference_after_reload"]) > 1e-4:
        raise RuntimeError(f"Charge changed after conversion for {sysname}")

    print(f"[DONE] Converted {sysname}")
    print(f"       top: {top}")
    print(f"       gro: {gro}")
    print(f"       ndx: {ndx}")
    print(f"       report: {outdir / 'conversion_report.txt'}")

if __name__ == "__main__":
    main()
PY
chmod +x "${BASE}/scripts/convert_one_with_parmed.py"

for SYS in "${SYSTEMS[@]}"; do
  INDIR="${BASE}/systems/${SYS}"
  OUTDIR="${BASE}/gromacs_systems/${SYS}"
  PRMTOP="${INDIR}/complex_solvated.prmtop"
  INPCRD="${INDIR}/complex_solvated.inpcrd"

  echo
  echo "============================================================"
  echo "[INFO] Converting ${SYS}"
  echo "============================================================"

  if [[ ! -s "${PRMTOP}" || ! -s "${INPCRD}" ]]; then
    echo "[ERROR] Missing input for ${SYS}:"
    echo "        ${PRMTOP}"
    echo "        ${INPCRD}"
    exit 1
  fi

  mkdir -p "${OUTDIR}"
  python "${BASE}/scripts/convert_one_with_parmed.py" "${SYS}" "${PRMTOP}" "${INPCRD}" "${OUTDIR}" \
    2>&1 | tee "${BASE}/logs/convert_${SYS}.log"
done

echo
echo "[INFO] Conversion reports:"
for SYS in "${SYSTEMS[@]}"; do
  echo "---- ${SYS} ----"
  sed -n '1,80p' "${BASE}/gromacs_systems/${SYS}/conversion_report.txt"
done

echo "[DONE] Amber -> GROMACS conversion finished."

__A35R_SCRIPT_EOF__
chmod +x '02_convert_amber_to_gromacs_parmed.sh'
mkdir -p "$(dirname '03_make_gromacs_mdp_cpu.sh')"
cat > '03_make_gromacs_mdp_cpu.sh' <<'__A35R_SCRIPT_EOF__'
#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# 03_make_gromacs_mdp_cpu.sh
# Purpose:
#   Create GROMACS .mdp files for CPU GROMACS 2021:
#   - minimization
#   - short 20 ps NVT/NPT/production test
#   - 100 ps NVT/NPT equilibration
#   - 100 ns production
#
# Notes:
#   - dt = 0.002 ps.
#   - 20 ps = 10,000 steps.
#   - 100 ps = 50,000 steps.
#   - 100 ns = 50,000,000 steps.
#   - tc-grps = System for maximum compatibility.
#   - Position restraints are not enabled by default because ParmEd-converted
#     topologies can differ in moleculetype organization.
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
MDPDIR="${BASE}/mdp"

mkdir -p "${MDPDIR}"

cat > "${MDPDIR}/em.mdp" <<'EOF'
; Energy minimization
integrator              = steep
emtol                   = 1000.0
emstep                  = 0.01
nsteps                  = 50000

; Neighbor searching
cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

; Electrostatics and VdW
coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

; Constraints
constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

; Output
nstenergy               = 500
nstlog                  = 500

; Periodic boundary conditions
pbc                     = xyz
EOF

cat > "${MDPDIR}/nvt_20ps.template.mdp" <<'EOF'
; 20 ps NVT heating / short test
define                  =
integrator              = md
dt                      = 0.002
nsteps                  = 10000
continuation            = no

; Initial velocities
gen_vel                 = yes
gen_temp                = 300
gen_seed                = GEN_SEED_PLACEHOLDER

; Neighbor searching
cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

; Electrostatics and VdW
coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

; Temperature coupling
tcoupl                  = V-rescale
tc-grps                 = System
tau_t                   = 0.1
ref_t                   = 300

; Pressure coupling
pcoupl                  = no

; Constraints
constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

; Output
nstxout                 = 0
nstvout                 = 0
nstfout                 = 0
nstenergy               = 500
nstlog                  = 500
nstxout-compressed      = 500
compressed-x-grps       = System

; Periodic boundary conditions
pbc                     = xyz
EOF

cat > "${MDPDIR}/npt_20ps.mdp" <<'EOF'
; 20 ps NPT equilibration / short test
define                  =
integrator              = md
dt                      = 0.002
nsteps                  = 10000
continuation            = yes

gen_vel                 = no

; Neighbor searching
cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

; Electrostatics and VdW
coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

; Temperature coupling
tcoupl                  = V-rescale
tc-grps                 = System
tau_t                   = 0.1
ref_t                   = 300

; Pressure coupling
pcoupl                  = Berendsen
pcoupltype              = isotropic
tau_p                   = 2.0
ref_p                   = 1.0
compressibility         = 4.5e-5

; Constraints
constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

; Output
nstxout                 = 0
nstvout                 = 0
nstfout                 = 0
nstenergy               = 500
nstlog                  = 500
nstxout-compressed      = 500
compressed-x-grps       = System

; Periodic boundary conditions
pbc                     = xyz
EOF

cat > "${MDPDIR}/md_20ps.mdp" <<'EOF'
; 20 ps production test
integrator              = md
dt                      = 0.002
nsteps                  = 10000
continuation            = yes

gen_vel                 = no

; Neighbor searching
cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

; Electrostatics and VdW
coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

; Temperature coupling
tcoupl                  = V-rescale
tc-grps                 = System
tau_t                   = 0.1
ref_t                   = 300

; Pressure coupling
pcoupl                  = Parrinello-Rahman
pcoupltype              = isotropic
tau_p                   = 2.0
ref_p                   = 1.0
compressibility         = 4.5e-5

; Constraints
constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

; Center of mass motion removal
comm-mode               = Linear
nstcomm                 = 100
comm-grps               = System

; Output
nstxout                 = 0
nstvout                 = 0
nstfout                 = 0
nstenergy               = 500
nstlog                  = 500
nstxout-compressed      = 500
compressed-x-grps       = System

; Periodic boundary conditions
pbc                     = xyz
EOF

cat > "${MDPDIR}/nvt_100ps.template.mdp" <<'EOF'
; 100 ps NVT equilibration for production run
define                  =
integrator              = md
dt                      = 0.002
nsteps                  = 50000
continuation            = no

gen_vel                 = yes
gen_temp                = 300
gen_seed                = GEN_SEED_PLACEHOLDER

cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

tcoupl                  = V-rescale
tc-grps                 = System
tau_t                   = 0.1
ref_t                   = 300

pcoupl                  = no

constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

nstxout                 = 0
nstvout                 = 0
nstfout                 = 0
nstenergy               = 1000
nstlog                  = 1000
nstxout-compressed      = 1000
compressed-x-grps       = System

pbc                     = xyz
EOF

cat > "${MDPDIR}/npt_100ps.mdp" <<'EOF'
; 100 ps NPT equilibration for production run
define                  =
integrator              = md
dt                      = 0.002
nsteps                  = 50000
continuation            = yes

gen_vel                 = no

cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

tcoupl                  = V-rescale
tc-grps                 = System
tau_t                   = 0.1
ref_t                   = 300

pcoupl                  = Berendsen
pcoupltype              = isotropic
tau_p                   = 2.0
ref_p                   = 1.0
compressibility         = 4.5e-5

constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

nstxout                 = 0
nstvout                 = 0
nstfout                 = 0
nstenergy               = 1000
nstlog                  = 1000
nstxout-compressed      = 1000
compressed-x-grps       = System

pbc                     = xyz
EOF

cat > "${MDPDIR}/md_100ns.mdp" <<'EOF'
; 100 ns production MD
integrator              = md
dt                      = 0.002
nsteps                  = 50000000
continuation            = yes

gen_vel                 = no

cutoff-scheme           = Verlet
nstlist                 = 20
rlist                   = 1.0

coulombtype             = PME
rcoulomb                = 1.0
vdwtype                 = Cut-off
rvdw                    = 1.0
DispCorr                = EnerPres

tcoupl                  = V-rescale
tc-grps                 = System
tau_t                   = 0.1
ref_t                   = 300

pcoupl                  = Parrinello-Rahman
pcoupltype              = isotropic
tau_p                   = 2.0
ref_p                   = 1.0
compressibility         = 4.5e-5

constraints             = h-bonds
constraint-algorithm    = lincs
lincs_iter              = 1
lincs_order             = 4

comm-mode               = Linear
nstcomm                 = 100
comm-grps               = System

; Output every 10 ps
nstxout                 = 0
nstvout                 = 0
nstfout                 = 0
nstenergy               = 5000
nstlog                  = 5000
nstxout-compressed      = 5000
compressed-x-grps       = System

pbc                     = xyz
EOF

echo "[DONE] MDP files generated in ${MDPDIR}"
ls -lh "${MDPDIR}"

__A35R_SCRIPT_EOF__
chmod +x '03_make_gromacs_mdp_cpu.sh'
mkdir -p "$(dirname '04_test_gromacs_cpu_one.slurm')"
cat > '04_test_gromacs_cpu_one.slurm' <<'__A35R_SCRIPT_EOF__'
#!/bin/bash
#SBATCH --job-name=A35R_gmx_test_one
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=64
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

set -euo pipefail

# ================================================================
# 04_test_gromacs_cpu_one.slurm
# Purpose:
#   Run a short CPU-GROMACS test for drugs2263 only:
#     EM -> 20 ps NVT -> 20 ps NPT -> 20 ps production
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
SYS="${SYS:-drugs2263}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

export OMP_NUM_THREADS=1

mkdir -p "${BASE}/logs"
cd "${BASE}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=${BASE}"
echo "[INFO] SYS=${SYS}"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"
echo "[INFO] SLURM_NNODES=${SLURM_NNODES:-NA}"

"${GMX_BIN}" --version

RUNDIR="${BASE}/gmx_test_cpu/${SYS}"
mkdir -p "${RUNDIR}"

cp -f "${BASE}/gromacs_systems/${SYS}/conf.gro" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}/topol.top" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}/index.ndx" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}"/posre_*.itp "${RUNDIR}/" 2>/dev/null || true

cd "${RUNDIR}"

SEED=226301
sed "s/GEN_SEED_PLACEHOLDER/${SEED}/g" "${BASE}/mdp/nvt_20ps.template.mdp" > nvt_20ps.mdp

echo "[STEP] grompp EM"
"${GMX_BIN}" grompp \
  -f "${BASE}/mdp/em.mdp" \
  -c conf.gro \
  -p topol.top \
  -n index.ndx \
  -o em.tpr \
  -po em_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun EM"
mpirun "${GMX_BIN}" mdrun \
  -deffnm em \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

echo "[STEP] grompp NVT 20 ps"
"${GMX_BIN}" grompp \
  -f nvt_20ps.mdp \
  -c em.gro \
  -r em.gro \
  -p topol.top \
  -n index.ndx \
  -o nvt_20ps.tpr \
  -po nvt_20ps_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun NVT 20 ps"
mpirun "${GMX_BIN}" mdrun \
  -deffnm nvt_20ps \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

echo "[STEP] grompp NPT 20 ps"
"${GMX_BIN}" grompp \
  -f "${BASE}/mdp/npt_20ps.mdp" \
  -c nvt_20ps.gro \
  -t nvt_20ps.cpt \
  -r nvt_20ps.gro \
  -p topol.top \
  -n index.ndx \
  -o npt_20ps.tpr \
  -po npt_20ps_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun NPT 20 ps"
mpirun "${GMX_BIN}" mdrun \
  -deffnm npt_20ps \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

echo "[STEP] grompp MD 20 ps"
"${GMX_BIN}" grompp \
  -f "${BASE}/mdp/md_20ps.mdp" \
  -c npt_20ps.gro \
  -t npt_20ps.cpt \
  -p topol.top \
  -n index.ndx \
  -o md_20ps.tpr \
  -po md_20ps_out.mdp \
  -maxwarn 1

echo "[STEP] mdrun MD 20 ps"
mpirun "${GMX_BIN}" mdrun \
  -deffnm md_20ps \
  -dlb yes \
  -v \
  -pin on \
  -ntomp 1

echo "[CHECK] Searching dangerous keywords"
grep -iE "shake|nan|inf|fatal|segmentation|error|constraint|lincs warning|terminated abnormally" *.log *.edr *.out 2>/dev/null || true

echo "[DONE] Test finished at $(date)"
echo "[DONE] Results: ${RUNDIR}"

__A35R_SCRIPT_EOF__
chmod +x '04_test_gromacs_cpu_one.slurm'
mkdir -p "$(dirname '05_test_gromacs_cpu_array.slurm')"
cat > '05_test_gromacs_cpu_array.slurm' <<'__A35R_SCRIPT_EOF__'
#!/bin/bash
#SBATCH --job-name=A35R_gmx_test_array
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=64
#SBATCH --array=0-2
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -euo pipefail

# ================================================================
# 05_test_gromacs_cpu_array.slurm
# Purpose:
#   Run short CPU-GROMACS test for three systems:
#     drugs2263, drugs3003, drugs3523
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
SYS="${SYSTEMS[$SLURM_ARRAY_TASK_ID]}"

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

export OMP_NUM_THREADS=1

mkdir -p "${BASE}/logs"
cd "${BASE}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] SYS=${SYS}"
echo "[INFO] Array task: ${SLURM_ARRAY_TASK_ID}"

RUNDIR="${BASE}/gmx_test_cpu/${SYS}"
mkdir -p "${RUNDIR}"

cp -f "${BASE}/gromacs_systems/${SYS}/conf.gro" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}/topol.top" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}/index.ndx" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}"/posre_*.itp "${RUNDIR}/" 2>/dev/null || true

cd "${RUNDIR}"

SEED=$((220000 + SLURM_ARRAY_TASK_ID + 1))
sed "s/GEN_SEED_PLACEHOLDER/${SEED}/g" "${BASE}/mdp/nvt_20ps.template.mdp" > nvt_20ps.mdp

"${GMX_BIN}" grompp -f "${BASE}/mdp/em.mdp" -c conf.gro -p topol.top -n index.ndx -o em.tpr -po em_out.mdp -maxwarn 1
mpirun "${GMX_BIN}" mdrun -deffnm em -dlb yes -v -pin on -ntomp 1

"${GMX_BIN}" grompp -f nvt_20ps.mdp -c em.gro -r em.gro -p topol.top -n index.ndx -o nvt_20ps.tpr -po nvt_20ps_out.mdp -maxwarn 1
mpirun "${GMX_BIN}" mdrun -deffnm nvt_20ps -dlb yes -v -pin on -ntomp 1

"${GMX_BIN}" grompp -f "${BASE}/mdp/npt_20ps.mdp" -c nvt_20ps.gro -t nvt_20ps.cpt -r nvt_20ps.gro -p topol.top -n index.ndx -o npt_20ps.tpr -po npt_20ps_out.mdp -maxwarn 1
mpirun "${GMX_BIN}" mdrun -deffnm npt_20ps -dlb yes -v -pin on -ntomp 1

"${GMX_BIN}" grompp -f "${BASE}/mdp/md_20ps.mdp" -c npt_20ps.gro -t npt_20ps.cpt -p topol.top -n index.ndx -o md_20ps.tpr -po md_20ps_out.mdp -maxwarn 1
mpirun "${GMX_BIN}" mdrun -deffnm md_20ps -dlb yes -v -pin on -ntomp 1

echo "[CHECK] Dangerous keywords for ${SYS}"
grep -iE "shake|nan|inf|fatal|segmentation|error|constraint|lincs warning|terminated abnormally" *.log *.out 2>/dev/null || true

echo "[DONE] ${SYS} short test finished at $(date)"

__A35R_SCRIPT_EOF__
chmod +x '05_test_gromacs_cpu_array.slurm'
mkdir -p "$(dirname '06_gromacs_100ns_3rep_cpu_array.slurm')"
cat > '06_gromacs_100ns_3rep_cpu_array.slurm' <<'__A35R_SCRIPT_EOF__'
#!/bin/bash
#SBATCH --job-name=A35R_gmx_100ns_3rep
#SBATCH --partition=<REDACTED>
#SBATCH -N 3
#SBATCH --ntasks-per-node=64
#SBATCH --array=0-8
#SBATCH --output=logs/%x_%A_%a.out
#SBATCH --error=logs/%x_%A_%a.err

set -euo pipefail

# ================================================================
# 06_gromacs_100ns_3rep_cpu_array.slurm
# Purpose:
#   Run 100 ns CPU GROMACS MD for:
#     3 ligands × 3 repeats = 9 array tasks
#
# Mapping:
#   array 0: drugs2263 rep1
#   array 1: drugs2263 rep2
#   array 2: drugs2263 rep3
#   array 3: drugs3003 rep1
#   ...
#   array 8: drugs3523 rep3
#
# Workflow per task:
#   EM -> 100 ps NVT -> 100 ps NPT -> 100 ns production
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

SYS_INDEX=$((SLURM_ARRAY_TASK_ID / 3))
REP_INDEX=$((SLURM_ARRAY_TASK_ID % 3))

SYS="${SYSTEMS[$SYS_INDEX]}"
REP="${REPS[$REP_INDEX]}"

SEED=$((350000 + SYS_INDEX * 1000 + REP_INDEX + 1))

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

export OMP_NUM_THREADS=1

mkdir -p "${BASE}/logs"
cd "${BASE}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] BASE=${BASE}"
echo "[INFO] SYS=${SYS}"
echo "[INFO] REP=${REP}"
echo "[INFO] SEED=${SEED}"
echo "[INFO] SLURM_JOB_ID=${SLURM_JOB_ID:-NA}"
echo "[INFO] SLURM_ARRAY_TASK_ID=${SLURM_ARRAY_TASK_ID}"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"
echo "[INFO] SLURM_NNODES=${SLURM_NNODES:-NA}"

RUNDIR="${BASE}/gmx_md100_3rep/${SYS}/${REP}"
mkdir -p "${RUNDIR}"

cp -f "${BASE}/gromacs_systems/${SYS}/conf.gro" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}/topol.top" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}/index.ndx" "${RUNDIR}/"
cp -f "${BASE}/gromacs_systems/${SYS}"/posre_*.itp "${RUNDIR}/" 2>/dev/null || true

cd "${RUNDIR}"

sed "s/GEN_SEED_PLACEHOLDER/${SEED}/g" "${BASE}/mdp/nvt_100ps.template.mdp" > nvt_100ps.mdp

run_mdrun() {
  local deffnm="$1"
  if [[ -f "${deffnm}.log" ]] && grep -q "Finished mdrun" "${deffnm}.log"; then
    echo "[SKIP] ${deffnm} already finished."
    return 0
  fi

  if [[ "${deffnm}" == "md_100ns" && -f "${deffnm}.cpt" ]]; then
    echo "[RUN] Restarting ${deffnm} from checkpoint"
    mpirun "${GMX_BIN}" mdrun \
      -deffnm "${deffnm}" \
      -cpi "${deffnm}.cpt" \
      -append \
      -dlb yes \
      -v \
      -pin on \
      -ntomp 1
  else
    echo "[RUN] Starting ${deffnm}"
    mpirun "${GMX_BIN}" mdrun \
      -deffnm "${deffnm}" \
      -dlb yes \
      -v \
      -pin on \
      -ntomp 1
  fi
}

if [[ ! -f em.gro ]]; then
  echo "[STEP] grompp EM"
  "${GMX_BIN}" grompp \
    -f "${BASE}/mdp/em.mdp" \
    -c conf.gro \
    -p topol.top \
    -n index.ndx \
    -o em.tpr \
    -po em_out.mdp \
    -maxwarn 1
fi
run_mdrun em

if [[ ! -f nvt_100ps.tpr ]]; then
  echo "[STEP] grompp NVT 100 ps"
  "${GMX_BIN}" grompp \
    -f nvt_100ps.mdp \
    -c em.gro \
    -r em.gro \
    -p topol.top \
    -n index.ndx \
    -o nvt_100ps.tpr \
    -po nvt_100ps_out.mdp \
    -maxwarn 1
fi
run_mdrun nvt_100ps

if [[ ! -f npt_100ps.tpr ]]; then
  echo "[STEP] grompp NPT 100 ps"
  "${GMX_BIN}" grompp \
    -f "${BASE}/mdp/npt_100ps.mdp" \
    -c nvt_100ps.gro \
    -t nvt_100ps.cpt \
    -r nvt_100ps.gro \
    -p topol.top \
    -n index.ndx \
    -o npt_100ps.tpr \
    -po npt_100ps_out.mdp \
    -maxwarn 1
fi
run_mdrun npt_100ps

if [[ ! -f md_100ns.tpr ]]; then
  echo "[STEP] grompp MD 100 ns"
  "${GMX_BIN}" grompp \
    -f "${BASE}/mdp/md_100ns.mdp" \
    -c npt_100ps.gro \
    -t npt_100ps.cpt \
    -p topol.top \
    -n index.ndx \
    -o md_100ns.tpr \
    -po md_100ns_out.mdp \
    -maxwarn 1
fi
run_mdrun md_100ns

echo "[CHECK] Dangerous keywords"
grep -iE "shake|nan|inf|fatal|segmentation|error|constraint|lincs warning|terminated abnormally" *.log *.out 2>/dev/null || true

echo "[DONE] ${SYS} ${REP} finished at $(date)"
echo "[DONE] Results: ${RUNDIR}"

__A35R_SCRIPT_EOF__
chmod +x '06_gromacs_100ns_3rep_cpu_array.slurm'
mkdir -p "$(dirname '07_gromacs_analysis_cpu_array.slurm')"
cat > '07_gromacs_analysis_cpu_array.slurm' <<'__A35R_SCRIPT_EOF__'
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

__A35R_SCRIPT_EOF__
chmod +x '07_gromacs_analysis_cpu_array.slurm'
mkdir -p "$(dirname '08_collect_plot_gromacs_results.py')"
cat > '08_collect_plot_gromacs_results.py' <<'__A35R_SCRIPT_EOF__'
#!/usr/bin/env python3
"""
08_collect_plot_gromacs_results.py

Collect GROMACS analysis CSV files from:
  gmx_md100_3rep/${SYS}/${REP}/analysis/

Generate:
  - combined CSV files for each metric
  - summary_table.csv
  - summary_by_system_metric.csv
  - PNG plots

Run:
  python3 08_collect_plot_gromacs_results.py \
    --root gmx_md100_3rep \
    --out gmx_analysis_summary
"""

import argparse
from pathlib import Path
import math
import warnings

import pandas as pd
import matplotlib.pyplot as plt


METRICS = {
    "rmsd_backbone": "rmsd_backbone.csv",
    "rmsd_ligand_heavy": "rmsd_ligand_heavy.csv",
    "rmsf_backbone_residue": "rmsf_backbone_residue.csv",
    "gyrate_protein": "gyrate_protein.csv",
    "hbond_prot_lig": "hbond_prot_lig.csv",
    "mindist_prot_lig": "mindist_prot_lig.csv",
    "contacts_prot_lig": "contacts_prot_lig.csv",
}

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]


def read_csv(path: Path):
    if not path.exists() or path.stat().st_size == 0:
        return None
    try:
        df = pd.read_csv(path)
        if df.empty:
            return None
        return df
    except Exception as e:
        warnings.warn(f"Could not read {path}: {e}")
        return None


def numeric_y_columns(df):
    cols = []
    for c in df.columns:
        if c.lower() in {"time", "time_ns", "time_ps", "residue", "residue_index"}:
            continue
        if pd.api.types.is_numeric_dtype(df[c]):
            cols.append(c)
    return cols


def guess_x_column(df, metric):
    lower = {c.lower(): c for c in df.columns}
    if "time_ns" in lower:
        return lower["time_ns"]
    if "time" in lower:
        return lower["time"]
    if "residue" in lower:
        return lower["residue"]
    if "residue_index" in lower:
        return lower["residue_index"]
    return df.columns[0]


def add_metadata(df, system, rep, metric):
    df = df.copy()
    df.insert(0, "metric", metric)
    df.insert(0, "rep", rep)
    df.insert(0, "system", system)
    return df


def summarize_metric(df, metric):
    ycols = numeric_y_columns(df)
    if not ycols:
        return []
    y = ycols[0]
    x = guess_x_column(df, metric)

    tmp = df[["system", "rep", x, y]].copy()
    tmp[y] = pd.to_numeric(tmp[y], errors="coerce")
    tmp = tmp.dropna(subset=[y])

    rows = []
    for (system, rep), sub in tmp.groupby(["system", "rep"]):
        if sub.empty:
            continue
        if "rmsf" not in metric and pd.api.types.is_numeric_dtype(sub[x]):
            xmax = sub[x].max()
            xmin = sub[x].min()
            cutoff = xmin + 0.5 * (xmax - xmin)
            sub2 = sub[sub[x] >= cutoff]
            if sub2.empty:
                sub2 = sub
        else:
            sub2 = sub

        rows.append({
            "system": system,
            "rep": rep,
            "metric": metric,
            "value_column": y,
            "n": int(sub2[y].shape[0]),
            "mean": float(sub2[y].mean()),
            "std": float(sub2[y].std(ddof=1)) if sub2[y].shape[0] > 1 else float("nan"),
            "min": float(sub2[y].min()),
            "max": float(sub2[y].max()),
            "median": float(sub2[y].median()),
            "final_or_last": float(sub[y].iloc[-1]),
            "summary_window": "second_half_time_series_or_all_residues",
        })
    return rows


def plot_time_series(df, metric, outdir):
    ycols = numeric_y_columns(df)
    if not ycols:
        return
    y = ycols[0]
    x = guess_x_column(df, metric)

    plt.figure(figsize=(8, 5))
    for (system, rep), sub in df.groupby(["system", "rep"]):
        if x not in sub.columns or y not in sub.columns:
            continue
        plt.plot(sub[x], sub[y], linewidth=1.0, alpha=0.85, label=f"{system}-{rep}")
    plt.xlabel(x)
    plt.ylabel(y)
    plt.title(metric)
    plt.legend(fontsize=7, ncol=2)
    plt.tight_layout()
    plt.savefig(outdir / f"{metric}.png", dpi=300)
    plt.close()


def plot_rmsf(df, metric, outdir):
    ycols = numeric_y_columns(df)
    if not ycols:
        return
    y = ycols[0]
    x = guess_x_column(df, metric)

    plt.figure(figsize=(8, 5))
    for (system, rep), sub in df.groupby(["system", "rep"]):
        plt.plot(sub[x], sub[y], linewidth=1.0, alpha=0.85, label=f"{system}-{rep}")
    plt.xlabel(x)
    plt.ylabel(y)
    plt.title(metric)
    plt.legend(fontsize=7, ncol=2)
    plt.tight_layout()
    plt.savefig(outdir / f"{metric}.png", dpi=300)
    plt.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_md100_3rep", help="Root directory containing system/rep folders")
    parser.add_argument("--out", default="gmx_analysis_summary", help="Output summary directory")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    all_summary_rows = []

    for metric, fname in METRICS.items():
        frames = []
        for system in SYSTEMS:
            for rep in REPS:
                path = root / system / rep / "analysis" / fname
                df = read_csv(path)
                if df is None:
                    print(f"[MISS] {path}")
                    continue
                frames.append(add_metadata(df, system, rep, metric))

        if not frames:
            print(f"[WARN] No data for metric: {metric}")
            continue

        combined = pd.concat(frames, ignore_index=True)
        combined_path = outdir / f"combined_{metric}.csv"
        combined.to_csv(combined_path, index=False)
        print(f"[WRITE] {combined_path}")

        all_summary_rows.extend(summarize_metric(combined, metric))

        if "rmsf" in metric:
            plot_rmsf(combined, metric, outdir)
        else:
            plot_time_series(combined, metric, outdir)

    if all_summary_rows:
        summary = pd.DataFrame(all_summary_rows)
        summary.to_csv(outdir / "summary_table.csv", index=False)

        grouped = (
            summary.groupby(["system", "metric"], as_index=False)
            .agg(
                rep_mean=("mean", "mean"),
                rep_sd=("mean", "std"),
                rep_n=("mean", "count"),
                final_mean=("final_or_last", "mean"),
                final_sd=("final_or_last", "std"),
            )
        )
        grouped.to_csv(outdir / "summary_by_system_metric.csv", index=False)

        print(f"[WRITE] {outdir / 'summary_table.csv'}")
        print(f"[WRITE] {outdir / 'summary_by_system_metric.csv'}")
    else:
        print("[WARN] No summary rows generated.")

    print("[DONE] Collection and plotting finished.")


if __name__ == "__main__":
    main()

__A35R_SCRIPT_EOF__
chmod +x '08_collect_plot_gromacs_results.py'
mkdir -p "$(dirname 'scripts/xvg_to_csv.py')"
cat > 'scripts/xvg_to_csv.py' <<'__A35R_SCRIPT_EOF__'
#!/usr/bin/env python3
"""
xvg_to_csv.py

Convert one or more GROMACS .xvg files into simple CSV files.

Usage:
  python3 scripts/xvg_to_csv.py file1.xvg file2.xvg
  python3 scripts/xvg_to_csv.py analysis/*.xvg
"""

import sys
from pathlib import Path
import re
import pandas as pd


def parse_xvg(path: Path):
    legends = []
    x_label = None
    y_label = None
    data = []

    with open(path, "r", errors="replace") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith("@"):
                if "xaxis" in line and "label" in line:
                    m = re.search(r'label\s+"([^"]+)"', line)
                    if m:
                        x_label = m.group(1).strip()
                elif "yaxis" in line and "label" in line:
                    m = re.search(r'label\s+"([^"]+)"', line)
                    if m:
                        y_label = m.group(1).strip()
                elif "legend" in line:
                    m = re.search(r'legend\s+"([^"]+)"', line)
                    if m:
                        legends.append(m.group(1).strip())
                continue
            if line.startswith("#"):
                continue

            parts = line.split()
            try:
                vals = [float(x) for x in parts]
            except ValueError:
                continue
            if vals:
                data.append(vals)

    if not data:
        return None

    ncol = max(len(row) for row in data)
    normalized = [row + [float("nan")] * (ncol - len(row)) for row in data]

    xname = sanitize_col(x_label) if x_label else "x"
    if "time" in xname.lower() and "(ps)" in (x_label or "").lower():
        xname = "time_ps"
    elif "time" in xname.lower() and "(ns)" in (x_label or "").lower():
        xname = "time_ns"
    elif "residue" in xname.lower():
        xname = "residue"

    cols = [xname]
    for i in range(1, ncol):
        if i - 1 < len(legends):
            cols.append(sanitize_col(legends[i - 1]))
        elif y_label and ncol == 2:
            cols.append(sanitize_col(y_label))
        else:
            cols.append(f"y{i}")

    df = pd.DataFrame(normalized, columns=cols)

    # Normalize common GROMACS outputs.
    stem = path.stem.lower()
    if stem.startswith("rmsd") and len(df.columns) >= 2:
        df = df.rename(columns={df.columns[0]: "time_ns", df.columns[1]: "rmsd_nm"})
    elif stem.startswith("gyrate") and len(df.columns) >= 2:
        df = df.rename(columns={df.columns[0]: "time_ps", df.columns[1]: "rg_nm"})
    elif stem.startswith("hbond") and "dist" not in stem and "ang" not in stem and len(df.columns) >= 2:
        df = df.rename(columns={df.columns[0]: "time_ps", df.columns[1]: "hbonds"})
    elif stem.startswith("mindist") and len(df.columns) >= 2:
        df = df.rename(columns={df.columns[0]: "time_ps", df.columns[1]: "min_distance_nm"})
    elif stem.startswith("contacts") and len(df.columns) >= 2:
        df = df.rename(columns={df.columns[0]: "time_ps", df.columns[1]: "contacts"})
    elif stem.startswith("rmsf") and len(df.columns) >= 2:
        df = df.rename(columns={df.columns[0]: "residue", df.columns[1]: "rmsf_nm"})

    return df


def sanitize_col(s):
    s = s.strip()
    s = s.replace("(", "").replace(")", "")
    s = s.replace("/", "_per_")
    s = re.sub(r"[^0-9a-zA-Z_]+", "_", s)
    s = re.sub(r"_+", "_", s)
    s = s.strip("_")
    return s or "value"


def convert(path):
    path = Path(path)
    if not path.exists():
        print(f"[MISS] {path}", file=sys.stderr)
        return
    df = parse_xvg(path)
    if df is None:
        print(f"[WARN] No numeric data in {path}", file=sys.stderr)
        return
    out = path.with_suffix(".csv")
    df.to_csv(out, index=False)
    print(f"[WRITE] {out}")


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(0)
    for item in sys.argv[1:]:
        convert(item)


if __name__ == "__main__":
    main()

__A35R_SCRIPT_EOF__
chmod +x 'scripts/xvg_to_csv.py'
mkdir -p "$(dirname '09_check_finished_and_extract_energy.sh')"
cat > '09_check_finished_and_extract_energy.sh' <<'__A35R_SCRIPT_EOF__'
#!/usr/bin/env bash
set -euo pipefail

# ================================================================
# 09_check_finished_and_extract_energy.sh
# Purpose:
#   Quickly check whether 100 ns jobs finished and extract basic energy terms.
# ================================================================

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
GMX_BIN="${GMX_BIN:-gmx_mpi}"
SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

module purge
module load oneapi
module load gromacs/2021.3-intel-2021.4.0

OUT="${BASE}/gmx_md100_3rep/job_finish_status.tsv"
echo -e "system\trep\tmd_log_exists\tfinished\tlast_step_line" > "${OUT}"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    RUNDIR="${BASE}/gmx_md100_3rep/${SYS}/${REP}"
    LOG="${RUNDIR}/md_100ns.log"
    if [[ -s "${LOG}" ]]; then
      FINISHED="NO"
      grep -q "Finished mdrun" "${LOG}" && FINISHED="YES"
      LASTSTEP="$(grep -E '^\s*Step\s+Time|^\s*[0-9]+\s+[0-9.]+' "${LOG}" | tail -n 1 | tr '\t' ' ' | sed 's/  */ /g')"
      echo -e "${SYS}\t${REP}\tYES\t${FINISHED}\t${LASTSTEP}" >> "${OUT}"
    else
      echo -e "${SYS}\t${REP}\tNO\tNO\tNA" >> "${OUT}"
    fi
  done
done

cat "${OUT}"
echo "[DONE] Status written to ${OUT}"

__A35R_SCRIPT_EOF__
chmod +x '09_check_finished_and_extract_energy.sh'
mkdir -p "$(dirname 'README_RUN_ORDER_CPU.txt')"
cat > 'README_RUN_ORDER_CPU.txt' <<'__A35R_SCRIPT_EOF__'
A35R Amber-to-GROMACS CPU workflow
===================================

Clean target directory:
  <PROJECT_ROOT>/gromacs-runs

Old source directory:
  <USER_HOME>/1_projects/PRP-MPOX-JCAMD/JCAMD-R1/AMBER/A35R

Recommended run order
---------------------

1) Put these scripts in the clean directory, or run the master creation script.

2) Copy core Amber files from old A35R to clean A35R-gromacs:

   cd <PROJECT_ROOT>/gromacs-runs
   bash 00_prepare_clean_A35R_gromacs.sh

3) Check CPU GROMACS module:

   bash 01_check_cpu_gromacs_module.sh

4) Convert Amber to GROMACS:

   conda activate ambertools_local
   bash 02_convert_amber_to_gromacs_parmed.sh

5) Generate MDP files:

   bash 03_make_gromacs_mdp_cpu.sh

6) Test one system first:

   sbatch 04_test_gromacs_cpu_one.slurm

7) If drugs2263 test is OK, test all three systems:

   sbatch 05_test_gromacs_cpu_array.slurm

8) Submit 100 ns × 3 repeats:

   sbatch 06_gromacs_100ns_3rep_cpu_array.slurm

9) After production jobs finish, run analysis:

   sbatch 07_gromacs_analysis_cpu_array.slurm

10) Collect and plot:

   python3 08_collect_plot_gromacs_results.py \
     --root gmx_md100_3rep \
     --out gmx_analysis_summary

Important notes
---------------

- This CPU workflow uses:
    module load oneapi
    module load gromacs/2021.3-intel-2021.4.0
    gmx_mpi

- The formal 100 ns job uses:
    #SBATCH -N 3
    #SBATCH --ntasks-per-node=64
    mpirun gmx_mpi mdrun -dlb yes -v -pin on -ntomp 1

- The example -noconfout option is NOT used here because each stage needs the final .gro file for the next stage and for analysis.

- Position restraint files are generated, but not automatically activated. This avoids common errors caused by molecule-type numbering after Amber-to-GROMACS conversion. If you want restrained NVT/NPT, inspect topol.top first and insert the posre include under the correct moleculetype.

- For review response, use:
    backbone RMSD
    ligand heavy-atom RMSD after protein fitting
    RMSF
    radius of gyration
    protein-ligand hydrogen bonds
    protein-ligand minimum distance/contact
    three independent replicates mean ± SD

__A35R_SCRIPT_EOF__

echo "[DONE] Scripts created."
echo
echo "Next commands:"
echo "  cd ${NEW_BASE}"
echo "  bash 00_prepare_clean_A35R_gromacs.sh"
echo "  bash 01_check_cpu_gromacs_module.sh"
echo "  conda activate ambertools_local"
echo "  bash 02_convert_amber_to_gromacs_parmed.sh"
echo "  bash 03_make_gromacs_mdp_cpu.sh"
echo "  sbatch 04_test_gromacs_cpu_one.slurm"
