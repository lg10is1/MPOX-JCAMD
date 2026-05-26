# Reproducibility Record: A35R gmx_MMPBSA Analysis

## Scope

This document records information recoverable from the retained MMPBSA archive. It distinguishes evidenced runtime metadata from items that must be recovered from upstream MD preparation records.

## Recorded Runtime Environment

| Item | Archived evidence |
| --- | --- |
| Analysis software | gmx_MMPBSA `v1.5.6` |
| Trajectory processing | GROMACS `2021.3-spack` in preprocessing logs; gmx_MMPBSA invoked a GROMACS 2021 build labeled `2021-UNCHECKED` |
| Amber tools | Runtime resolved tools from an Amber20 installation |
| Python runtime | Python `3.9.1` |
| ParmEd runtime | `3.4.3` (topology-conversion header additionally reports ParmEd `VERSION4.3.1`) |
| Operating system | Linux x86_64; full host/site identifiers removed from the public package |
| Parallel model | Serial gmx_MMPBSA calculation scripts with scheduler orchestration across 9 jobs |

No CPU model, GPU model, RAM allocation, exact container digest, or software lock file was retained in a publishable form.

## Experimental Design Recoverable From Archive

| Item | Setting |
| --- | --- |
| Targets | A35R complexes with eltrombopag (`drugs2263`), cepharanthine (`drugs3003`), and simeprevir (`drugs3523`) |
| Replication | Three independent trajectories per ligand |
| Simulation length | 100 ns per replicate |
| Analysis window | Last 50 ns (`50000-100000` ps) |
| Sampling | Every 500 ps; approximately 101 snapshots per replicate |
| MMPBSA protocol | Single trajectory; receptor `Protein`, ligand `LIG` |
| GB configuration | `igb=5`, `saltcon=0.150`, corrected analysis with `PBRadii=3` |

The `drugsXXXX` identifiers are preserved in original calculation folder and output names to maintain file-level traceability; manuscript-facing reporting should use the compound names.

## Missing Provenance Required For Full MD Reproduction

The following elements were not demonstrably present in this MMPBSA backup and should be added from the upstream MD preparation archive before final deposition:

| Missing item | Why it matters |
| --- | --- |
| MD `.mdp` files | Define cutoffs, PME, thermostat, barostat, timestep, constraints, output frequencies, and ensemble protocol |
| Explicit protein force-field identity | Required to cite and rebuild the topology |
| Ligand charge derivation method | GAFF2 use is stated, but the charge-generation protocol is not recorded here |
| Starting structure and preparation/protonation record | Needed to independently reconstruct the simulation system |
| Exact environment/container lock or image digest | Required for strict software-level replay |
| Hardware allocation record | Needed when reporting performance or exact compute environment |

## Public Release Controls

The folder `A35R-MMPBSA-Public/` is designed for GitHub publication. It:

- retains sanitized scripts, MMPBSA parameter inputs, a representative lightweight structural example, result summaries, and selected figures;
- removes trajectories (`.xtc`, `.trr`), run inputs (`.tpr`), logs, cached paths, and large simulation working files;
- replaces site-specific absolute paths with `<PROJECT_ROOT>` or relative paths;
- does not retain scheduler account, partition, personal e-mail, node identifier, or private network information.

## Version Confirmation Commands

Run these commands after rebuilding the environment:

```bash
gmx --version
gmx_MMPBSA --version
python --version
python -c "import parmed, numpy, pandas, scipy, matplotlib, seaborn; print(parmed.__version__)"
```

Record the output, the operating system, CPU/GPU hardware, RAM, and any container digest in the final repository release or manuscript supplement.

