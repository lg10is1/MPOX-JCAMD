# Public Release Audit

Audit date: 2026-05-29

## Package Size

- Files: 488
- Total size: approximately 67.5 MB

## Sensitive-String Scan

The public package was scanned for the following private or environment-specific patterns:

- Internal HPC filesystem roots from the source cluster
- Cluster account/user/group strings
- Compute node or cluster host names
- Local Windows project paths
- Windows user-profile paths
- Email-address patterns

Result: no remaining matches were detected in the public package after sanitization.

## Excluded-Extension Check

The package was checked for raw trajectory, GROMACS binary, topology/coordinate, log, and XVG file classes:

- `.xtc`, `.trr`
- `.tpr`, `.edr`, `.cpt`
- `.gro`, `.top`, `.ndx`, `.itp`
- `.log`, `.xvg`

Result: no files with these extensions were present in the public package.

## Largest Retained Files

The largest retained files are CSV summary tables, not raw trajectories:

| Relative path | Size |
|---|---:|
| `04_summary_tables/gmx_analysis_summary/combined_rmsd_ligand_heavy.csv` | ~5.03 MB |
| `04_summary_tables/gmx_analysis_summary/combined_rmsd_backbone.csv` | ~4.69 MB |
| `04_summary_tables/gmx_analysis_summary/combined_mindist_prot_lig.csv` | ~4.18 MB |
| `04_summary_tables/gmx_analysis_summary/combined_contacts_prot_lig.csv` | ~3.85 MB |
| `04_summary_tables/gmx_analysis_summary/combined_gyrate_protein.csv` | ~3.84 MB |
| `04_summary_tables/gmx_analysis_summary/combined_hbond_prot_lig.csv` | ~3.50 MB |

## Remaining Manual Check Before Deposition

Before uploading to a repository or journal system, visually inspect binary figure files (`.png`, `.pdf`) for institution-specific labels, author names, or unpublished identifiers. The automated text scan cannot fully inspect visible raster content.
