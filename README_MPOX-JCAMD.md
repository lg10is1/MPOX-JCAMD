# MPOX-JCAMD

Public supplementary code, docking outputs, and processed molecular simulation analysis files for the manuscript:

**Structure Prediction and Drug Screening Targeting Monkeypox Virus Polymerase and Surface Proteins**

This repository supports public inspection and partial reproducibility of a structure-guided screening workflow for monkeypox virus (MPXV) proteins. The study combines AlphaFold-based structure prediction, AutoDock Vina virtual screening, surface plasmon resonance (SPR) binding assessment, GROMACS molecular dynamics (MD) simulations, and gmx_MMPBSA MM/GBSA analysis.

## Scope of this repository

This repository is intended to document the computational workflow and processed analysis outputs used in the revised manuscript and response to reviewers. It includes receptor structures, docking configuration files, receptor PDBQT files, packaged docking logs, workflow scripts, MD analysis scripts, processed summary tables, MM/GBSA outputs, and publication-style figures.

The repository should be interpreted as a reproducibility and transparency resource. It does **not** establish antiviral efficacy, cellular target engagement, clinical activity, or the therapeutic suitability of any compound.

## Evidence boundaries

The revised manuscript and this repository use the following cautious interpretation framework.

1. **Virtual screening**
   - AutoDock Vina docking was used as an initial prioritization step.
   - Docking scores were not interpreted as direct evidence of antiviral activity.
   - Blind/global docking was used because most selected MPXV targets lack co-crystallized small-molecule ligands or well-characterized orthosteric pockets.
   - Docking results should be regarded as binding hypotheses requiring experimental and functional validation.

2. **SPR binding assessment**
   - SPR provided preliminary in vitro A35R-associated binding responses for selected compounds.
   - The reported KD values are apparent steady-state estimates.
   - The highest analyte concentration used in the SPR assay was 100 µM. Therefore, compounds with fitted KD values above 100 µM should be interpreted cautiously as weak apparent binders rather than as precisely quantified high-confidence affinities.
   - The SPR results do not demonstrate antiviral activity, cellular target engagement, or therapeutic efficacy.

3. **MD simulations**
   - MD simulations were used to examine post-docking structural relaxation, protein-ligand spatial association, protein-ligand contacts, hydrogen bonds, and global structural descriptors.
   - Ligand RMSD was used as a descriptive metric of ligand conformational variation and was interpreted together with protein-ligand minimum distance, contact counts, hydrogen-bond analysis, and MM/GBSA results.
   - Ligand RMSD should not be used alone as definitive proof that the initial docking pose was preserved throughout the simulation.

4. **MM/GBSA analysis**
   - MM/GBSA calculations were used as post hoc energetic indicators derived from MD snapshots.
   - Entropic contributions were not included.
   - The MM/GBSA values should therefore be interpreted as relative simulation-derived energetic indicators rather than absolute binding free energies or replacements for experimental KD values.

5. **A35R target interpretation**
   - A35R is treated as an exploratory MPXV surface-protein target for preliminary small-molecule binding assessment.
   - The present data do not establish A35R as a validated small-molecule antiviral target.
   - Orthogonal biophysical validation, aggregation controls, targeted mutagenesis, structure-activity relationship analysis, and cell-based antiviral assays are required in future work.

## Studied A35R-ligand systems

| Internal ID | Compound | SPR interpretation | Apparent steady-state KD | Highest tested SPR concentration | MD replicates | Production length |
|---|---|---:|---:|---:|---:|---:|
| `drugs2263` | Eltrombopag | Preliminary A35R-associated binder; fitted KD within tested concentration range | 60.7 µM | 100 µM | 3 | 100 ns each |
| `drugs3003` | Cepharanthine | Weak preliminary A35R-associated binder; fitted KD exceeds tested concentration range | 436 µM | 100 µM | 3 | 100 ns each |
| `drugs3523` | Simeprevir | Weak preliminary A35R-associated binder; fitted KD exceeds tested concentration range | 356 µM | 100 µM | 3 | 100 ns each |

These compounds should be described as **preliminary A35R-associated binders** or **preliminary A35R-binding hits**, not as optimized drug candidates. Their biological relevance remains to be tested by orthogonal binding assays and cell-based antiviral assays.

## Docking targets

The `Docking/` directory contains receptor structures, AutoDock Vina configuration files, receptor PDBQT files, and packaged docking logs for seven MPXV targets.

| Target | Receptor PDB | Receptor PDBQT | Vina config | Packaged logs |
|---|---|---|---|---|
| A20 | `Docking/PDB/A20.pdb` | `Docking/pdbqt/A20.pdbqt` | `Docking/config/configA20.txt` | `Docking/docking results/A20.zip` |
| A29L | `Docking/PDB/A29L.pdb` | `Docking/pdbqt/A29L.pdbqt` | `Docking/config/configA29L.txt` | `Docking/docking results/A29L.zip` |
| A30L | `Docking/PDB/A30L.pdb` | `Docking/pdbqt/A30L.pdbqt` | `Docking/config/configA30L.txt` | `Docking/docking results/A30L.zip` |
| A35R | `Docking/PDB/A35R.pdb` | `Docking/pdbqt/A35R.pdbqt` | `Docking/config/configA35R.txt` | `Docking/docking results/A35R.zip` |
| DNA polymerase | `Docking/PDB/DNApolymearse.pdb` | `Docking/pdbqt/DNA polymerase.pdbqt` | `Docking/config/configDNA_polymerase.txt` | `Docking/docking results/DNA polymerase.zip` |
| E4R | `Docking/PDB/E4R.pdb` | `Docking/pdbqt/E4R.pdbqt` | `Docking/config/configE4R.txt` | `Docking/docking results/E4R.zip` |
| E8L | `Docking/PDB/E8L.pdb` | `Docking/pdbqt/E8L.pdbqt` | `Docking/config/configE8L.txt` | `Docking/docking results/E8L.zip` |

## Workflow overview

### 1. Structure prediction and confidence assessment

Protein structures were predicted using AlphaFold-based workflows. For the revised manuscript, the monomer-PTM preset was used to generate predicted aligned error (PAE) information for the seven MPXV proteins.

The PAE and pLDDT information was used to support model-confidence assessment. For A35R, comparison with the available experimental A35R structure was included in the revised manuscript. Nevertheless, side-chain-level pocket geometry remains uncertain for predicted structures, and docking results based on such models should be interpreted cautiously.

### 2. Ligand library and receptor preparation

A total of 6,405 approved drugs were used for high-throughput screening. Ligands were prepared in AutoDock-compatible PDBQT format.

For the high-throughput docking stage:
- no independent quantum-chemical charge derivation was performed;
- no systematic pH-dependent protomer or tautomer enumeration was performed;
- ligand atom types, rotatable bonds, and partial charge fields were generated or retained during the PDBQT preparation workflow.

These choices are consistent with a broad screening workflow but represent limitations for quantitative affinity prediction.

### 3. AutoDock Vina docking

Docking was performed using AutoDock Vina. For each target, the docking box was defined to encompass the entire receptor structure, enabling blind/global docking.

This strategy was used because the selected MPXV targets, especially the surface proteins, generally lack well-characterized small-molecule binding pockets. However, blind docking can increase the risk of spurious surface or hydrophobic-site binding. Therefore, docking results should be treated as initial hypotheses.

For enzymatic targets such as DNA polymerase and E4R, DNA, Mg2+ ions, catalytic waters, or homologous ligand templates were not included in the uniform docking workflow. The corresponding docking results should therefore not be interpreted as definitive evidence of catalytic inhibition.

### 4. SPR binding assessment

SPR was used to assess selected A35R-compound interactions. The revised manuscript reports apparent steady-state KD values for cepharanthine, eltrombopag, and simeprevir.

Important interpretation notes:
- The compounds showed measurable A35R-associated SPR responses under the tested conditions.
- The SPR measurements support preliminary in vitro binding evidence.
- Because the highest injected analyte concentration was 100 µM, fitted KD values above 100 µM should be interpreted cautiously.
- Orthogonal biophysical validation, such as MST, ITC, DSF, unrelated-protein controls, tag-only controls, detergent-sensitivity testing, or DLS aggregation assessment, was not included in the current study.
- The SPR data do not demonstrate antiviral activity or therapeutic efficacy.

### 5. GROMACS MD simulations

The three SPR-tested A35R-ligand complexes were subjected to MD simulation analysis.

General simulation design:
- three independent replicates per complex;
- 100 ns production simulation per replicate;
- GROMACS 2021.3-series workflow;
- AMBER ff14SB for protein;
- GAFF2-based ligand description;
- TIP3P water model;
- periodic boundary conditions;
- post-simulation quality-control checks.

MD descriptors included:
- protein backbone RMSD;
- ligand heavy-atom RMSD;
- protein RMSF;
- radius of gyration;
- protein-ligand minimum distance;
- protein-ligand contact counts;
- hydrogen-bond analysis.

The MD analyses support continued ligand association with A35R in the analyzed trajectories, but the simulations should not be overinterpreted as proof that the initial docking pose remains unchanged. Ligand RMSD and contact analyses should be interpreted together.

### 6. MM/GBSA analysis

Binding free energies were estimated using gmx_MMPBSA from MD snapshots.

The MM/GBSA workflow was used to compare post-docking simulation-derived energetic trends among the three A35R-ligand complexes. Because entropy was not included, the calculated values should be interpreted as relative indicators rather than absolute binding free energies.

## Repository layout

```text
MPOX-JCAMD/
|-- README.md
|-- AlphaFold_PTM.sh             # Minimal AlphaFold monomer-PTM command template
|-- autodock_vina.sh             # Minimal AutoDock Vina batch-docking template
|-- Docking/                     # Docking receptors, configs, PDBQT files, and packaged Vina logs
|-- A35R-GROMACS-MD/             # GROMACS MD code, parameters, processed tables, and figures
`-- A35R-MMPBSA/                 # gmx_MMPBSA workflow, processed outputs, and figures
```

## Main components

| Path | Description |
|---|---|
| `AlphaFold_PTM.sh` | Minimal AlphaFold monomer-PTM command template. Local database/runtime paths must be supplied by the user. |
| `autodock_vina.sh` | Minimal AutoDock Vina batch-docking template. Edit paths and configuration files before reuse. |
| `Docking/README.md` | Docking data notes, target list, and archive layout. |
| `Docking/PDB/` | Receptor PDB files used for docking preparation. |
| `Docking/pdbqt/` | Receptor PDBQT files used by AutoDock Vina. |
| `Docking/config/` | Per-target AutoDock Vina search-space configuration files. |
| `Docking/docking results/` | One `.zip` archive per target containing Vina log files for that target. |
| `A35R-GROMACS-MD/README.md` | MD release notes, included/excluded file classes, and public manifest information. |
| `A35R-GROMACS-MD/METHODS_MD.md` | GROMACS MD methods and analysis description. |
| `A35R-GROMACS-MD/02_parameters/` | GROMACS `.mdp` files and AMBER-to-GROMACS conversion reports. |
| `A35R-GROMACS-MD/03_code/` | SLURM, shell, and Python scripts for MD execution, checks, analysis, and plotting. |
| `A35R-GROMACS-MD/04_summary_tables/` | Combined MD summary tables used for statistics and figures. |
| `A35R-GROMACS-MD/05_per_replicate_csv/` | Per-system and per-replicate MD analysis CSV outputs. |
| `A35R-GROMACS-MD/06_figures/` | MD figures in PNG, PDF, and SVG formats. |
| `A35R-MMPBSA/README.md` | MM/GBSA workflow documentation. |
| `A35R-MMPBSA/REPRODUCIBILITY.md` | Reproducibility notes and evidence boundaries for MM/GBSA analysis. |
| `A35R-MMPBSA/environment.yml` | Conda environment specification for the MM/GBSA workflow. |
| `A35R-MMPBSA/workflow/` | Environment checks, input preparation, SLURM templates, parsers, and visualization scripts. |
| `A35R-MMPBSA/results/` | Processed MM/GBSA summary tables and selected example output. |
| `A35R-MMPBSA/figures/` | MM/GBSA summary and decomposition figures. |

## Quick start

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

For MD plotting or inspection scripts, a minimal Python environment should include:

```bash
python -m pip install numpy pandas matplotlib parmed
```

The SLURM scripts are templates from an HPC workflow. Replace placeholders such as `<PROJECT_ROOT>`, `<PARTITION>`, `<ACCOUNT>`, `<CLUSTER_FS>`, and module names before rerunning them on a new system.

To inspect the packaged docking logs, extract the target archive of interest:

```bash
cd "Docking/docking results"
unzip A35R.zip -d A35R
```

The expanded docking log folders are ignored by Git to keep the public repository manageable. The `.zip` archives are the shareable release files.

## Software used

| Component | Version or note |
|---|---|
| AlphaFold | Monomer-PTM command template provided; local database/runtime paths must be supplied by the user |
| AutoDock Vina | Batch-docking command template and per-target configs provided |
| GROMACS | 2021.3-series runtime recorded in analysis logs |
| gmx_MMPBSA | v1.5.6 |
| AmberTools | Amber20 runtime tools recorded for MM/GBSA |
| Python | 3.9-series runtime recorded for MM/GBSA workflow |
| Python packages | `numpy`, `pandas`, `matplotlib`, `ParmEd` |

## Data availability notes

### Included

- Sanitized workflow scripts and parameter files.
- Docking receptor PDB/PDBQT files and Vina configuration files.
- Packaged docking log archives, with one `.zip` file per target under `Docking/docking results/`.
- Processed docking score tables and analysis outputs where applicable.
- Processed MD and MM/GBSA CSV summary tables.
- Per-replicate MD analysis CSV exports.
- Selected example MM/GBSA input/output files.
- Publication-style figures.

### Not included

- Raw MD trajectories (`*.xtc`, `*.trr`).
- GROMACS binary run, checkpoint, and energy files (`*.tpr`, `*.cpt`, `*.edr`).
- Full production logs and raw XVG files.
- Large working directories and cluster-specific temporary files.
- Expanded docking log folders, which can be recreated by extracting the target `.zip` archives.

One processed table, `A35R-MMPBSA/results/figure_tables/md_all_timeseries_long.csv`, is approximately 62 MB. It is below GitHub's hard file-size limit but may be better handled with Git LFS if the repository grows.

## Interpretation notes for users

The materials in this repository are provided to document how the computational results in the revised manuscript were generated and processed. They should be used with the following limitations in mind.

- Docking scores should not be interpreted as experimental binding affinities.
- Apparent SPR KD values should be interpreted in light of the tested concentration range.
- MD simulations provide structural and dynamic support for ligand association but do not prove antiviral activity.
- Ligand RMSD is a descriptive conformational metric and should not be used alone to claim docking-pose preservation.
- MM/GBSA values are relative simulation-derived indicators and are not equivalent to experimental KD values.
- The A35R-binding compounds reported here require further orthogonal validation and cell-based antiviral assays.

## Suggested terminology

When referring to the three A35R-associated compounds, the following terms are recommended:

- preliminary A35R-associated binders;
- preliminary A35R-binding hits;
- compounds showing measurable A35R-associated SPR responses;
- weak apparent binders for cepharanthine and simeprevir;
- apparent micromolar binder for eltrombopag within the tested concentration range.

The following terms should be avoided unless supported by future functional data:

- optimized drug candidates;
- validated antiviral compounds;
- proven A35R inhibitors;
- established A35R-targeting therapeutics;
- confirmed antiviral efficacy.

## Citation

If you use this repository, please cite the associated article when available. Please also cite the underlying software where appropriate, including GROMACS, AutoDock Vina, AlphaFold, and gmx_MMPBSA.

Suggested software references:

1. Valdes-Tresanco, M. S.; Valdes-Tresanco, M. E.; Valiente, P. A.; Moreno, E. gmx_MMPBSA: A New Tool to Perform End-State Free Energy Calculations with GROMACS. *Journal of Chemical Theory and Computation* 2021, 17, 6281–6291. https://doi.org/10.1021/acs.jctc.1c00645

2. Abraham, M. J.; et al. GROMACS: High performance molecular simulations through multi-level parallelism from laptops to supercomputers. *SoftwareX* 2015, 1–2, 19–25. https://doi.org/10.1016/j.softx.2015.06.001

3. Eberhardt, J.; Santos-Martins, D.; Tillack, A. F.; Forli, S. AutoDock Vina 1.2.0: New Docking Methods, Expanded Force Field, and Python Bindings. *Journal of Chemical Information and Modeling* 2021, 61, 3891–3898. https://doi.org/10.1021/acs.jcim.1c00203

## Contact

For questions about the repository or reproducibility of the computational workflow, please contact the corresponding author of the associated manuscript.
