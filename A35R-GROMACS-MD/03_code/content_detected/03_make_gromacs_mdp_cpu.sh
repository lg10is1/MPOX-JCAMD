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

