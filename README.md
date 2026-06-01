# MPOX-JCAMD

Public supplementary code and processed analysis outputs for a molecular modelling study of monkeypox virus protein-ligand complexes. This repository collects AlphaFold command templates, AutoDock Vina docking inputs/results, GROMACS molecular dynamics (MD) analysis materials, and gmx_MMPBSA MM/GBSA workflows/results used to evaluate candidate antiviral compounds.

## Project Scope

This repository is intended for public review and reproducibility of the computational workflow. It contains scripts, parameter files, docking receptor/config files, packaged docking logs, processed CSV tables, representative example inputs, figures, and documentation. Raw production trajectories and large binary simulation files are intentionally not distributed through GitHub.

The public release is organized around three levels of evidence:

- Broad AutoDock Vina screening against seven monkeypox virus targets.
- Follow-up GROMACS MD analysis for selected A35R protein-ligand systems.
- Post hoc gmx_MMPBSA MM/GBSA analysis of selected A35R MD trajectories.

## Studied Systems

| Internal ID | Compound | Experimental Biacore KD | MD replicates | Production length |
|---|---|---:|---:|---:|
| `drugs2263` | Eltrombopag | 60.7 uM | 3 | 100 ns each |
| `drugs3003` | Cepharanthine | 436 uM | 3 | 100 ns each |
| `drugs3523` | Simeprevir | 356 uM | 3 | 100 ns each |

The experimental affinity data indicate micromolar binding for all three compounds, with eltrombopag showing the lowest KD among the tested ligands. The MD and MM/GBSA results should be interpreted as structural and energetic support for the binding hypotheses, not as a direct quantitative replacement for the Biacore measurements.

## Docking Targets

The `Docking/` directory contains receptor structures, AutoDock Vina configuration files, receptor PDBQT files, and packaged docking logs for the following targets:

| Target | Receptor PDB | Receptor PDBQT | Vina config | Packaged logs |
|---|---|---|---|---|
| A20 | `Docking/PDB/A20.pdb` | `Docking/pdbqt/A20.pdbqt` | `Docking/config/configA20.txt` | `Docking/docking results/A20.zip` |
| A29L | `Docking/PDB/A29L.pdb` | `Docking/pdbqt/A29L.pdbqt` | `Docking/config/configA29L.txt` | `Docking/docking results/A29L.zip` |
| A30L | `Docking/PDB/A30L.pdb` | `Docking/pdbqt/A30L.pdbqt` | `Docking/config/configA30L.txt` | `Docking/docking results/A30L.zip` |
| A35R | `Docking/PDB/A35R.pdb` | `Docking/pdbqt/A35R.pdbqt` | `Docking/config/configA35R.txt` | `Docking/docking results/A35R.zip` |
| DNA polymerase | `Docking/PDB/DNApolymearse.pdb` | `Docking/pdbqt/DNA polymerase.pdbqt` | `Docking/config/configDNA_polymerase.txt` | `Docking/docking results/DNA polymerase.zip` |
| E4R | `Docking/PDB/E4R.pdb` | `Docking/pdbqt/E4R.pdbqt` | `Docking/config/configE4R.txt` | `Docking/docking results/E4R.zip` |
| E8L | `Docking/PDB/E8L.pdb` | `Docking/pdbqt/E8L.pdbqt` | `Docking/config/configE8L.txt` | `Docking/docking results/E8L.zip` |

## Repository Layout

```text
MPOX-JCAMD/
|-- README.md
|-- AlphaFold_PTM.sh             # Minimal AlphaFold/monomer-PTM command template
|-- autodock_vina.sh             # Minimal AutoDock Vina batch-docking template
|-- Docking/                     # Docking receptors, configs, PDBQT files, and packaged Vina logs
|-- A35R-GROMACS-MD/             # Sanitized GROMACS MD code, parameters, tables, and figures
`-- A35R-MMPBSA/                 # Sanitized gmx_MMPBSA workflow, example inputs, summaries, and figures
```

## Main Components

| Path | Description |
|---|---|
| `AlphaFold_PTM.sh` | Minimal command template for AlphaFold monomer-PTM prediction. |
| `autodock_vina.sh` | Minimal AutoDock Vina batch-docking template; edit paths/configs before reuse. |
| `Docking/README.md` | Docking data notes, target list, and archive layout. |
| `Docking/PDB/` | Receptor PDB files used for docking preparation. |
| `Docking/pdbqt/` | Receptor PDBQT files used by AutoDock Vina. |
| `Docking/config/` | Per-target AutoDock Vina search-space configuration files. |
| `Docking/docking results/` | One `.zip` archive per target containing the Vina log files for that target. |
| `A35R-GROMACS-MD/README.md` | Detailed MD release notes, included/excluded file classes, and public manifest information. |
| `A35R-GROMACS-MD/METHODS_MD.md` | Manuscript-ready GROMACS MD methods and analysis description. |
| `A35R-GROMACS-MD/02_parameters/` | GROMACS `.mdp` files and AMBER-to-GROMACS conversion reports. |
| `A35R-GROMACS-MD/03_code/` | SLURM, shell, and Python scripts for MD execution, checks, analysis, and plotting. |
| `A35R-GROMACS-MD/04_summary_tables/` | Combined MD summary tables used for statistics and figures. |
| `A35R-GROMACS-MD/05_per_replicate_csv/` | Per-system/per-replicate MD analysis CSV outputs. |
| `A35R-GROMACS-MD/06_figures/` | MD figures in PNG, PDF, and SVG formats. |
| `A35R-MMPBSA/README.md` | Detailed MM/GBSA workflow documentation. |
| `A35R-MMPBSA/REPRODUCIBILITY.md` | Reproducibility notes and evidence boundaries for MM/GBSA analysis. |
| `A35R-MMPBSA/environment.yml` | Conda environment specification for the MM/GBSA workflow. |
| `A35R-MMPBSA/workflow/` | Environment checks, input preparation, SLURM templates, parsers, and visualization scripts. |
| `A35R-MMPBSA/results/` | Processed MM/GBSA summary tables and selected example output. |
| `A35R-MMPBSA/figures/` | MM/GBSA summary/decomposition figures. |

## Quick Start

Clone the repository:

```bash
git clone https://github.com/lg10is1/MPOX-JCAMD.git
cd MPOX-JCAMD
```

Create the MM/GBSA analysis environment:

```bash
cd A35R-MMPBSA
conda env create -f environment.yml
conda activate a35r-mmpbsa
```

For MD plotting/inspection scripts, a minimal Python environment should include:

```bash
python -m pip install numpy pandas matplotlib parmed
```

The SLURM scripts are templates from an HPC workflow. Replace placeholders such as `<PROJECT_ROOT>`, `<PARTITION>`, `<ACCOUNT>`, `<CLUSTER_FS>`, and module names before rerunning them on a new system.

To inspect the packaged docking logs, extract the target archive of interest:

```bash
cd "Docking/docking results"
unzip A35R.zip -d A35R
```

The expanded docking log folders are ignored by Git to keep the public repository manageable. Keep the `.zip` archives as the shareable release files.

## Software Used

The archived workflow records the following core tools:

| Component | Version or note |
|---|---|
| AlphaFold | Monomer-PTM command template provided; local database/runtime paths must be supplied by the user |
| AutoDock Vina | Batch-docking command template and per-target configs provided; local ligand library paths must be supplied by the user |
| GROMACS | 2021.3-series runtime recorded in analysis logs |
| gmx_MMPBSA | v1.5.6 |
| AmberTools | Amber20 runtime tools recorded for MM/GBSA |
| Python | 3.9-series runtime recorded for MM/GBSA workflow |
| Python packages | `numpy`, `pandas`, `matplotlib`, `ParmEd` |

## Data Availability Notes

Included:

- Sanitized workflow scripts and parameter files.
- Docking receptor PDB/PDBQT files and Vina configuration files.
- Packaged docking log archives, with one `.zip` file per target under `Docking/docking results/`.
- Processed MD and MM/GBSA CSV summary tables.
- Per-replicate MD analysis CSV exports.
- Selected example MM/GBSA input/output files.
- Publication-style figures.

Not included:

- Raw MD trajectories (`*.xtc`, `*.trr`).
- GROMACS binary run, checkpoint, and energy files (`*.tpr`, `*.cpt`, `*.edr`).
- Full production logs and raw XVG files.
- Large working directories and cluster-specific temporary files.
- Expanded docking log folders, which can be recreated by extracting the target `.zip` archives.

One processed table, `A35R-MMPBSA/results/figure_tables/md_all_timeseries_long.csv`, is approximately 62 MB. It is below GitHub's hard file-size limit but may be better handled with Git LFS if the repository grows.

## Interpretation Notes

The MD datasets describe structural stability and protein-ligand contact persistence across three 100 ns replicates per compound. The MM/GBSA datasets estimate post hoc binding free-energy components from MD snapshots, mainly over the 50-100 ns production window. These calculations are useful for comparing simulation-derived trends, but experimental KD values from Biacore should be treated as the primary binding evidence.

The archived ligand RMSD analysis should be interpreted carefully. As documented in `A35R-GROMACS-MD/METHODS_MD.md`, ligand RMSD values from the original workflow appear to reflect ligand internal conformational fluctuation after ligand self-fitting. For binding-pose retention claims, recalculate ligand-heavy-atom RMSD in a protein-fitted coordinate frame.

## Citation

If you use this repository, please cite the associated article when available. Please also cite the underlying software where appropriate, including GROMACS and gmx_MMPBSA.

Suggested software references:

1. Valdes-Tresanco, M. S.; Valdes-Tresanco, M. E.; Valiente, P. A.; Moreno, E. gmx_MMPBSA: A New Tool to Perform End-State Free Energy Calculations with GROMACS. *Journal of Chemical Theory and Computation* 2021, 17, 6281-6291. https://doi.org/10.1021/acs.jctc.1c00645
2. Abraham, M. J.; et al. GROMACS: High performance molecular simulations through multi-level parallelism from laptops to supercomputers. *SoftwareX* 2015, 1-2, 19-25. https://doi.org/10.1016/j.softx.2015.06.001
