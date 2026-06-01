# Docking Data

This directory contains the public AutoDock Vina docking materials for the monkeypox virus target screen.

## Contents

| Path | Description |
|---|---|
| `PDB/` | Receptor PDB files used during docking preparation. |
| `pdbqt/` | Receptor PDBQT files used as AutoDock Vina receptor inputs. |
| `config/` | Per-target AutoDock Vina configuration files defining the search space. |
| `docking_results/` | Packaged docking log archives, one `.zip` file per target. |

## Targets

| Target | PDB | PDBQT | Config | Results archive |
|---|---|---|---|---|
| A20 | `PDB/A20.pdb` | `pdbqt/A20.pdbqt` | `config/configA20.txt` | `docking results/A20.zip` |
| A29L | `PDB/A29L.pdb` | `pdbqt/A29L.pdbqt` | `config/configA29L.txt` | `docking results/A29L.zip` |
| A30L | `PDB/A30L.pdb` | `pdbqt/A30L.pdbqt` | `config/configA30L.txt` | `docking results/A30L.zip` |
| A35R | `PDB/A35R.pdb` | `pdbqt/A35R.pdbqt` | `config/configA35R.txt` | `docking results/A35R.zip` |
| DNA polymerase | `PDB/DNApolymearse.pdb` | `pdbqt/DNA polymerase.pdbqt` | `config/configDNA_polymerase.txt` | `docking results/DNA polymerase.zip` |
| E4R | `PDB/E4R.pdb` | `pdbqt/E4R.pdbqt` | `config/configE4R.txt` | `docking results/E4R.zip` |
| E8L | `PDB/E8L.pdb` | `pdbqt/E8L.pdbqt` | `config/configE8L.txt` | `docking results/E8L.zip` |

The file name `DNApolymearse.pdb` is preserved as archived in the working data.

## Using The Results

Each archive contains the docking log files for one target. To inspect one target locally:

```bash
cd "Docking/docking results"
unzip A35R.zip -d A35R
```

Expanded result folders contain thousands of small log files and are intentionally ignored by Git. The `.zip` archives are the intended public release files.

## Re-running Docking

Use `../autodock_vina.sh` as a command template. Before reuse, replace the placeholder ligand path, output path, target config path, CPU count, and environment name with values appropriate for the local system.
