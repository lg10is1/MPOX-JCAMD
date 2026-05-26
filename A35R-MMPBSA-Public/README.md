# A35R-Ligand Molecular Dynamics and MM/GBSA Analysis

## Overview

This repository is the sanitized supplementary-material package for molecular dynamics (MD) and MM/GBSA analysis of monkeypox virus A35R protein-ligand complexes evaluated for a manuscript submitted to the *Journal of Computer-Aided Molecular Design* (JCAMD).

**Systems:** Eltrombopag, Cepharanthine, and Simeprevir  
**Replicates:** Three independent 100 ns simulations per system  
**Energy analysis:** Last 50 ns, sampled every 500 ps, analyzed with gmx_MMPBSA  
**Authors:** [Insert final author list]  
**Associated article:** [Insert final article title]  
**DOI:** `10.xxxx/xxxxx` (placeholder)

## Compound Identifier Mapping

The source calculation uses legacy internal IDs in filenames, script arguments, and result table keys. These IDs are retained in the release package so that published summaries remain traceable to the archived calculations.

| Compound name | Internal calculation ID | Display label for reuse |
| --- | --- | --- |
| Eltrombopag | `drugs2263` | `Eltrombopag (drugs2263)` |
| Cepharanthine | `drugs3003` | `Cepharanthine (drugs3003)` |
| Simeprevir | `drugs3523` | `Simeprevir (drugs3523)` |

## Contents

```text
A35R-MMPBSA-Public/
|-- README.md
|-- REPRODUCIBILITY.md
|-- environment.yml
|-- setup_env.sh
|-- .gitignore
|-- workflow/
|   |-- environment_check/   # dependency/environment scripts
|   |-- prepare_inputs/      # MMPBSA input and index preparation
|   |-- slurm_run_scripts/   # scheduler templates with placeholders
|   |-- debug_scripts/       # troubleshooting job templates
|   |-- collect_parse/       # result parsers
|   |-- visualization/       # figure-generation scripts
|   `-- input_templates/     # execution wrapper template
|-- example_inputs/
|   `-- drugs3003_rep1/     # cepharanthine representative analysis input set
|-- results/
|   |-- summary_delta_fixed/
|   |-- summary_pbradii3/
|   |-- summary_robust/
|   |-- example_drugs3003_rep1/ # cepharanthine example output
|   `-- figure_tables/
`-- figures/
    `-- mmpbsa/              # selected energy summary/decomposition figures
```

`PUBLIC_DIRECTORY_TREE.txt` contains the complete file listing of this release package.

## What Is Included And Omitted

Included materials are executable workflow scripts, MMPBSA control inputs, a representative protein-ligand structural/topological example, summary tables, and selected figures. Path and scheduler values are replaced with portable placeholders including `<PROJECT_ROOT>`, `<PARTITION>`, and `<ACCOUNT>`.

Raw trajectory files (`.xtc`/`.trr`), binary run inputs (`.tpr`), energy/log files, container/path-cache files, and large working intermediates are not distributed through GitHub. The 62 MB per-frame `md_all_timeseries_long.csv` result table is retained for reviewer traceability; repositories enforcing smaller file recommendations may track this table with Git LFS. The source backup did not contain MD `.mdp` files; therefore, this package supports inspection and rerunning of the documented MMPBSA analysis when the required MD inputs are supplied, but it is not a complete independent regeneration archive for the upstream MD simulations.

## Software Environment

Archived execution evidence records the following runtime:

| Component | Recorded version |
| --- | --- |
| gmx_MMPBSA | `v1.5.6` |
| GROMACS | `2021.3-spack` (processing logs); a 2021 build is recorded in MMPBSA logs |
| AmberTools | Amber20 runtime tools |
| Python | `3.9.1` |
| ParmEd | `3.4.3` at MMPBSA runtime |

Create a reconstruction environment with:

```bash
conda env create -f environment.yml
conda activate a35r-mmpbsa
```

The original HPC module/container image and hardware allocation were not retained as an immutable lock file; consult `REPRODUCIBILITY.md` for the evidence boundary.

## Analysis Parameters

| Parameter | Setting |
| --- | --- |
| Calculation type | Single-trajectory MM/GBSA |
| Analysis interval | 50-100 ns of each 100 ns replicate |
| Sampling interval | 500 ps |
| Receptor / ligand groups | `Protein` / `LIG`; `-cg 0 1` |
| GB model | `igb=5` |
| Salt concentration | `saltcon=0.150` M |
| Radii selection in corrected run | `PBRadii=3` |
| Ligand parameterization record | Amber-based topology retaining GAFF2 ligand parameters and assigned charges |

The protein force-field identity and ligand charge-generation method must be confirmed from the upstream system-preparation records before manuscript finalization.

## Run The Documented MMPBSA Analysis

After supplying a compatible `md_100ns.tpr` and trajectory for each system/replicate:

```bash
export PROJECT_ROOT="$PWD"
cd "$PROJECT_ROOT/<run_directory>"

gmx trjconv -s md_100ns.tpr -f md_100ns.xtc \
  -o mmpbsa_50_100_dt500_pbc_mol_center.xtc \
  -b 50000 -e 100000 -dt 500 -pbc mol -center

gmx trjconv -s md_100ns.tpr \
  -f mmpbsa_50_100_dt500_pbc_mol_center.xtc \
  -o mmpbsa_50_100_dt500_fit.xtc -fit rot+trans

gmx_MMPBSA -O \
  -i mmpbsa_gb_prod_pbr3.in \
  -cs md_100ns.tpr \
  -ct mmpbsa_50_100_dt500_fit.xtc \
  -ci mmpbsa_index.ndx \
  -cg 0 1 -cp topol.top \
  -o FINAL_RESULTS_MMPBSA_GB.dat \
  -eo FINAL_RESULTS_MMPBSA_GB.csv -nogui
```

For energy interpretation, read `DELTA_TOTAL` from the `Delta (Complex - Receptor - Ligand)` result section. More negative values indicate more favorable estimated binding under this common protocol.

## Citation

Please cite the associated article when available, together with:

1. Valdes-Tresanco, M. S.; Valdes-Tresanco, M. E.; Valiente, P. A.; Moreno, E. *J. Chem. Theory Comput.* **2021**, *17*, 6281-6291. https://doi.org/10.1021/acs.jctc.1c00645
2. Abraham, M. J.; et al. *SoftwareX* **2015**, *1-2*, 19-25. https://doi.org/10.1016/j.softx.2015.06.001
3. Wang, J.; Wolf, R. M.; Caldwell, J. W.; Kollman, P. A.; Case, D. A. *J. Comput. Chem.* **2004**, *25*, 1157-1174. https://doi.org/10.1002/jcc.20035

