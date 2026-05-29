# A35R GROMACS MD analysis backup

This folder is a clean backup of GROMACS MD production metadata, trajectory-analysis outputs, summary tables, figures, and scripts.

## Original working directory

```
<PROJECT_ROOT>/gromacs-runs
```

## Backup directory

```
<PROJECT_ROOT>/gromacs-runs-GROMACS-analysis-backup_20260526_134231
```

## Systems

- drugs2263
- drugs3003
- drugs3523

Each system contains three independent 100 ns MD replicates:

- rep1
- rep2
- rep3

## Directory structure

```
00_project_overview/
01_gromacs_input_systems/
02_short_test_results/
03_100ns_md_metadata/
04_100ns_md_logs/
05_100ns_final_structures/
06_per_rep_analysis_outputs/
07_combined_analysis_tables/
08_md_figures/
09_scripts/
10_quality_control/
11_optional_trajectories/
99_manifest/
```

## Main MD analysis metrics

The backup includes:

1. Protein backbone RMSD
2. Ligand heavy-atom RMSD
3. Protein backbone RMSF
4. Radius of gyration
5. Protein-ligand hydrogen bonds
6. Protein-ligand minimum distance
7. Protein-ligand contact number

## Notes on large files

By default, large trajectory files such as `.xtc`, `.trr`, and checkpoint files are not copied.

To create a full backup including trajectories and checkpoints, run:

```bash
COPY_TRAJ=1 COPY_RESTART=1 bash 33_backup_gromacs_md_analysis.sh
```

## Reviewer-facing key folders

- Per-replicate analysis outputs:
  `06_per_rep_analysis_outputs/`

- Combined summary tables:
  `07_combined_analysis_tables/`

- Manuscript-ready MD figures:
  `08_md_figures/`

- Scripts:
  `09_scripts/`

- Integrity report:
  `10_quality_control/gromacs_analysis_backup_integrity_check.txt`

