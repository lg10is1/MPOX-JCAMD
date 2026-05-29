# Sensitive Data Removal and Public-Release Rules

This package was prepared for external sharing from an internal GROMACS backup directory. The original backup was left unchanged. The public package contains sanitized copies only.

## Redacted or Replaced

The following information was replaced with placeholders in text-like files:

| Original class | Public placeholder |
|---|---|
| Local Windows project paths | `<LOCAL_PROJECT_PATH>`, `<LOCAL_GROMACS_BACKUP>`, `<LOCAL_MMPBSA_BACKUP>` |
| HPC user home paths | `<USER_HOME>` |
| HPC software installation paths | `<SOFTWARE_ROOT>` |
| Cluster account/group/user names | `<CLUSTER_ACCOUNT>`, `<GROUP_NAME>`, `<USER_NAME>` |
| Compute node or host names | `<COMPUTE_NODE>`, `<CLUSTER_HOST>` |
| Email addresses | `<EMAIL_REMOVED>` |
| SLURM account/partition/QOS/mail fields | `<REDACTED>` |

## Omitted File Classes

The following original file classes were not copied into the public package:

- `*.xtc`, `*.trr`: raw or processed trajectories.
- `*.tpr`, `*.edr`, `*.cpt`: binary GROMACS run, energy, and checkpoint files.
- `*.gro`, `*.top`, `*.ndx`, `*.itp`: large structural/topology/index files.
- `*.log`: full GROMACS logs with environment details.
- `*.xvg`: raw XVG files that often include command-line and path headers.
- `11_optional_trajectories/`: optional trajectory archive.
- Very large long-format raw time-series tables, where summarized CSV equivalents are already included.

## Retained File Classes

The following were retained after sanitization where needed:

- `.mdp` GROMACS parameter output files.
- `.py`, `.sh`, and `.slurm` analysis and workflow scripts.
- `.csv` and `.tsv` summary/per-replicate analysis tables.
- `.png`, `.pdf`, and sanitized `.svg` figure files.
- `.txt`, `.md`, and `.json` overview, QC, and conversion-report files.

## Audit Notes

The public file list and checksums are in `MANIFEST_PUBLIC.tsv`. Before deposition, run a final text scan for institution-, user-, or path-specific terms required by the target repository. The binary figure files were copied as publication outputs; their filenames and visible labels should also be inspected against journal policy.

