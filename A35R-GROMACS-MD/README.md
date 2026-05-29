# A35R GROMACS MD Public Code and Results Package

This folder is a sanitized public-release package prepared from the archived A35R GROMACS molecular dynamics analysis. It is intended for journal submission, reviewer inspection, and reproducibility support. Private filesystem paths, cluster account details, node names, and scheduler account fields have been replaced with placeholders.

Generated on: 2026-05-29

## Systems

| Internal ID | Compound | Replicates | Production MD |
|---|---|---:|---:|
| `drugs2263` | Eltrombopag | 3 | 100 ns each |
| `drugs3003` | Cepharanthine | 3 | 100 ns each |
| `drugs3523` | Simeprevir | 3 | 100 ns each |

## Folder Layout

| Folder | Contents |
|---|---|
| `01_overview/` | Sanitized project summaries and figure/method notes from the analysis archive. |
| `02_parameters/` | GROMACS `.mdp` output parameter files and AMBER-to-GROMACS conversion reports. |
| `03_code/` | Sanitized shell, SLURM, and Python scripts used for conversion checks, MD execution, progress checks, analysis, and figure generation. |
| `04_summary_tables/` | Combined CSV/TSV tables used for summary statistics and plotting. Very large raw long-format time series were omitted. |
| `05_per_replicate_csv/` | Per-system/per-replicate CSV outputs exported from the GROMACS analyses. |
| `06_figures/` | Publication-style figures in PNG, PDF, and SVG formats. |
| `07_quality_control/` | Sanitized quality-control and integrity-check text records. |
| `99_original_manifest_sanitized/` | Sanitized manifest files from the original archive. |
| `MANIFEST_PUBLIC.tsv` | Public file manifest with size and SHA256 checksums. |
| `EXCLUDED_RAW_FILES.txt` | Explicit list of raw/binary file classes omitted from the public package. |

## What Was Included

- MD execution and analysis scripts after path/account sanitization.
- GROMACS parameter files for the short tests and 100 ns production runs.
- Summary tables and per-replicate CSV analysis outputs.
- Final plotting outputs used for manuscript/reviewer-facing figures.
- Sanitized QC and manifest records.

## What Was Excluded

The original backup contained very large and environment-specific files. The following classes were intentionally excluded from this public code/results package:

- Raw and processed trajectories: `*.xtc`, `*.trr`
- Binary run inputs and energy/checkpoint files: `*.tpr`, `*.edr`, `*.cpt`
- Large coordinate/topology/index files: `*.gro`, `*.top`, `*.ndx`, `*.itp`
- Full GROMACS logs: `*.log`
- Raw XVG files with command/path headers: `*.xvg`
- Optional trajectory archive folder: `11_optional_trajectories/`

These files are not needed to inspect the released code, parameter settings, summary statistics, or figure-generation outputs. They should be archived separately if the journal or repository requires raw trajectory deposition.

## Software Notes

The archived runs used GROMACS 2021.3 on an HPC SLURM environment. Python plotting/collection scripts use the standard library plus packages such as `numpy`, `pandas`, and `matplotlib`; conversion helper scripts may require `ParmEd`.

Example local setup for inspecting or rerunning the Python plotting scripts:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install numpy pandas matplotlib parmed
```

Most SLURM scripts contain placeholders such as `<PROJECT_ROOT>`, `<REDACTED>`, and `<SOFTWARE_ROOT>`. Replace these with your own project path, partition/account settings, module names, and GROMACS executable before rerunning on a different cluster.

## Important Interpretation Note

The archived ligand RMSD values should be treated carefully. The original ligand RMSD workflow appears to fit the ligand to itself, so those values mainly describe ligand internal conformational fluctuation. For statements about binding-pose retention relative to the protein pocket, recalculate ligand-heavy-atom RMSD after fitting the protein backbone or binding-site protein atoms, then measuring the ligand displacement in that protein-fitted frame.

## Main Documentation

- `METHODS_MD.md`: manuscript-ready MD methods and analysis description.
- `SENSITIVE_DATA_REMOVAL.md`: details of the sanitization and exclusion rules.
- `MANIFEST_PUBLIC.tsv`: complete public-file checksum manifest.

