#!/usr/bin/env python3
import sys
import re
from pathlib import Path

if len(sys.argv) != 4:
    print("Usage: 21_make_clean_mmpbsa_index.py md_100ns.gro topol.top mmpbsa_index.ndx", file=sys.stderr)
    sys.exit(1)

gro_path = Path(sys.argv[1]).resolve()
top_path = Path(sys.argv[2]).resolve()
ndx_path = Path(sys.argv[3]).resolve()

ION_NAMES = {
    "NA", "Na", "Na+", "SOD",
    "K", "K+",
    "CL", "Cl", "Cl-", "CLA",
    "MG", "Mg", "MG2",
    "CA", "Ca", "CA2",
    "ZN", "Zn", "ZN2"
}

WATER_NAMES = {
    "WAT", "SOL", "HOH", "TIP3", "TIP3P", "SPC"
}

STD_AA = {
    "ALA","ARG","ASN","ASP","ASH","CYS","CYX","CYM","GLN","GLU","GLH","GLY",
    "HIS","HID","HIE","HIP","HSD","HSE","HSP","ILE","LEU","LYS","LYN","MET",
    "PHE","PRO","SER","THR","TRP","TYR","VAL"
}

def read_gro_natoms(gro):
    lines = gro.read_text(errors="ignore").splitlines()
    if len(lines) < 3:
        raise RuntimeError(f"Bad GRO file: {gro}")
    try:
        natoms = int(lines[1].strip())
    except Exception:
        raise RuntimeError(f"Cannot read atom number from GRO second line: {gro}")
    atom_lines = lines[2:2+natoms]
    if len(atom_lines) != natoms:
        raise RuntimeError(f"GRO atom count mismatch: expected {natoms}, got {len(atom_lines)}")
    return natoms, atom_lines

def parse_gro_by_resname(gro):
    natoms, atom_lines = read_gro_natoms(gro)
    protein = []
    lig = []
    system = list(range(1, natoms + 1))
    res_count = {}

    for idx, line in enumerate(atom_lines, start=1):
        resname = line[5:10].strip()
        res_count[resname] = res_count.get(resname, 0) + 1

        if resname in STD_AA:
            protein.append(idx)
        elif resname == "LIG":
            lig.append(idx)

    return natoms, protein, lig, system, res_count

def strip_comment(line):
    return line.split(";")[0].strip()

def section_name(line):
    m = re.match(r"^\s*\[\s*([^\]]+)\s*\]\s*$", line)
    if m:
        return m.group(1).strip().lower()
    return None

def find_include_file(name, base_dir):
    p = Path(name.strip().strip('"').strip("'"))
    if p.is_absolute() and p.exists():
        return p
    p2 = base_dir / p
    if p2.exists():
        return p2
    return None

def collect_top_files(top):
    files = []
    seen = set()

    def visit(p):
        p = p.resolve()
        if p in seen:
            return
        seen.add(p)
        files.append(p)

        for raw in p.read_text(errors="ignore").splitlines():
            s = raw.strip()
            if not s.startswith("#include"):
                continue
            m = re.search(r'#include\s+["<]([^">]+)[">]', s)
            if not m:
                continue
            inc = find_include_file(m.group(1), p.parent)
            if inc is not None:
                visit(inc)

    visit(top)
    return files

def parse_moleculetype_atomcounts_and_molecules(top):
    files = collect_top_files(top)
    atom_counts = {}
    molecules = []

    # Parse moleculetype atom counts
    for p in files:
        current_section = None
        current_mol = None
        in_atoms = False
        atom_count_for_current = 0

        lines = p.read_text(errors="ignore").splitlines()
        i = 0
        while i < len(lines):
            raw = lines[i]
            s_clean = strip_comment(raw)
            sec = section_name(s_clean)

            if sec:
                # leaving previous [ atoms ]
                if in_atoms and current_mol is not None:
                    atom_counts[current_mol] = max(atom_counts.get(current_mol, 0), atom_count_for_current)
                current_section = sec
                in_atoms = False
                atom_count_for_current = 0

                if current_section == "moleculetype":
                    # Next non-empty non-comment line gives molecule type name
                    j = i + 1
                    while j < len(lines):
                        t = strip_comment(lines[j])
                        if not t:
                            j += 1
                            continue
                        parts = t.split()
                        if parts:
                            current_mol = parts[0]
                        break

                elif current_section == "atoms":
                    if current_mol is not None:
                        in_atoms = True
                        atom_count_for_current = 0

                i += 1
                continue

            if in_atoms:
                t = s_clean
                if t:
                    parts = t.split()
                    # [ atoms ] lines start with atom number
                    if parts and re.match(r"^\d+$", parts[0]):
                        atom_count_for_current += 1

            i += 1

        if in_atoms and current_mol is not None:
            atom_counts[current_mol] = max(atom_counts.get(current_mol, 0), atom_count_for_current)

    # Parse [ molecules ] only from topol.top
    current_section = None
    for raw in top.read_text(errors="ignore").splitlines():
        s = strip_comment(raw)
        sec = section_name(s)
        if sec:
            current_section = sec
            continue
        if current_section == "molecules" and s:
            parts = s.split()
            if len(parts) >= 2:
                mol = parts[0]
                try:
                    count = int(parts[1])
                except Exception:
                    continue
                molecules.append((mol, count))

    return atom_counts, molecules, files

def build_groups_from_topology(natoms, top):
    atom_counts, molecules, files = parse_moleculetype_atomcounts_and_molecules(top)

    if not molecules:
        raise RuntimeError("Cannot parse [ molecules ] from topol.top")

    protein = []
    lig = []
    system = list(range(1, natoms + 1))

    pos = 1

    for mol, nmol in molecules:
        if mol not in atom_counts:
            raise RuntimeError(f"Molecule type '{mol}' appears in [ molecules ] but atom count was not found in [ moleculetype ]/[ atoms ].")

        n_atoms_one = atom_counts[mol]

        for _ in range(nmol):
            start = pos
            end = pos + n_atoms_one - 1
            atom_range = list(range(start, end + 1))

            mol_upper = mol.upper()

            if mol_upper == "LIG":
                lig.extend(atom_range)
            elif mol in WATER_NAMES or mol_upper in WATER_NAMES:
                pass
            elif mol in ION_NAMES or mol_upper in ION_NAMES:
                pass
            elif mol_upper in {"WAT", "SOL", "HOH", "TIP3", "TIP3P", "SPC"}:
                pass
            elif mol_upper in {"NA", "NA+", "SOD", "CL", "CL-", "CLA", "K", "K+"}:
                pass
            else:
                # In ParmEd converted Amber systems, protein molecule type is often system1.
                # Treat non-water, non-ion, non-LIG molecule types as receptor/protein.
                protein.extend(atom_range)

            pos = end + 1

    if pos - 1 != natoms:
        raise RuntimeError(
            f"Topology-derived atom count ({pos-1}) does not match GRO atom count ({natoms}). "
            f"This may indicate include-file parsing issues."
        )

    return protein, lig, system, atom_counts, molecules, files

def write_group(f, name, atoms):
    f.write(f"[ {name} ]\n")
    for i in range(0, len(atoms), 15):
        f.write(" ".join(str(x) for x in atoms[i:i+15]) + "\n")
    f.write("\n")

def validate_group(name, atoms, natoms):
    if not atoms:
        raise RuntimeError(f"Group {name} is empty.")
    bad = [x for x in atoms if x < 1 or x > natoms]
    if bad:
        raise RuntimeError(f"Group {name} has invalid atom indices. Examples: {bad[:20]}")

natoms, gro_protein, gro_lig, gro_system, res_count = parse_gro_by_resname(gro_path)

method = "topology"
try:
    protein, lig, system, atom_counts, molecules, files = build_groups_from_topology(natoms, top_path)
except Exception as e:
    method = "gro_resname_fallback"
    protein, lig, system = gro_protein, gro_lig, gro_system
    atom_counts, molecules, files = {}, [], []
    if not protein or not lig:
        raise RuntimeError(
            "Failed to build index from topology and GRO fallback also failed.\n"
            f"Topology error: {e}\n"
            f"GRO residue counts: {res_count}"
        )

protein = sorted(set(protein))
lig = sorted(set(lig))
protein_lig = sorted(set(protein + lig))
system = sorted(set(system))

validate_group("Protein", protein, natoms)
validate_group("LIG", lig, natoms)
validate_group("Protein_LIG", protein_lig, natoms)
validate_group("System", system, natoms)

with ndx_path.open("w") as f:
    write_group(f, "Protein", protein)        # group 0
    write_group(f, "LIG", lig)                # group 1
    write_group(f, "Protein_LIG", protein_lig) # group 2
    write_group(f, "System", system)          # group 3

report = ndx_path.with_suffix(".report.txt")
report.write_text(
    "Clean gmx_MMPBSA index report\n"
    "========================================\n"
    f"gro={gro_path}\n"
    f"top={top_path}\n"
    f"index={ndx_path}\n"
    f"method={method}\n"
    f"natoms={natoms}\n"
    f"Protein_atoms={len(protein)}\n"
    f"LIG_atoms={len(lig)}\n"
    f"Protein_LIG_atoms={len(protein_lig)}\n"
    f"System_atoms={len(system)}\n"
    "group_ids:\n"
    "  0 Protein\n"
    "  1 LIG\n"
    "  2 Protein_LIG\n"
    "  3 System\n"
    "\n"
    f"GRO_residue_counts_top30={sorted(res_count.items(), key=lambda x: -x[1])[:30]}\n"
    f"Topology_molecules={molecules}\n"
    f"Topology_atom_counts={atom_counts}\n"
    f"Topology_files={[str(x) for x in files]}\n"
)

print(report.read_text())
