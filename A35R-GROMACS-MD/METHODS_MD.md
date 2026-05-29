# Molecular Dynamics Methods

## System Preparation

Three A35R protein-ligand complexes were analyzed by GROMACS molecular dynamics simulation: `drugs2263` (eltrombopag), `drugs3003` (cepharanthine), and `drugs3523` (simeprevir). Each system was simulated in three independent replicates (`rep1`, `rep2`, and `rep3`). The archived workflow converted prepared AMBER-format systems to GROMACS-compatible files with ParmEd; sanitized conversion reports are provided in `02_parameters/conversion_reports/`.

The public package does not include the full coordinate, topology, index, or trajectory files because they are large and may contain environment-specific metadata. The released parameter files and analysis outputs are sufficient for checking the reported protocol and reproducing downstream summary/plotting steps from deposited raw trajectories.

## MD Protocol

GROMACS 2021.3 was used for the archived simulations. A short CPU test workflow consisted of energy minimization, 20 ps NVT equilibration, 20 ps NPT equilibration, and a 20 ps production test. The final production simulations were run for 100 ns per replicate.

The production `.mdp` files are provided under `02_parameters/mdp/03_100ns_md_metadata/`. The representative archived production settings were:

| Parameter | Value |
|---|---|
| Integrator | `md` |
| Time step | 0.002 ps |
| Production steps | 50,000,000 |
| Production length | 100 ns |
| Temperature coupling | V-rescale |
| Reference temperature | 300 K |
| Pressure coupling | Parrinello-Rahman, isotropic |
| Reference pressure | 1.0 bar |
| Electrostatics | PME |
| Coulomb cutoff | 1.0 nm |
| van der Waals cutoff | 1.0 nm |
| Dispersion correction | `EnerPres` |
| Constraints | H-bonds |
| Compressed coordinate output | every 5,000 steps, equal to 10 ps |

Energy minimization used steepest descent with an archived maximum of 50,000 steps, `emtol = 1000.0`, and `emstep = 0.01`. The short NVT test used velocity generation and V-rescale coupling at 300 K. The production runs used continuation from equilibrated structures and did not generate new velocities.

## Production and Analysis Scripts

The main production-array SLURM script is:

- `03_code/analysis_slurm/06_gromacs_100ns_3rep_cpu_array.slurm`

Auxiliary scripts are grouped by purpose:

- `03_code/production_slurm/`: short-test workflow.
- `03_code/progress_check/`: 100 ns completion and speed checks.
- `03_code/check_scripts/`: analysis-output checks and XVG-to-CSV conversion helpers.
- `03_code/collect_plot_python/`: collection and plotting of GROMACS analysis metrics.
- `03_code/nature_plotting/`: manuscript-style figure generation and residue-decomposition visualization.
- `03_code/content_detected/`: historical scripts detected in the original backup, retained for traceability.

The scripts have been sanitized and are not drop-in runnable on a new cluster until placeholders such as `<PROJECT_ROOT>`, `<REDACTED>`, and module names are adapted locally.

## Trajectory Analysis

The archived analysis measured standard MD stability and interaction metrics for each 100 ns replicate. The combined and per-replicate tables are provided in `04_summary_tables/` and `05_per_replicate_csv/`.

Reported metrics include:

- Protein backbone RMSD.
- Protein residue RMSF.
- Radius of gyration.
- Protein-ligand hydrogen bonds.
- Minimum protein-ligand distance.
- Protein-ligand contact counts.
- Ligand RMSD as archived, with the caveat below.

For manuscript-level reporting, use replicate means and variability from the combined summary tables, rather than single-replicate curves alone. The most defensible description is that all three ligand-bound systems completed three 100 ns replicates and produced stable protein trajectories with persistent protein-ligand proximity/contact signals. Avoid overclaiming binding affinity from MD stability metrics alone.

## Ligand RMSD Caveat

The archived ligand RMSD output should not be used as the sole evidence for binding-pose retention. The original workflow appears to fit the ligand to itself before measuring ligand RMSD. That operation removes translational/rotational displacement of the ligand and mainly reports internal ligand conformational change.

For a binding-pose statement, recalculate ligand RMSD using a protein-fitted frame:

1. Remove periodic-boundary artifacts and center the protein-ligand complex.
2. Fit the trajectory on the protein backbone or a stable binding-site protein atom selection.
3. Measure ligand heavy-atom RMSD in that protein-fitted frame against the initial or representative bound pose.

The archived ligand RMSD values may still be described as ligand internal conformational RMSD if the fitting method is stated clearly.

## Suggested Manuscript Wording

Molecular dynamics simulations were performed for A35R in complex with eltrombopag, cepharanthine, and simeprevir. For each complex, three independent 100 ns replicates were run using GROMACS 2021.3. The production simulations used a 2 fs time step, V-rescale temperature coupling at 300 K, isotropic Parrinello-Rahman pressure coupling at 1 bar, PME electrostatics, 1.0 nm Coulomb and van der Waals cutoffs, and H-bond constraints. Trajectory stability and protein-ligand interaction persistence were evaluated using backbone RMSD, residue RMSF, radius of gyration, hydrogen-bond counts, minimum protein-ligand distances, and contact counts. Summary statistics were calculated across the three replicates, with the second half of the trajectories used for equilibrium-window summaries where applicable.

## Relationship to MM/PBSA or MM/GBSA

The GROMACS MD outputs describe structural stability and interaction persistence. MM/PBSA or MM/GBSA calculations estimate post hoc binding free-energy components from trajectory snapshots. These analyses are related because MM/PBSA/MM/GBSA depends on the MD-generated ensembles, but they answer different questions: MD stability asks whether the simulated complex remains structurally reasonable, while MM/PBSA/MM/GBSA ranks approximate energetic favorability. Experimental affinity data should be treated as the final binding evidence.

