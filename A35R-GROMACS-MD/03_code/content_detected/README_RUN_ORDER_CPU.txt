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

