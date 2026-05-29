#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

echo "[INFO] Creating gmx_MMPBSA workflow scripts in:"
echo "       $BASE"

###############################################################################
# 20_check_gmx_mmpbsa_env.sh
###############################################################################
cat > 20_check_gmx_mmpbsa_env.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
cd "$BASE"

echo "============================================================"
echo "[1] Basic path"
echo "============================================================"
pwd
hostname
date

echo
echo "============================================================"
echo "[2] Try module information"
echo "============================================================"
if type module >/dev/null 2>&1; then
  module avail gmx 2>&1 | head -n 80 || true
  module avail gmx_mmpbsa 2>&1 || true
  module avail gmx_MMPBSA 2>&1 || true
else
  echo "[WARN] module command not available in current shell."
fi

echo
echo "============================================================"
echo "[3] Try to load common SJTU/Siyuan gmx_MMPBSA environment"
echo "============================================================"
set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  echo "[INFO] Found gmx_MMPBSA_1.5.2 wrapper. Running it once to initialize environment."
  gmx_MMPBSA_1.5.2 || true
fi

echo
echo "============================================================"
echo "[4] Executables"
echo "============================================================"
for exe in gmx_MMPBSA gmx_MMPBSA_test gmx gmx_mpi mpirun MMPBSA.py cpptraj antechamber parmchk2 python3; do
  printf "%-20s : " "$exe"
  command -v "$exe" || true
done

echo
echo "============================================================"
echo "[5] Versions"
echo "============================================================"
if command -v gmx_MMPBSA >/dev/null 2>&1; then
  gmx_MMPBSA -v || true
  gmx_MMPBSA -h | head -n 60 || true
else
  echo "[ERROR] gmx_MMPBSA not found."
  echo "        Please use either module load gmx_mmpbsa/... or create conda env with 20A_create_conda_env_gmxMMPBSA.sh"
fi

echo
if command -v gmx >/dev/null 2>&1; then
  echo "[INFO] gmx version:"
  gmx --version | head -n 40 || true
else
  echo "[WARN] ordinary gmx not found."
  echo "       gmx_MMPBSA MPI mode prefers ordinary gmx rather than gmx_mpi."
fi

echo
if command -v gmx_mpi >/dev/null 2>&1; then
  echo "[INFO] gmx_mpi version:"
  gmx_mpi --version | head -n 30 || true
fi

echo
echo "============================================================"
echo "[6] AMBERHOME / Python packages"
echo "============================================================"
echo "AMBERHOME=${AMBERHOME:-NA}"
python3 - <<'PY' || true
mods = ["numpy", "scipy", "pandas", "matplotlib", "mpi4py"]
for m in mods:
    try:
        mod = __import__(m)
        print(f"{m:12s}: OK  {getattr(mod, '__version__', 'NA')}")
    except Exception as e:
        print(f"{m:12s}: MISSING  {e}")
PY

echo
echo "============================================================"
echo "[7] gmx_MMPBSA create_input quick test"
echo "============================================================"
if command -v gmx_MMPBSA >/dev/null 2>&1; then
  mkdir -p gmx_mmpbsa_env_test
  cd gmx_mmpbsa_env_test
  gmx_MMPBSA --create_input gb >/dev/null 2>&1 || true
  ls -lh || true
  cd "$BASE"
fi

echo
echo "[DONE] Environment check finished."
EOS
chmod +x 20_check_gmx_mmpbsa_env.sh

###############################################################################
# 20A_create_conda_env_gmxMMPBSA.sh
###############################################################################
cat > 20A_create_conda_env_gmxMMPBSA.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

echo "============================================================"
echo "[INFO] Creating conda environment: gmxMMPBSA"
echo "============================================================"

if ! command -v conda >/dev/null 2>&1; then
  echo "[ERROR] conda not found in PATH."
  exit 1
fi

CONDA_BASE="$(conda info --base)"
source "${CONDA_BASE}/etc/profile.d/conda.sh"

conda create -n gmxMMPBSA python=3.11 -y
conda activate gmxMMPBSA

conda install -c conda-forge \
  "mpi4py=4.0.1" \
  "ambertools<24" \
  "numpy=1.26.4" \
  "matplotlib=3.7.3" \
  "scipy=1.14.1" \
  "pandas=1.5.3" \
  "seaborn=0.11.2" \
  "gromacs<2026" \
  pocl \
  -y

python -m pip install gmx_MMPBSA

echo
echo "============================================================"
echo "[INFO] Check installed tools"
echo "============================================================"
which gmx_MMPBSA
gmx_MMPBSA -v || true
which gmx
gmx --version | head -n 30 || true
echo "AMBERHOME=${AMBERHOME:-NA}"

echo
echo "[DONE] Conda environment gmxMMPBSA created."
echo "Use:"
echo "  conda activate gmxMMPBSA"
EOS
chmod +x 20A_create_conda_env_gmxMMPBSA.sh

###############################################################################
# 21_prepare_gmx_mmpbsa_inputs.sh
###############################################################################
cat > 21_prepare_gmx_mmpbsa_inputs.sh <<'EOS'
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
EOS
chmod +x 21_prepare_gmx_mmpbsa_inputs.sh

###############################################################################
# 22_test_gmx_mmpbsa_one.slurm
###############################################################################
cat > 22_test_gmx_mmpbsa_one.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_test
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
#SBATCH --output=mmpbsa_test_%j.out
#SBATCH --error=mmpbsa_test_%j.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

SYS="${SYS:-drugs3003}"
REP="${REP:-rep1}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] SYS=$SYS REP=$REP"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"

cd "$OUTROOT/$SYS/$REP"

echo "[INFO] Loading gmx_MMPBSA environment"
set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  gmx_MMPBSA_1.5.2 || true
fi

if ! command -v gmx_MMPBSA >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base)"
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate gmxMMPBSA
  fi
fi

echo "[INFO] Executables:"
which gmx_MMPBSA || true
which gmx || true
which mpirun || true
gmx_MMPBSA -v || true

NPROC="${SLURM_NTASKS:-16}"

echo "[INFO] Running quick GB test on about 11 frames"
if gmx_MMPBSA -h >/dev/null 2>&1; then
  mpirun -np "$NPROC" gmx_MMPBSA \
    -O \
    -i mmpbsa_gb_test.in \
    -cs md_100ns.tpr \
    -ct mmpbsa_test_90_100_dt1000_fit.xtc \
    -ci mmpbsa_index.ndx \
    -cg 0 1 \
    -cp topol.top \
    -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
    -eo FINAL_RESULTS_MMPBSA_GB_TEST.csv \
    -nogui > mmpbsa_gb_test.progress.log 2>&1
else
  gmx_MMPBSA MPI \
    -O \
    -i mmpbsa_gb_test.in \
    -cs md_100ns.tpr \
    -ct mmpbsa_test_90_100_dt1000_fit.xtc \
    -ci mmpbsa_index.ndx \
    -cg 0 1 \
    -cp topol.top \
    -o FINAL_RESULTS_MMPBSA_GB_TEST.dat \
    -eo FINAL_RESULTS_MMPBSA_GB_TEST.csv \
    -nogui > mmpbsa_gb_test.progress.log 2>&1
fi

echo "[INFO] Finished at $(date)"
ls -lh FINAL_RESULTS_MMPBSA_GB_TEST.dat FINAL_RESULTS_MMPBSA_GB_TEST.csv mmpbsa_gb_test.progress.log || true

echo "[INFO] Tail result:"
tail -n 80 FINAL_RESULTS_MMPBSA_GB_TEST.dat || true
EOS
chmod +x 22_test_gmx_mmpbsa_one.slurm

###############################################################################
# 23_gmx_mmpbsa_array_gb.slurm
###############################################################################
cat > 23_gmx_mmpbsa_array_gb.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_gb
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
#SBATCH --array=0-8
#SBATCH --output=mmpbsa_gb_%A_%a.out
#SBATCH --error=mmpbsa_gb_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

JOBS=(
"drugs2263 rep1"
"drugs2263 rep2"
"drugs2263 rep3"
"drugs3003 rep1"
"drugs3003 rep2"
"drugs3003 rep3"
"drugs3523 rep1"
"drugs3523 rep2"
"drugs3523 rep3"
)

read SYS REP <<< "${JOBS[$SLURM_ARRAY_TASK_ID]}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] Array ID: ${SLURM_ARRAY_TASK_ID}"
echo "[INFO] SYS=$SYS REP=$REP"
echo "[INFO] SLURM_NTASKS=${SLURM_NTASKS:-NA}"

cd "$OUTROOT/$SYS/$REP"

set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  gmx_MMPBSA_1.5.2 || true
fi

if ! command -v gmx_MMPBSA >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base)"
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate gmxMMPBSA
  fi
fi

which gmx_MMPBSA
gmx_MMPBSA -v || true
NPROC="${SLURM_NTASKS:-16}"

echo "[INFO] Running production MM/GBSA on 50-100 ns trajectory"
mpirun -np "$NPROC" gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_prod.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB.csv \
  -nogui > mmpbsa_gb.progress.log 2>&1

echo "[INFO] Finished at $(date)"
ls -lh FINAL_RESULTS_MMPBSA_GB.dat FINAL_RESULTS_MMPBSA_GB.csv mmpbsa_gb.progress.log || true
tail -n 80 FINAL_RESULTS_MMPBSA_GB.dat || true
EOS
chmod +x 23_gmx_mmpbsa_array_gb.slurm

###############################################################################
# 24_gmx_mmpbsa_array_gb_pb.slurm
###############################################################################
cat > 24_gmx_mmpbsa_array_gb_pb.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_gbpb
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
#SBATCH --array=0-8
#SBATCH --output=mmpbsa_gbpb_%A_%a.out
#SBATCH --error=mmpbsa_gbpb_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

JOBS=(
"drugs2263 rep1"
"drugs2263 rep2"
"drugs2263 rep3"
"drugs3003 rep1"
"drugs3003 rep2"
"drugs3003 rep3"
"drugs3523 rep1"
"drugs3523 rep2"
"drugs3523 rep3"
)

read SYS REP <<< "${JOBS[$SLURM_ARRAY_TASK_ID]}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] SYS=$SYS REP=$REP"

cd "$OUTROOT/$SYS/$REP"

set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  gmx_MMPBSA_1.5.2 || true
fi

if ! command -v gmx_MMPBSA >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base)"
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate gmxMMPBSA
  fi
fi

which gmx_MMPBSA
NPROC="${SLURM_NTASKS:-16}"

echo "[INFO] Running production MM/GBSA + MM/PBSA on 50-100 ns trajectory"
mpirun -np "$NPROC" gmx_MMPBSA \
  -O \
  -i mmpbsa_gb_pb_prod.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB_PB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB_PB.csv \
  -nogui > mmpbsa_gb_pb.progress.log 2>&1

echo "[INFO] Finished at $(date)"
ls -lh FINAL_RESULTS_MMPBSA_GB_PB.dat FINAL_RESULTS_MMPBSA_GB_PB.csv mmpbsa_gb_pb.progress.log || true
tail -n 120 FINAL_RESULTS_MMPBSA_GB_PB.dat || true
EOS
chmod +x 24_gmx_mmpbsa_array_gb_pb.slurm

###############################################################################
# 25_gmx_mmpbsa_array_decomp_gb.slurm
###############################################################################
cat > 25_gmx_mmpbsa_array_decomp_gb.slurm <<'EOS'
#!/bin/bash
#SBATCH --job-name=mmpbsa_decomp
#SBATCH --partition=<REDACTED>
#SBATCH -N 1
#SBATCH --ntasks-per-node=16
#SBATCH --array=0-8
#SBATCH --output=mmpbsa_decomp_%A_%a.out
#SBATCH --error=mmpbsa_decomp_%A_%a.err

set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
OUTROOT="$BASE/gmx_mmpbsa_50_100ns"

JOBS=(
"drugs2263 rep1"
"drugs2263 rep2"
"drugs2263 rep3"
"drugs3003 rep1"
"drugs3003 rep2"
"drugs3003 rep3"
"drugs3523 rep1"
"drugs3523 rep2"
"drugs3523 rep3"
)

read SYS REP <<< "${JOBS[$SLURM_ARRAY_TASK_ID]}"

echo "[INFO] Job started at $(date)"
echo "[INFO] Host: $(hostname)"
echo "[INFO] SYS=$SYS REP=$REP"

cd "$OUTROOT/$SYS/$REP"

set +e
if type module >/dev/null 2>&1; then
  module load gmx_mmpbsa/1.5.2-gcc-9.3.0 2>/dev/null
  module load gmx_MMPBSA/1.4.3-gcc-9.3.0-ambertools-20-gromacs2021 2>/dev/null
  module load miniconda3/22.11.1 2>/dev/null
fi
set -e

if command -v gmx_MMPBSA_1.5.2 >/dev/null 2>&1; then
  gmx_MMPBSA_1.5.2 || true
fi

if ! command -v gmx_MMPBSA >/dev/null 2>&1; then
  if command -v conda >/dev/null 2>&1; then
    CONDA_BASE="$(conda info --base)"
    source "${CONDA_BASE}/etc/profile.d/conda.sh"
    conda activate gmxMMPBSA
  fi
fi

which gmx_MMPBSA
NPROC="${SLURM_NTASKS:-16}"

echo "[INFO] Running residue-wise MM/GBSA decomposition"
mpirun -np "$NPROC" gmx_MMPBSA \
  -O \
  -i mmpbsa_decomp_gb.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 \
  -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_DECOMP_GB.dat \
  -do FINAL_DECOMP_MMPBSA_GB.dat \
  -eo FINAL_RESULTS_MMPBSA_DECOMP_GB.csv \
  -deo FINAL_DECOMP_MMPBSA_GB.csv \
  -nogui > mmpbsa_decomp_gb.progress.log 2>&1

echo "[INFO] Finished at $(date)"
ls -lh FINAL_RESULTS_MMPBSA_DECOMP_GB.dat FINAL_DECOMP_MMPBSA_GB.dat FINAL_DECOMP_MMPBSA_GB.csv mmpbsa_decomp_gb.progress.log || true
tail -n 120 FINAL_DECOMP_MMPBSA_GB.dat || true
EOS
chmod +x 25_gmx_mmpbsa_array_decomp_gb.slurm

###############################################################################
# 26_check_gmx_mmpbsa_outputs.sh
###############################################################################
cat > 26_check_gmx_mmpbsa_outputs.sh <<'EOS'
#!/usr/bin/env bash
set -euo pipefail

BASE="${BASE:-<PROJECT_ROOT>/gromacs-runs}"
OUTROOT="${OUTROOT:-$BASE/gmx_mmpbsa_50_100ns}"

SYSTEMS=("drugs2263" "drugs3003" "drugs3523")
REPS=("rep1" "rep2" "rep3")

printf "%-10s %-5s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
  "system" "rep" "gb_dat" "gb_csv" "gbpb_dat" "decomp" "errors" "status"

for SYS in "${SYSTEMS[@]}"; do
  for REP in "${REPS[@]}"; do
    D="$OUTROOT/$SYS/$REP"

    gb_dat="NO"; gb_csv="NO"; gbpb_dat="NO"; decomp="NO"; errors="NO"; status="PASS"

    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.dat" ]] && gb_dat="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB.csv" ]] && gb_csv="YES"
    [[ -s "$D/FINAL_RESULTS_MMPBSA_GB_PB.dat" ]] && gbpb_dat="YES"
    [[ -s "$D/FINAL_DECOMP_MMPBSA_GB.dat" ]] && decomp="YES"

    if grep -R -iE "fatal|error|traceback|segmentation|nan|not finite|bad atom type|could not|failed" "$D"/*.log "$D"/*.dat 2>/dev/null | grep -v -i "estimated" >/dev/null 2>&1; then
      errors="YES"
      status="CHECK"
    fi

    if [[ "$gb_dat" == "NO" ]]; then
      status="MISSING_GB"
    fi

    printf "%-10s %-5s %-10s %-10s %-10s %-10s %-10s %-10s\n" \
      "$SYS" "$REP" "$gb_dat" "$gb_csv" "$gbpb_dat" "$decomp" "$errors" "$status"
  done
done

echo
echo "[INFO] Dangerous keyword details:"
grep -R -iE "fatal|traceback|segmentation|nan|not finite|bad atom type|could not|failed" "$OUTROOT"/*/*/*.log "$OUTROOT"/*/*/*.dat 2>/dev/null || echo "No obvious dangerous keywords found."
EOS
chmod +x 26_check_gmx_mmpbsa_outputs.sh

###############################################################################
# 27_collect_gmx_mmpbsa_results.py
###############################################################################
cat > 27_collect_gmx_mmpbsa_results.py <<'EOS'
#!/usr/bin/env python3
import argparse
import csv
import math
import re
import statistics
from pathlib import Path

TERMS = [
    "VDWAALS", "EEL",
    "EGB", "EPB",
    "ESURF", "ENPOLAR", "EDISPER",
    "DELTA G gas", "DELTA G solv", "DELTA TOTAL"
]

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

COLORS = {
    "drugs2263": "#4C78A8",
    "drugs3003": "#59A14F",
    "drugs3523": "#E15759",
}

def mean(xs):
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return statistics.mean(xs) if xs else float("nan")

def sd(xs):
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return statistics.stdev(xs) if len(xs) >= 2 else float("nan")

def sem(xs):
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return statistics.stdev(xs) / math.sqrt(len(xs)) if len(xs) >= 2 else float("nan")

def parse_float_list(line):
    return [float(x) for x in re.findall(r"[-+]?\d+\.\d+(?:[Ee][-+]?\d+)?|[-+]?\d+(?:[Ee][-+]?\d+)", line)]

def detect_model(line, current):
    u = line.upper()
    if "GENERALIZED BORN" in u or "GB" in u and "CALCULATION" in u:
        return "GB"
    if "POISSON BOLTZMANN" in u or "PB" in u and "CALCULATION" in u:
        return "PB"
    return current

def parse_dat(dat_path):
    rows = []
    if not dat_path.exists():
        return rows

    model = "NA"
    in_diff = False

    for raw in dat_path.read_text(errors="ignore").splitlines():
        line = raw.strip()
        if not line:
            continue

        model = detect_model(line, model)
        upper = line.upper()

        if "DIFFERENCES" in upper or "DELTA" in upper and "COMPLEX" in upper and "RECEPTOR" in upper:
            in_diff = True
            continue

        if upper.endswith(":") and any(x in upper for x in ["COMPLEX", "RECEPTOR", "LIGAND"]):
            in_diff = False

        # We mainly want the Differences table.
        if not in_diff:
            continue

        for term in TERMS:
            if upper.startswith(term.upper()):
                nums = parse_float_list(line)
                if nums:
                    rows.append({
                        "model": model,
                        "term": term,
                        "average": nums[0],
                        "sd_prop": nums[1] if len(nums) > 1 else float("nan"),
                        "sd": nums[2] if len(nums) > 2 else float("nan"),
                        "source": str(dat_path)
                    })
                break

    # Fallback: if parser did not catch difference table, parse any DELTA TOTAL-like line.
    if not rows:
        for raw in dat_path.read_text(errors="ignore").splitlines():
            line = raw.strip()
            upper = line.upper()
            model = detect_model(line, model)
            for term in TERMS:
                if upper.startswith(term.upper()):
                    nums = parse_float_list(line)
                    if nums:
                        rows.append({
                            "model": model,
                            "term": term,
                            "average": nums[0],
                            "sd_prop": nums[1] if len(nums) > 1 else float("nan"),
                            "sd": nums[2] if len(nums) > 2 else float("nan"),
                            "source": str(dat_path)
                        })
                    break
    return rows

def write_csv(path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"[WRITE] {path}")

def collect(root):
    all_rows = []
    for sys in SYSTEMS:
        for rep in REPS:
            d = root / sys / rep

            files = [
                ("GB", d / "FINAL_RESULTS_MMPBSA_GB.dat"),
                ("GB_PB", d / "FINAL_RESULTS_MMPBSA_GB_PB.dat"),
                ("DECOMP_GB", d / "FINAL_RESULTS_MMPBSA_DECOMP_GB.dat"),
                ("TEST", d / "FINAL_RESULTS_MMPBSA_GB_TEST.dat"),
            ]

            for calc, dat in files:
                if not dat.exists():
                    continue
                parsed = parse_dat(dat)
                for r in parsed:
                    r["system"] = sys
                    r["rep"] = rep
                    r["calc"] = calc
                    all_rows.append(r)
    return all_rows

def summarize(rows):
    summary = []
    keys = sorted(set((r["calc"], r["model"], r["system"], r["term"]) for r in rows))
    for calc, model, sys, term in keys:
        vals = [r["average"] for r in rows if r["calc"] == calc and r["model"] == model and r["system"] == sys and r["term"] == term]
        summary.append({
            "calc": calc,
            "model": model,
            "system": sys,
            "term": term,
            "n_reps": len(vals),
            "mean": mean(vals),
            "sd": sd(vals),
            "sem": sem(vals),
            "values": ";".join(f"{v:.6g}" for v in vals)
        })
    return summary

def plot_delta_total(summary, outdir):
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"[WARN] matplotlib not available: {e}")
        return

    plt.rcParams.update({
        "font.family": "Arial",
        "font.size": 8,
        "axes.linewidth": 0.8,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "xtick.major.width": 0.8,
        "ytick.major.width": 0.8,
    })

    for calc in sorted(set(r["calc"] for r in summary)):
        for model in sorted(set(r["model"] for r in summary if r["calc"] == calc)):
            data = []
            labels = []
            colors = []
            for sys in SYSTEMS:
                match = [r for r in summary if r["calc"] == calc and r["model"] == model and r["system"] == sys and r["term"] == "DELTA TOTAL"]
                if not match:
                    continue
                vals = [float(x) for x in match[0]["values"].split(";") if x]
                data.append(vals)
                labels.append(sys)
                colors.append(COLORS.get(sys, "#777777"))

            if not data:
                continue

            fig, ax = plt.subplots(figsize=(3.2, 2.6))
            bp = ax.boxplot(data, patch_artist=True, widths=0.55, showfliers=True)
            for patch, c in zip(bp["boxes"], colors):
                patch.set_facecolor(c)
                patch.set_alpha(0.55)
                patch.set_linewidth(0.8)
            for elem in ["whiskers", "caps", "medians"]:
                for item in bp[elem]:
                    item.set_linewidth(0.8)

            for i, vals in enumerate(data, start=1):
                ax.scatter([i] * len(vals), vals, s=18, zorder=3, color=colors[i-1], edgecolor="black", linewidth=0.3)

            ax.axhline(0, color="black", linewidth=0.6, linestyle="--")
            ax.set_xticklabels(labels, rotation=20, ha="right")
            ax.set_ylabel("Binding free energy, ΔG (kcal/mol)")
            ax.set_title(f"{calc} | {model} | ΔGbind")
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            fig.tight_layout()
            path = outdir / f"fig_delta_total_{calc}_{model}.pdf"
            fig.savefig(path)
            fig.savefig(path.with_suffix(".png"), dpi=600)
            plt.close(fig)
            print(f"[WRITE] {path}")

def plot_components(summary, outdir):
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"[WARN] matplotlib not available: {e}")
        return

    terms = ["VDWAALS", "EEL", "EGB", "EPB", "ESURF", "ENPOLAR", "EDISPER", "DELTA G gas", "DELTA G solv", "DELTA TOTAL"]

    for calc in sorted(set(r["calc"] for r in summary)):
        for model in sorted(set(r["model"] for r in summary if r["calc"] == calc)):
            available_terms = []
            for t in terms:
                if any(r["calc"] == calc and r["model"] == model and r["term"] == t for r in summary):
                    available_terms.append(t)

            if not available_terms:
                continue

            x = list(range(len(available_terms)))
            width = 0.23

            fig, ax = plt.subplots(figsize=(6.8, 3.0))
            for si, sys in enumerate(SYSTEMS):
                ys = []
                es = []
                for t in available_terms:
                    m = [r for r in summary if r["calc"] == calc and r["model"] == model and r["system"] == sys and r["term"] == t]
                    if m:
                        ys.append(float(m[0]["mean"]))
                        es.append(float(m[0]["sd"]) if m[0]["sd"] == m[0]["sd"] else 0.0)
                    else:
                        ys.append(float("nan"))
                        es.append(0.0)

                xpos = [v + (si - 1) * width for v in x]
                ax.bar(xpos, ys, width=width, yerr=es, capsize=2, label=sys, color=COLORS.get(sys, "#777777"), alpha=0.75, linewidth=0.4, edgecolor="black")

            ax.axhline(0, color="black", linewidth=0.6)
            ax.set_xticks(x)
            ax.set_xticklabels(available_terms, rotation=35, ha="right")
            ax.set_ylabel("Energy component (kcal/mol)")
            ax.set_title(f"{calc} | {model} | MM/PB(GB)SA components")
            ax.legend(frameon=False, fontsize=7)
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            fig.tight_layout()
            path = outdir / f"fig_components_{calc}_{model}.pdf"
            fig.savefig(path)
            fig.savefig(path.with_suffix(".png"), dpi=600)
            plt.close(fig)
            print(f"[WRITE] {path}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    ap.add_argument("--out", default="gmx_mmpbsa_summary")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    rows = collect(root)
    if not rows:
        print("[ERROR] No gmx_MMPBSA result rows parsed.")
        return

    write_csv(
        outdir / "mmpbsa_replicate_energy_terms.csv",
        rows,
        ["system", "rep", "calc", "model", "term", "average", "sd_prop", "sd", "source"]
    )

    summary = summarize(rows)
    write_csv(
        outdir / "mmpbsa_system_summary.csv",
        summary,
        ["calc", "model", "system", "term", "n_reps", "mean", "sd", "sem", "values"]
    )

    # A reviewer-friendly compact table: DELTA TOTAL only.
    compact = [r for r in summary if r["term"] == "DELTA TOTAL"]
    write_csv(
        outdir / "mmpbsa_delta_total_summary.csv",
        compact,
        ["calc", "model", "system", "term", "n_reps", "mean", "sd", "sem", "values"]
    )

    plot_delta_total(summary, outdir)
    plot_components(summary, outdir)

    print("\n[DONE] Collection finished.")
    print(f"Summary directory: {outdir}")

if __name__ == "__main__":
    main()
EOS
chmod +x 27_collect_gmx_mmpbsa_results.py

###############################################################################
# 28_extract_top_decomp_residues.py
###############################################################################
cat > 28_extract_top_decomp_residues.py <<'EOS'
#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from collections import defaultdict

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

def parse_decomp_dat(path):
    rows = []
    if not path.exists():
        return rows

    for line in path.read_text(errors="ignore").splitlines():
        s = line.strip()
        if not s:
            continue

        # Heuristic parser for residue decomposition lines.
        # Common terms may include residue identifier followed by internal/vdw/eel/polar/nonpolar/total.
        nums = re.findall(r"[-+]?\d+\.\d+(?:[Ee][-+]?\d+)?|[-+]?\d+(?:[Ee][-+]?\d+)", s)
        if len(nums) < 2:
            continue

        # Try to avoid headers and pure numeric lines.
        if any(h in s.upper() for h in ["TOTAL", "SIDECHAIN", "BACKBONE", "RESIDUE"]):
            pass

        # Typical residue token: A:123:LYS, LYS 123, R:LYS:123, etc.
        tokens = s.split()
        residue = tokens[0]
        # last numeric value is often total contribution; this is a fallback.
        total = float(nums[-1])
        if abs(total) > 10000:
            continue
        rows.append({"residue": residue, "total": total, "line": s})
    return rows

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    ap.add_argument("--out", default="gmx_mmpbsa_summary/top_decomp_residues.csv")
    ap.add_argument("--topn", type=int, default=20)
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    all_rows = []
    for sys in SYSTEMS:
        for rep in REPS:
            p = root / sys / rep / "FINAL_DECOMP_MMPBSA_GB.dat"
            parsed = parse_decomp_dat(p)
            for r in parsed:
                r["system"] = sys
                r["rep"] = rep
                r["source"] = str(p)
                all_rows.append(r)

    # This is deliberately conservative because decomp output formats vary.
    # It stores raw lines; manually inspect the top rows before manuscript use.
    all_rows.sort(key=lambda x: x["total"])

    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["system", "rep", "residue", "total", "line", "source"])
        w.writeheader()
        for r in all_rows[: args.topn * 9]:
            w.writerow(r)

    print(f"[WRITE] {out}")
    print("[NOTE] Decomposition output formats vary. Please manually inspect residue labels before final manuscript use.")

if __name__ == "__main__":
    main()
EOS
chmod +x 28_extract_top_decomp_residues.py

###############################################################################
# 29_gmx_mmpbsa_methods_template.txt
###############################################################################
cat > 29_gmx_mmpbsa_methods_template.txt <<'EOS'
MM/GBSA and MM/PBSA binding free-energy estimation

To further refine the docking-derived binding poses and quantitatively assess the relative binding stability of the A35R–ligand complexes, MM/GBSA and MM/PBSA calculations were performed using gmx_MMPBSA. For each ligand, three independent 100-ns GROMACS trajectories were used. The last 50 ns of each trajectory were extracted at 500-ps intervals, giving approximately 101 snapshots per replicate and approximately 303 snapshots per ligand. Prior to energy calculation, trajectories were processed with GROMACS trjconv to remove periodic boundary artifacts, center the protein–ligand complex, and fit the trajectory to the protein–ligand complex. The single-trajectory protocol was used, in which receptor and ligand conformations were extracted from the same complex trajectory. The receptor group was defined as the protein atoms and the ligand group as the LIG residue. The GROMACS topology generated from the Amber/GAFF2-parametrized system was provided directly to gmx_MMPBSA, thereby retaining the ligand parameters and partial charges used in the MD simulations. The generalized Born model was calculated with igb = 5 and a salt concentration of 0.150 M. In additional validation runs, Poisson–Boltzmann calculations were performed with an ionic strength of 0.150 M. The binding free energy was estimated as ΔGbind = Gcomplex − Greceptor − Gligand. Energy components, including van der Waals, electrostatic, polar solvation, and nonpolar solvation contributions, were extracted for each system. Residue-wise energy decomposition was further performed to identify residues that contributed most strongly to ligand binding.

Result-description template

Compared with the initial docking score-based ranking, the MM/GBSA/MM/PBSA analysis provided a trajectory-ensemble-based estimate of binding stability after explicit-solvent MD refinement. A more negative ΔGbind indicates a more favorable calculated binding free energy under the same force-field and implicit-solvent settings. The decomposition of ΔGbind into van der Waals, electrostatic, polar solvation, and nonpolar solvation terms allows the dominant energetic drivers of binding to be assessed. In this study, the three A35R–ligand systems were evaluated using three independent 100-ns simulations, thereby reducing the dependence on a single docking pose or a single MD trajectory. Residue-wise decomposition was used to identify binding-site residues with favorable energetic contributions and to support the detailed interaction analysis of the predicted binding poses.
EOS

echo
echo "[DONE] All scripts created."
ls -lh 20_check_gmx_mmpbsa_env.sh \
       20A_create_conda_env_gmxMMPBSA.sh \
       21_prepare_gmx_mmpbsa_inputs.sh \
       22_test_gmx_mmpbsa_one.slurm \
       23_gmx_mmpbsa_array_gb.slurm \
       24_gmx_mmpbsa_array_gb_pb.slurm \
       25_gmx_mmpbsa_array_decomp_gb.slurm \
       26_check_gmx_mmpbsa_outputs.sh \
       27_collect_gmx_mmpbsa_results.py \
       28_extract_top_decomp_residues.py \
       29_gmx_mmpbsa_methods_template.txt
