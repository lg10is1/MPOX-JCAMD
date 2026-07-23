# Docking Data

This directory contains the public AutoDock Vina docking materials for the monkeypox virus target screen.

## Contents

| Path | Description |
|---|---|
| `PDB/` | Receptor PDB files used during docking preparation. |
| `pdbqt/` | Receptor PDBQT files used as AutoDock Vina receptor inputs. |
| `config/` | Per-target AutoDock Vina configuration files defining the search space. |
| `docking grid configuration files/` | Archived duplicate set of the per-target grid configuration files, preserved as organized in the working data. |
| `docking_results/` | Packaged docking log archives, one `.zip` file per target. |
| `compare_docking.py` | Helper script for comparing docking results across targets. |
| `extract_docking.py` | Helper script for extracting scores/poses from docking logs. |
| `find_stable.py` | Helper script for identifying stable docking poses. |

## Targets

| Target | PDB | PDBQT | Config | Results archive |
|---|---|---|---|---|
| A20 | `PDB/A20.pdb` | `pdbqt/A20.pdbqt` | `config/configA20.txt` | `docking_results/A20.zip` |
| A29L | `PDB/A29L.pdb` | `pdbqt/A29L.pdbqt` | `config/configA29L.txt` | `docking_results/A29L.zip` |
| A30L | `PDB/A30L.pdb` | `pdbqt/A30L.pdbqt` | `config/configA30L.txt` | `docking_results/A30L.zip` |
| A35R | `PDB/A35R.pdb` | `pdbqt/A35R.pdbqt` | `config/configA35R.txt` | `docking_results/A35R.zip` |
| DNA polymerase | `PDB/DNApolymearse.pdb` | `pdbqt/DNA polymerase.pdbqt` | `config/configDNA_polymerase.txt` | `docking_results/DNA polymerase.zip` |
| E4R | `PDB/E4R.pdb` | `pdbqt/E4R.pdbqt` | `config/configE4R.txt` | `docking_results/E4R.zip` |
| E8L | `PDB/E8L.pdb` | `pdbqt/E8L.pdbqt` | `config/configE8L.txt` | `docking_results/E8L.zip` |

The file name `DNApolymearse.pdb` is preserved as archived in the working data.

## Using The Results

Each archive contains one AutoDock Vina log file per ligand for one target (6,405-6,406 log files per archive, ligand IDs `drugs1`-`drugs6406`). To inspect one target locally:

```bash
cd Docking/docking_results
unzip A35R.zip -d A35R
```

Expanded result folders contain thousands of small log files and are intentionally ignored by Git. The `.zip` archives are the intended public release files.

## Re-running Docking

Use `../autodock_vina.sh` as a command template. Before reuse, replace the placeholder ligand path, output path, target config path, CPU count, and environment name with values appropriate for the local system.
