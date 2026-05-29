#!/usr/bin/env python3
import sys
import csv
from pathlib import Path

def infer_header(name, ncols):
    stem = Path(name).stem

    if stem == "rmsd_backbone":
        return ["time_ps", "rmsd_nm"] if ncols == 2 else [f"col{i+1}" for i in range(ncols)]

    if stem == "rmsd_ligand_heavy":
        return ["time_ps", "rmsd_nm"] if ncols == 2 else [f"col{i+1}" for i in range(ncols)]

    if stem == "rmsf_backbone_residue":
        return ["residue_index", "rmsf_nm"] if ncols == 2 else [f"col{i+1}" for i in range(ncols)]

    if stem == "gyrate_protein":
        if ncols == 2:
            return ["time_ps", "rg_nm"]
        if ncols == 5:
            return ["time_ps", "rg_nm", "rg_x_nm", "rg_y_nm", "rg_z_nm"]
        return [f"col{i+1}" for i in range(ncols)]

    if stem == "hbond_prot_lig":
        if ncols == 2:
            return ["time_ps", "hbonds"]
        if ncols == 3:
            return ["time_ps", "hbonds", "pairs"]
        return [f"col{i+1}" for i in range(ncols)]

    if stem == "mindist_prot_lig":
        if ncols == 2:
            return ["time_ps", "mindist_nm"]
        if ncols == 3:
            return ["time_ps", "mindist_nm", "contacts"]
        return [f"col{i+1}" for i in range(ncols)]

    if stem == "contacts_prot_lig":
        if ncols == 2:
            return ["time_ps", "contacts"]
        return [f"col{i+1}" for i in range(ncols)]

    return [f"col{i+1}" for i in range(ncols)]

def convert_one(xvg_path):
    xvg = Path(xvg_path)
    csv_path = xvg.with_suffix(".csv")

    rows = []
    with xvg.open(errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith("#") or s.startswith("@"):
                continue
            parts = s.split()
            try:
                vals = [float(x) for x in parts]
            except ValueError:
                continue
            rows.append(vals)

    if not rows:
        print(f"[WARN] No numeric data: {xvg}")
        return False

    ncols = max(len(r) for r in rows)
    rows = [r for r in rows if len(r) == ncols]
    header = infer_header(xvg.name, ncols)

    with csv_path.open("w", newline="") as out:
        w = csv.writer(out)
        w.writerow(header)
        w.writerows(rows)

    print(f"[OK] {xvg} -> {csv_path} rows={len(rows)} cols={ncols}")
    return True

def main():
    if len(sys.argv) < 2:
        print("Usage: python scripts_convert_xvg_to_csv.py file1.xvg file2.xvg ...")
        sys.exit(1)

    ok = 0
    fail = 0

    for p in sys.argv[1:]:
        if convert_one(p):
            ok += 1
        else:
            fail += 1

    print(f"[DONE] converted={ok}, failed_or_empty={fail}")

if __name__ == "__main__":
    main()
