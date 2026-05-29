#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from statistics import mean, stdev

def parse_mmpbsa_dat(path: Path):
    """
    Parse FINAL_RESULTS_MMPBSA_GB.dat.
    Typical lines:
      VDWAALS          -xx.xx     sd     sem
      EEL              -xx.xx     sd     sem
      EGB               xx.xx     sd     sem
      ESURF             xx.xx     sd     sem
      DELTA TOTAL      -xx.xx     sd     sem
    """
    rows = {}
    if not path.exists():
        return rows

    for line in path.read_text(errors="ignore").splitlines():
        s = line.strip()
        if not s:
            continue

        # Match energy term with average, SD, SEM
        # Supports "DELTA TOTAL" as a two-word term.
        m = re.match(
            r"^(DELTA\s+TOTAL|VDWAALS|EEL|EGB|ESURF|GGAS|GSOLV|DELTA\s+G\s+gas|DELTA\s+G\s+solv)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?\s*"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?",
            s
        )
        if m:
            term = re.sub(r"\s+", "_", m.group(1).strip())
            avg = float(m.group(2))
            sd = float(m.group(3)) if m.group(3) is not None else None
            sem = float(m.group(4)) if m.group(4) is not None else None
            rows[term] = {"avg": avg, "sd": sd, "sem": sem}

    return rows

def safe_sd(vals):
    return stdev(vals) if len(vals) >= 2 else 0.0

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    ap.add_argument("--out", default="gmx_mmpbsa_summary_direct")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    systems = ["drugs2263", "drugs3003", "drugs3523"]
    reps = ["rep1", "rep2", "rep3"]

    long_rows = []

    for sysname in systems:
        for rep in reps:
            dat = root / sysname / rep / "FINAL_RESULTS_MMPBSA_GB.dat"
            parsed = parse_mmpbsa_dat(dat)

            if not parsed:
                print(f"[MISS_OR_PARSE_FAIL] {dat}")
                continue

            for term, vals in parsed.items():
                long_rows.append({
                    "system": sysname,
                    "rep": rep,
                    "term": term,
                    "mean_kcal_per_mol": vals["avg"],
                    "sd_kcal_per_mol": vals["sd"],
                    "sem_kcal_per_mol": vals["sem"],
                    "source": str(dat),
                })

    long_csv = out / "mmpbsa_gb_terms_by_rep.csv"
    with long_csv.open("w", newline="") as f:
        fieldnames = [
            "system", "rep", "term",
            "mean_kcal_per_mol", "sd_kcal_per_mol", "sem_kcal_per_mol",
            "source"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(long_rows)

    print(f"[WRITE] {long_csv}")

    # System summary by term across 3 repeats
    summary_rows = []
    by_key = {}

    for row in long_rows:
        key = (row["system"], row["term"])
        by_key.setdefault(key, []).append(float(row["mean_kcal_per_mol"]))

    for (sysname, term), vals in sorted(by_key.items()):
        summary_rows.append({
            "system": sysname,
            "term": term,
            "replicate_mean_kcal_per_mol": mean(vals),
            "replicate_sd_kcal_per_mol": safe_sd(vals),
            "n_reps": len(vals),
        })

    summary_csv = out / "mmpbsa_gb_summary_by_system.csv"
    with summary_csv.open("w", newline="") as f:
        fieldnames = [
            "system", "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"[WRITE] {summary_csv}")

    # Extract DELTA_TOTAL only
    delta_rows = [r for r in summary_rows if r["term"] == "DELTA_TOTAL"]
    delta_csv = out / "mmpbsa_gb_delta_total_summary.csv"
    with delta_csv.open("w", newline="") as f:
        fieldnames = [
            "system", "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps"
        ]
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(delta_rows)

    print(f"[WRITE] {delta_csv}")

    print("\nDELTA_TOTAL summary:")
    for r in delta_rows:
        print(
            f"{r['system']}: "
            f"{r['replicate_mean_kcal_per_mol']:.3f} ± "
            f"{r['replicate_sd_kcal_per_mol']:.3f} kcal/mol "
            f"(n={r['n_reps']})"
        )

if __name__ == "__main__":
    main()
