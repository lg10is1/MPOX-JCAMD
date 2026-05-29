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

