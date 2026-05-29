#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
ROOT=<REDACTED>
OUTROOT="${OUTROOT:-$BASE/gmx_mmpbsa_50_100ns}"

# gmx_MMPBSA 推荐不要用整条 100 ns 每一帧。
# 这里默认取最后 50 ns，每 500 ps 一帧，约 101 帧/rep。
B_PS="${B_PS:-50000}"
E_PS="${E_PS:-100000}"
DT_PS="${DT_PS:-500}"

# 快速测试：最后 10 ns，每 1000 ps 一帧，约 11 帧/rep。
TEST_B_PS="${TEST_B_PS:-90000}"
TEST_E_PS="${TEST_E_PS:-100000}"
TEST_DT_PS="${TEST_DT_PS:-1000}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

cd "$BASE"

echo "============================================================"
echo "[INFO] Prepare gmx_MMPBSA inputs v2"
echo "============================================================"
echo "[INFO] BASE=$BASE"
echo "[INFO] ROOT=$ROOT"
echo "[INFO] OUTROOT=$OUTROOT"
echo "[INFO] Production window: ${B_PS}-${E_PS} ps, dt=${DT_PS} ps"
echo "[INFO] Test window      : ${TEST_B_PS}-${TEST_E_PS} ps, dt=${TEST_DT_PS} ps"

echo
echo "============================================================"
echo "[INFO] Load GROMACS module"
echo "============================================================"
set +e
if type module >/dev/null 2>&1; then
  module load oneapi 2>/dev/null
  module load gromacs/2021.3-intel-2021.4.0 2>/dev/null
fi
set -e

if command -v gmx >/dev/null 2>&1; then
  GMX="gmx"
elif command -v gmx_mpi >/dev/null 2>&1; then
  GMX="gmx_mpi"
else
  echo "[ERROR] Neither gmx nor gmx_mpi found."
  exit 1
fi

echo "[INFO] Using GMX=$GMX"
$GMX --version | head -n 30 || true

mkdir -p "$OUTROOT"

###############################################################################
# Python helper: create a clean MMPBSA index from topol.top and md_100ns.gro
###############################################################################
cat > "$BASE/21_make_clean_mmpbsa_index.py" <<'PY'
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
PY

chmod +x "$BASE/21_make_clean_mmpbsa_index.py"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do

    SRCDIR="$ROOT/$SYS/$REP"
    RUNDIR="$OUTROOT/$SYS/$REP"

    echo
    echo "============================================================"
    echo "[INFO] Preparing $SYS $REP"
    echo "============================================================"
    echo "[INFO] SRCDIR=$SRCDIR"
    echo "[INFO] RUNDIR=$RUNDIR"

    if [[ ! -d "$SRCDIR" ]]; then
      echo "[ERROR] Missing source directory: $SRCDIR"
      exit 1
    fi

    for f in md_100ns.tpr md_100ns.xtc md_100ns.gro topol.top; do
      if [[ ! -s "$SRCDIR/$f" ]]; then
        echo "[ERROR] Missing required file: $SRCDIR/$f"
        exit 1
      fi
    done

    mkdir -p "$RUNDIR"

    cp -L "$SRCDIR"/topol.top "$RUNDIR"/
    cp -L "$SRCDIR"/md_100ns.tpr "$RUNDIR"/
    cp -L "$SRCDIR"/md_100ns.gro "$RUNDIR"/
    cp -L "$SRCDIR"/*.itp "$RUNDIR"/ 2>/dev/null || true
    ln -sf "$SRCDIR/md_100ns.xtc" "$RUNDIR/md_100ns.xtc"

    cd "$RUNDIR"

    echo
    echo "[STEP] Generate clean mmpbsa_index.ndx"
    python3 "$BASE/21_make_clean_mmpbsa_index.py" \
      md_100ns.gro \
      topol.top \
      mmpbsa_index.ndx

    echo
    echo "[STEP] Show index group headers"
    grep -n "^\[" mmpbsa_index.ndx
    cat mmpbsa_index.report.txt

    echo
    echo "[STEP] Quick check index validity with gmx make_ndx"
    printf "q\n" | $GMX make_ndx \
      -f md_100ns.tpr \
      -n mmpbsa_index.ndx \
      -o mmpbsa_index_checked.ndx \
      > make_ndx_check.log 2>&1 || {
        echo "[ERROR] make_ndx check failed."
        cat make_ndx_check.log
        exit 1
      }

    echo
    echo "[STEP] PBC removal and centering for production trajectory"
    echo "       center group = 2 Protein_LIG"
    echo "       output group = 3 System"
    printf "2\n3\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f md_100ns.xtc \
      -o mmpbsa_50_100_dt${DT_PS}_pbc_mol_center.xtc \
      -n mmpbsa_index.ndx \
      -b "$B_PS" \
      -e "$E_PS" \
      -dt "$DT_PS" \
      -pbc mol \
      -center \
      -ur compact \
      > trjconv_prod_center.log 2>&1 || {
        echo "[ERROR] trjconv production center failed."
        cat trjconv_prod_center.log
        exit 1
      }

    echo
    echo "[STEP] Fit production trajectory"
    echo "       fit group = 2 Protein_LIG"
    echo "       output group = 3 System"
    printf "2\n3\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f mmpbsa_50_100_dt${DT_PS}_pbc_mol_center.xtc \
      -o mmpbsa_50_100_dt${DT_PS}_fit.xtc \
      -n mmpbsa_index.ndx \
      -fit rot+trans \
      > trjconv_prod_fit.log 2>&1 || {
        echo "[ERROR] trjconv production fit failed."
        cat trjconv_prod_fit.log
        exit 1
      }

    echo
    echo "[STEP] PBC removal and centering for quick-test trajectory"
    printf "2\n3\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f md_100ns.xtc \
      -o mmpbsa_test_90_100_dt${TEST_DT_PS}_pbc_mol_center.xtc \
      -n mmpbsa_index.ndx \
      -b "$TEST_B_PS" \
      -e "$TEST_E_PS" \
      -dt "$TEST_DT_PS" \
      -pbc mol \
      -center \
      -ur compact \
      > trjconv_test_center.log 2>&1 || {
        echo "[ERROR] trjconv quick-test center failed."
        cat trjconv_test_center.log
        exit 1
      }

    echo
    echo "[STEP] Fit quick-test trajectory"
    printf "2\n3\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f mmpbsa_test_90_100_dt${TEST_DT_PS}_pbc_mol_center.xtc \
      -o mmpbsa_test_90_100_dt${TEST_DT_PS}_fit.xtc \
      -n mmpbsa_index.ndx \
      -fit rot+trans \
      > trjconv_test_fit.log 2>&1 || {
        echo "[ERROR] trjconv quick-test fit failed."
        cat trjconv_test_fit.log
        exit 1
      }

    echo
    echo "[STEP] Generate optional reference PDB of Protein_LIG"
    printf "2\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f mmpbsa_50_100_dt${DT_PS}_fit.xtc \
      -o complex_ref_protein_ligand.pdb \
      -n mmpbsa_index.ndx \
      -dump "$B_PS" \
      > trjconv_ref_pdb.log 2>&1 || true

    echo
    echo "[STEP] Write gmx_MMPBSA input files"

    cat > mmpbsa_gb_test.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_test",
  startframe=1,
  endframe=9999999,
  interval=1,
  verbose=2,
  keep_files=0,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

    cat > mmpbsa_gb_prod.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_50_100ns",
  startframe=1,
  endframe=9999999,
  interval=1,
  verbose=2,
  keep_files=0,
/
&gb
  igb=5,
  saltcon=0.150,
/
EOF_IN

    cat > mmpbsa_gb_pb_prod.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_PB_50_100ns",
  startframe=1,
  endframe=9999999,
  interval=1,
  verbose=2,
  keep_files=0,
/
&gb
  igb=5,
  saltcon=0.150,
/
&pb
  istrng=0.150,
  fillratio=4.0,
/
EOF_IN

    cat > mmpbsa_decomp_gb.in <<EOF_IN
&general
  sys_name="${SYS}_${REP}_GB_decomp_50_100ns",
  startframe=1,
  endframe=9999999,
  interval=1,
  verbose=2,
  keep_files=0,
/
&gb
  igb=5,
  saltcon=0.150,
/
&decomp
  idecomp=2,
  dec_verbose=1,
/
EOF_IN

    cat > README_MMPBSA_INPUTS.txt <<EOF_README
System: $SYS
Repeat: $REP

Clean index groups:
  0 Protein
  1 LIG
  2 Protein_LIG
  3 System

Production trajectory:
  mmpbsa_50_100_dt${DT_PS}_fit.xtc
  Time window: ${B_PS}-${E_PS} ps
  Sampling interval: ${DT_PS} ps

Quick-test trajectory:
  mmpbsa_test_90_100_dt${TEST_DT_PS}_fit.xtc
  Time window: ${TEST_B_PS}-${TEST_E_PS} ps
  Sampling interval: ${TEST_DT_PS} ps

gmx_MMPBSA command should use:
  -cs md_100ns.tpr
  -ct mmpbsa_50_100_dt${DT_PS}_fit.xtc
  -ci mmpbsa_index.ndx
  -cg 0 1
  -cp topol.top

Meaning:
  receptor group = 0 Protein
  ligand group   = 1 LIG
EOF_README

    echo
    echo "[STEP] Final file check"
    ls -lh \
      md_100ns.tpr \
      topol.top \
      mmpbsa_index.ndx \
      mmpbsa_50_100_dt${DT_PS}_fit.xtc \
      mmpbsa_test_90_100_dt${TEST_DT_PS}_fit.xtc \
      mmpbsa_gb_test.in \
      mmpbsa_gb_prod.in \
      README_MMPBSA_INPUTS.txt

    cd "$BASE"

  done
done

echo
echo "============================================================"
echo "[DONE] All gmx_MMPBSA inputs prepared successfully."
echo "============================================================"
echo "[INFO] Output root:"
echo "       $OUTROOT"
