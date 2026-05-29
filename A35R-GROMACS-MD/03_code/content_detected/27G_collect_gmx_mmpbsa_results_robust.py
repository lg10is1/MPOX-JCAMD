#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from statistics import mean, stdev

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

FLOAT_RE = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?")

TERM_PATTERNS = [
    ("DELTA_TOTAL", re.compile(r"^(DELTA\s+TOTAL)\b", re.I)),
    ("DELTA_G_GAS", re.compile(r"^(DELTA\s+G\s+GAS|GGAS)\b", re.I)),
    ("DELTA_G_SOLV", re.compile(r"^(DELTA\s+G\s+SOLV|GSOLV)\b", re.I)),
    ("VDWAALS", re.compile(r"^(VDWAALS)\b", re.I)),
    ("EEL", re.compile(r"^(EEL)\b", re.I)),
    ("EGB", re.compile(r"^(EGB)\b", re.I)),
    ("EPB", re.compile(r"^(EPB)\b", re.I)),
    ("ESURF", re.compile(r"^(ESURF)\b", re.I)),
    ("ENPOLAR", re.compile(r"^(ENPOLAR)\b", re.I)),
    ("EDISPER", re.compile(r"^(EDISPER)\b", re.I)),
    # Some versions use TOTAL in the Differences/Delta section instead of DELTA TOTAL.
    ("TOTAL_FALLBACK", re.compile(r"^(TOTAL)\b", re.I)),
]

def clean_line(raw: str) -> str:
    s = raw.replace("\ufeff", "")
    s = s.replace("Δ", "DELTA")
    s = s.replace("|", " ")
    s = s.replace(",", " ")
    s = re.sub(r"\s+", " ", s).strip()
    return s

def extract_numbers_after_term(s: str, match_end: int):
    rest = s[match_end:]
    nums = [float(x) for x in FLOAT_RE.findall(rest)]
    return nums

def infer_sd_sem(nums):
    """
    gmx_MMPBSA/MMPBSA.py may output:
      Average SD SEM
    or:
      Average SD(Prop.) SD SEM(Prop.) SEM
    We keep the first number as mean.
    For SD/SEM, we use a conservative fallback.
    """
    if not nums:
        return None, None, None

    avg = nums[0]

    if len(nums) >= 5:
        # Average, SD(Prop.), SD, SEM(Prop.), SEM
        sd = nums[2]
        sem = nums[4]
    elif len(nums) >= 3:
        # Average, SD, SEM
        sd = nums[1]
        sem = nums[2]
    elif len(nums) == 2:
        avg = nums[0]
        sd = nums[1]
        sem = None
    else:
        sd = None
        sem = None

    return avg, sd, sem

def parse_mmpbsa_text_file(path: Path):
    """
    Robustly parse FINAL_RESULTS_MMPBSA_GB.dat or .csv.
    Returns:
      dict term -> {mean, sd, sem, source_line}
    """
    results = {}
    if not path.exists() or path.stat().st_size == 0:
        return results

    in_delta_section = False

    lines = path.read_text(errors="ignore").splitlines()

    for raw in lines:
        s = clean_line(raw)
        if not s:
            continue

        low = s.lower()

        # Track delta/difference section.
        if "differences" in low or "delta complex" in low or "complex - receptor - ligand" in low:
            in_delta_section = True

        # Some files have subsection headings.
        if re.match(r"^(complex|receptor|ligand)\s*:?\s*$", low, re.I):
            in_delta_section = False

        for canonical, pat in TERM_PATTERNS:
            m = pat.match(s)
            if not m:
                continue

            # Avoid parsing TOTAL from Complex/Receptor/Ligand sections.
            if canonical == "TOTAL_FALLBACK":
                if not in_delta_section:
                    continue
                canonical = "DELTA_TOTAL"

            nums = extract_numbers_after_term(s, m.end())
            avg, sd, sem = infer_sd_sem(nums)

            if avg is None:
                continue

            results[canonical] = {
                "mean_kcal_per_mol": avg,
                "sd_kcal_per_mol": sd,
                "sem_kcal_per_mol": sem,
                "source_line": raw.strip(),
                "source_file": str(path),
            }

    return results

def safe_sd(values):
    if len(values) >= 2:
        return stdev(values)
    return 0.0

def write_csv(path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[WRITE] {path}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    parser.add_argument("--out", default="gmx_mmpbsa_summary_robust")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    long_rows = []
    missing_or_failed = []

    for system in SYSTEMS:
        for rep in REPS:
            d = root / system / rep

            dat = d / "FINAL_RESULTS_MMPBSA_GB.dat"
            csv_file = d / "FINAL_RESULTS_MMPBSA_GB.csv"

            parsed = parse_mmpbsa_text_file(dat)

            # If dat parsing fails, try csv.
            if "DELTA_TOTAL" not in parsed and csv_file.exists():
                parsed_csv = parse_mmpbsa_text_file(csv_file)
                # Merge, but prefer dat terms if already parsed.
                for k, v in parsed_csv.items():
                    parsed.setdefault(k, v)

            if not parsed:
                missing_or_failed.append({
                    "system": system,
                    "rep": rep,
                    "reason": "No parsable terms",
                    "dat": str(dat),
                    "csv": str(csv_file),
                })
                print(f"[MISS_OR_PARSE_FAIL] {system} {rep}: {dat}")
                continue

            if "DELTA_TOTAL" not in parsed:
                missing_or_failed.append({
                    "system": system,
                    "rep": rep,
                    "reason": "Terms parsed but DELTA_TOTAL not found",
                    "dat": str(dat),
                    "csv": str(csv_file),
                })
                print(f"[WARN] {system} {rep}: terms parsed but DELTA_TOTAL not found")
                print(f"       parsed terms: {sorted(parsed.keys())}")

            for term, values in parsed.items():
                long_rows.append({
                    "system": system,
                    "rep": rep,
                    "term": term,
                    "mean_kcal_per_mol": values["mean_kcal_per_mol"],
                    "sd_kcal_per_mol": values["sd_kcal_per_mol"],
                    "sem_kcal_per_mol": values["sem_kcal_per_mol"],
                    "source_file": values["source_file"],
                    "source_line": values["source_line"],
                })

    write_csv(
        out / "mmpbsa_gb_terms_by_rep_robust.csv",
        long_rows,
        [
            "system",
            "rep",
            "term",
            "mean_kcal_per_mol",
            "sd_kcal_per_mol",
            "sem_kcal_per_mol",
            "source_file",
            "source_line",
        ],
    )

    if missing_or_failed:
        write_csv(
            out / "mmpbsa_parse_warnings.csv",
            missing_or_failed,
            ["system", "rep", "reason", "dat", "csv"],
        )

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

    write_csv(
        out / "mmpbsa_gb_summary_by_system_robust.csv",
        summary_rows,
        [
            "system",
            "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps",
        ],
    )

    delta_rows = [r for r in summary_rows if r["term"] == "DELTA_TOTAL"]

    write_csv(
        out / "mmpbsa_gb_delta_total_summary_robust.csv",
        delta_rows,
        [
            "system",
            "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps",
        ],
    )

    print()
    print("============================================================")
    print("DELTA_TOTAL summary")
    print("============================================================")

    if not delta_rows:
        print("[WARN] No DELTA_TOTAL rows parsed.")
        print("[HINT] Please inspect one result file with:")
        print("grep -nEi \"VDWAALS|EEL|EGB|ESURF|GGAS|GSOLV|DELTA|TOTAL|Differences|Energy Component\" \\")
        print("  gmx_mmpbsa_50_100ns/drugs3523/rep3/FINAL_RESULTS_MMPBSA_GB.dat | head -n 120")
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
