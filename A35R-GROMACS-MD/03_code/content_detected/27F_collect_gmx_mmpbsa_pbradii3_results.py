#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from statistics import mean, stdev

def parse_final_dat(path: Path):
    data = {}
    if not path.exists() or path.stat().st_size == 0:
        return data

    text = path.read_text(errors="ignore").splitlines()

    for line in text:
        s = line.strip()
        if not s:
            continue

        m = re.match(
            r"^(VDWAALS|EEL|EGB|ESURF|GGAS|GSOLV|DELTA\s+TOTAL)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)\s+"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?\s*"
            r"([-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?)?",
            s
        )

        if m:
            term = m.group(1).replace(" ", "_")
            avg = float(m.group(2))
            sd = float(m.group(3)) if m.group(3) is not None else None
            sem = float(m.group(4)) if m.group(4) is not None else None
            data[term] = {
                "mean_kcal_per_mol": avg,
                "sd_kcal_per_mol": sd,
                "sem_kcal_per_mol": sem,
            }

    return data

def safe_sd(values):
    if len(values) >= 2:
        return stdev(values)
    return 0.0

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    parser.add_argument("--out", default="gmx_mmpbsa_summary_pbradii3")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    systems = ["drugs2263", "drugs3003", "drugs3523"]
    reps = ["rep1", "rep2", "rep3"]

    long_rows = []

    for system in systems:
        for rep in reps:
            dat = root / system / rep / "FINAL_RESULTS_MMPBSA_GB.dat"
            parsed = parse_final_dat(dat)

            if not parsed:
                print(f"[MISS_OR_PARSE_FAIL] {dat}")
                continue

            for term, values in parsed.items():
                long_rows.append({
                    "system": system,
                    "rep": rep,
                    "term": term,
                    "mean_kcal_per_mol": values["mean_kcal_per_mol"],
                    "sd_kcal_per_mol": values["sd_kcal_per_mol"],
                    "sem_kcal_per_mol": values["sem_kcal_per_mol"],
                    "source": str(dat),
                })

    long_csv = out / "mmpbsa_gb_terms_by_rep.csv"
    with long_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "system",
                "rep",
                "term",
                "mean_kcal_per_mol",
                "sd_kcal_per_mol",
                "sem_kcal_per_mol",
                "source",
            ],
        )
        writer.writeheader()
        writer.writerows(long_rows)

    print(f"[WRITE] {long_csv}")

    grouped = {}
    for row in long_rows:
        grouped.setdefault((row["system"], row["term"]), []).append(
            float(row["mean_kcal_per_mol"])
        )

    summary_rows = []
    for (system, term), values in sorted(grouped.items()):
        summary_rows.append({
            "system": system,
            "term": term,
            "replicate_mean_kcal_per_mol": mean(values),
            "replicate_sd_kcal_per_mol": safe_sd(values),
            "n_reps": len(values),
        })

    summary_csv = out / "mmpbsa_gb_summary_by_system.csv"
    with summary_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "system",
                "term",
                "replicate_mean_kcal_per_mol",
                "replicate_sd_kcal_per_mol",
                "n_reps",
            ],
        )
        writer.writeheader()
        writer.writerows(summary_rows)

    print(f"[WRITE] {summary_csv}")

    delta_rows = [r for r in summary_rows if r["term"] == "DELTA_TOTAL"]

    delta_csv = out / "mmpbsa_gb_delta_total_summary.csv"
    with delta_csv.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "system",
                "term",
                "replicate_mean_kcal_per_mol",
                "replicate_sd_kcal_per_mol",
                "n_reps",
            ],
        )
        writer.writeheader()
        writer.writerows(delta_rows)

    print(f"[WRITE] {delta_csv}")

    print()
    print("DELTA_TOTAL summary:")
    if not delta_rows:
        print("[WARN] No DELTA_TOTAL rows parsed.")
    else:
        for r in delta_rows:
            print(
                f"{r['system']}: "
                f"{r['replicate_mean_kcal_per_mol']:.3f} ± "
                f"{r['replicate_sd_kcal_per_mol']:.3f} kcal/mol "
                f"(n={r['n_reps']})"
            )

if __name__ == "__main__":
    main()
