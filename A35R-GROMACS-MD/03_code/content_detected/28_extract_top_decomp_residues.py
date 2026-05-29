#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from collections import defaultdict

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

def parse_decomp_dat(path):
    rows = []
    if not path.exists():
        return rows

    for line in path.read_text(errors="ignore").splitlines():
        s = line.strip()
        if not s:
            continue

        # Heuristic parser for residue decomposition lines.
        # Common terms may include residue identifier followed by internal/vdw/eel/polar/nonpolar/total.
        nums = re.findall(r"[-+]?\d+\.\d+(?:[Ee][-+]?\d+)?|[-+]?\d+(?:[Ee][-+]?\d+)", s)
        if len(nums) < 2:
            continue

        # Try to avoid headers and pure numeric lines.
        if any(h in s.upper() for h in ["TOTAL", "SIDECHAIN", "BACKBONE", "RESIDUE"]):
            pass

        # Typical residue token: A:123:LYS, LYS 123, R:LYS:123, etc.
        tokens = s.split()
        residue = tokens[0]
        # last numeric value is often total contribution; this is a fallback.
        total = float(nums[-1])
        if abs(total) > 10000:
            continue
        rows.append({"residue": residue, "total": total, "line": s})
    return rows

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    ap.add_argument("--out", default="gmx_mmpbsa_summary/top_decomp_residues.csv")
    ap.add_argument("--topn", type=int, default=20)
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.parent.mkdir(parents=True, exist_ok=True)

    all_rows = []
    for sys in SYSTEMS:
        for rep in REPS:
            p = root / sys / rep / "FINAL_DECOMP_MMPBSA_GB.dat"
            parsed = parse_decomp_dat(p)
            for r in parsed:
                r["system"] = sys
                r["rep"] = rep
                r["source"] = str(p)
                all_rows.append(r)

    # This is deliberately conservative because decomp output formats vary.
    # It stores raw lines; manually inspect the top rows before manuscript use.
    all_rows.sort(key=lambda x: x["total"])

    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["system", "rep", "residue", "total", "line", "source"])
        w.writeheader()
        for r in all_rows[: args.topn * 9]:
            w.writerow(r)

    print(f"[WRITE] {out}")
    print("[NOTE] Decomposition output formats vary. Please manually inspect residue labels before final manuscript use.")

if __name__ == "__main__":
    main()
