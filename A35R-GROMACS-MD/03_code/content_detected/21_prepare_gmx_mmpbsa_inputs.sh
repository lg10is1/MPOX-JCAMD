#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
ROOT=<REDACTED>
OUTROOT="${OUTROOT:-$BASE/gmx_mmpbsa_50_100ns}"

# Last 50 ns, sample every 500 ps = about 101 frames.
B_PS="${B_PS:-50000}"
E_PS="${E_PS:-100000}"
DT_PS="${DT_PS:-500}"

# Quick test: last 10 ns, sample every 1000 ps = about 11 frames.
TEST_B_PS="${TEST_B_PS:-90000}"
TEST_E_PS="${TEST_E_PS:-100000}"
TEST_DT_PS="${TEST_DT_PS:-1000}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

cd "$BASE"

echo "============================================================"
echo "[INFO] Prepare gmx_MMPBSA inputs"
echo "============================================================"
echo "BASE=$BASE"
echo "ROOT=$ROOT"
echo "OUTROOT=$OUTROOT"
echo "Production window: ${B_PS}-${E_PS} ps, dt=${DT_PS} ps"
echo "Test window      : ${TEST_B_PS}-${TEST_E_PS} ps, dt=${TEST_DT_PS} ps"

echo
echo "============================================================"
echo "[INFO] Load GROMACS for trajectory preprocessing"
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
$GMX --version | head -n 20 || true

mkdir -p "$OUTROOT"

make_index_py='
import sys, pathlib

gro = pathlib.Path(sys.argv[1])
ndx = pathlib.Path(sys.argv[2])

std_aa = {
"ALA","ARG","ASN","ASP","ASH","CYS","CYX","CYM","GLN","GLU","GLH","GLY",
"HIS","HID","HIE","HIP","HSD","HSE","HSP","ILE","LEU","LYS","LYN","MET",
"PHE","PRO","SER","THR","TRP","TYR","VAL"
}
waters = {"WAT","HOH","SOL","TIP3","TIP3P","SPC"}
ions = {"NA","Na","Na+","SOD","K","K+","CL","Cl","Cl-","CLA","MG","Mg","MG2","CA","Ca","CA2","ZN","Zn","ZN2"}

lines = gro.read_text(errors="ignore").splitlines()
atom_lines = lines[2:-1]
protein = []
ligand = []
system = []
nonstd = {}

for idx, line in enumerate(atom_lines, start=1):
    system.append(idx)
    # GROMACS .gro fixed columns: residue name 6-10
    resname = line[5:10].strip()
    if resname in std_aa:
        protein.append(idx)
    elif resname == "LIG":
        ligand.append(idx)
    elif resname not in waters and resname not in ions:
        nonstd.setdefault(resname, []).append(idx)

if not ligand:
    # Fallback: if exactly one non-standard residue/molecule type exists, use it as ligand.
    if len(nonstd) == 1:
        ligand = list(next(iter(nonstd.values())))
    else:
        sys.stderr.write(f"[ERROR] Cannot identify ligand. Nonstandard groups: {list(nonstd.keys())}\\n")
        sys.exit(2)

if not protein:
    sys.stderr.write("[ERROR] Cannot identify protein atoms from residue names.\\n")
    sys.exit(3)

complex_atoms = sorted(set(protein + ligand))

def write_group(f, name, atoms):
    f.write(f"[ {name} ]\\n")
    for i in range(0, len(atoms), 15):
        f.write(" ".join(str(x) for x in atoms[i:i+15]) + "\\n")
    f.write("\\n")

with ndx.open("w") as f:
    write_group(f, "Protein", protein)       # group 0
    write_group(f, "LIG", ligand)            # group 1
    write_group(f, "Protein_LIG", complex_atoms)  # group 2
    write_group(f, "System", system)         # group 3

report = ndx.with_suffix(".report.txt")
report.write_text(
    f"gro={gro}\\n"
    f"index={ndx}\\n"
    f"Protein_atoms={len(protein)}\\n"
    f"LIG_atoms={len(ligand)}\\n"
    f"Protein_LIG_atoms={len(complex_atoms)}\\n"
    f"System_atoms={len(system)}\\n"
    f"group_ids: Protein=0, LIG=1, Protein_LIG=2, System=3\\n"
)
print(report.read_text())
'

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    SRCDIR="$ROOT/$SYS/$REP"
    RUNDIR="$OUTROOT/$SYS/$REP"

    echo
    echo "------------------------------------------------------------"
    echo "[INFO] Preparing $SYS $REP"
    echo "SRCDIR=$SRCDIR"
    echo "RUNDIR=$RUNDIR"
    echo "------------------------------------------------------------"

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

    # Copy topologies and final structure.
    cp -L "$SRCDIR"/topol.top "$RUNDIR"/
    cp -L "$SRCDIR"/md_100ns.tpr "$RUNDIR"/
    cp -L "$SRCDIR"/md_100ns.gro "$RUNDIR"/
    cp -L "$SRCDIR"/*.itp "$RUNDIR"/ 2>/dev/null || true

    # Use symbolic link for large trajectory.
    ln -sf "$SRCDIR/md_100ns.xtc" "$RUNDIR/md_100ns.xtc"

    # Create clean index file: group 0 Protein, group 1 LIG, group 2 Protein_LIG, group 3 System.
    python3 -c "$make_index_py" "$RUNDIR/md_100ns.gro" "$RUNDIR/mmpbsa_index.ndx"

    cd "$RUNDIR"

    echo "[STEP] PBC removal and centering for production trajectory"
    echo "       center group = 2 Protein_LIG; output group = 3 System"
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
      -ur compact

    echo "[STEP] Fit production trajectory to Protein_LIG"
    echo "       fit group = 2 Protein_LIG; output group = 3 System"
    printf "2\n3\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f mmpbsa_50_100_dt${DT_PS}_pbc_mol_center.xtc \
      -o mmpbsa_50_100_dt${DT_PS}_fit.xtc \
      -n mmpbsa_index.ndx \
      -fit rot+trans

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
      -ur compact

    echo "[STEP] Fit quick-test trajectory to Protein_LIG"
    printf "2\n3\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f mmpbsa_test_90_100_dt${TEST_DT_PS}_pbc_mol_center.xtc \
      -o mmpbsa_test_90_100_dt${TEST_DT_PS}_fit.xtc \
      -n mmpbsa_index.ndx \
      -fit rot+trans

    echo "[STEP] Generate optional reference PDB of Protein_LIG only"
    printf "2\n" | $GMX trjconv \
      -s md_100ns.tpr \
      -f mmpbsa_50_100_dt${DT_PS}_fit.xtc \
      -o complex_ref_protein_ligand.pdb \
      -n mmpbsa_index.ndx \
      -dump "$B_PS" || true

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

Files:
  md_100ns.tpr
  md_100ns.xtc -> symbolic link to source trajectory
  topol.top
  *.itp
  mmpbsa_index.ndx

Index group IDs:
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

Recommended command:
  gmx_MMPBSA -O -i mmpbsa_gb_prod.in \\
    -cs md_100ns.tpr \\
    -ct mmpbsa_50_100_dt${DT_PS}_fit.xtc \\
    -ci mmpbsa_index.ndx \\
    -cg 0 1 \\
    -cp topol.top \\
    -o FINAL_RESULTS_MMPBSA_GB.dat \\
    -eo FINAL_RESULTS_MMPBSA_GB.csv \\
    -nogui

Important:
  - Receptor group = 0 Protein
  - Ligand group   = 1 LIG
  - The trajectory is PBC-processed, centered on Protein_LIG, and fitted.
EOF_README

    ls -lh *.xtc *.tpr topol.top mmpbsa_index.ndx *.in README_MMPBSA_INPUTS.txt
    cd "$BASE"
  done
done

echo
echo "[DONE] gmx_MMPBSA input preparation finished."
echo "Output root:"
echo "  $OUTROOT"
