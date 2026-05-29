#!/usr/bin/env python3
import argparse
import csv
import re
from pathlib import Path
from statistics import mean, stdev

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

FLOAT_RE = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?")

TERM_MAP = {
    "VDWAALS": "DELTA_VDWAALS",
    "EEL": "DELTA_EEL",
    "1-4 EEL": "DELTA_1_4_EEL",
    "EGB": "DELTA_EGB",
    "ESURF": "DELTA_ESURF",
    "GGAS": "DELTA_GGAS",
    "GSOLV": "DELTA_GSOLV",
    "TOTAL": "DELTA_TOTAL",
}

def safe_sd(values):
    return stdev(values) if len(values) >= 2 else 0.0

def normalize_line(raw: str) -> str:
    s = raw.strip()
    s = re.sub(r"^\d+:\s*", "", s)      # 兼容 grep -n 输出
    s = s.replace("Δ", "DELTA_")        # ΔTOTAL -> DELTA_TOTAL
    s = s.replace("|", " ")
    s = re.sub(r"\s+", " ", s).strip()
    return s

def parse_delta_section(dat_file: Path):
    """
    只解析 Delta (Complex - Receptor - Ligand) 下面的 Δ 项。
    不解析 Complex/Receptor/Ligand 各自的 TOTAL，避免把绝对能量误认为结合自由能。
    """
    results = {}

    if not dat_file.exists() or dat_file.stat().st_size == 0:
        return results

    lines = dat_file.read_text(errors="ignore").splitlines()
    in_delta = False

    for raw in lines:
        s = normalize_line(raw)
        low = s.lower()

        if "delta (complex - receptor - ligand)" in low:
            in_delta = True
            continue

        if not in_delta:
            continue

        if not s:
            continue

        # 识别类似：
        # DELTA_VDWAALS -26.40 ...
        # DELTA_EEL      86.38 ...
        # DELTA_1-4 EEL   0.00 ...
        # DELTA_TOTAL   -22.13 ...
        m = re.match(
            r"^DELTA_?(VDWAALS|EEL|1-4\s+EEL|EGB|ESURF|GGAS|GSOLV|TOTAL)\s+(.+)$",
            s,
            flags=re.IGNORECASE
        )

        if not m:
            continue

        raw_term = m.group(1).upper()
        raw_term = re.sub(r"\s+", " ", raw_term).strip()
        term = TERM_MAP.get(raw_term)

        if term is None:
            continue

        nums = [float(x) for x in FLOAT_RE.findall(m.group(2))]

        # gmx_MMPBSA 输出列一般是：
        # Average SD(Prop.) SD SEM(Prop.) SEM
        if len(nums) < 1:
            continue

        avg = nums[0]
        sd_prop = nums[1] if len(nums) > 1 else None
        sd = nums[2] if len(nums) > 2 else None
        sem_prop = nums[3] if len(nums) > 3 else None
        sem = nums[4] if len(nums) > 4 else None

        results[term] = {
            "average_kcal_per_mol": avg,
            "sd_prop": sd_prop,
            "sd": sd,
            "sem_prop": sem_prop,
            "sem": sem,
            "source_line": raw.strip(),
        }

    return results

def write_csv(path: Path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    print(f"[WRITE] {path}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    parser.add_argument("--out", default="gmx_mmpbsa_summary_delta_fixed")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    out = Path(args.out).resolve()
    out.mkdir(parents=True, exist_ok=True)

    long_rows = []
    wide_rows = []
    warnings = []

    for system in SYSTEMS:
        for rep in REPS:
            dat = root / system / rep / "FINAL_RESULTS_MMPBSA_GB.dat"
            parsed = parse_delta_section(dat)

            if not parsed:
                warnings.append({
                    "system": system,
                    "rep": rep,
                    "reason": "No delta-section terms parsed",
                    "file": str(dat),
                })
                print(f"[WARN] No delta-section terms parsed: {system} {rep}")
                continue

            if "DELTA_TOTAL" not in parsed:
                warnings.append({
                    "system": system,
                    "rep": rep,
                    "reason": "Delta terms parsed but DELTA_TOTAL missing",
                    "file": str(dat),
                })
                print(f"[WARN] DELTA_TOTAL missing: {system} {rep}")

            wide = {
                "system": system,
                "rep": rep,
                "source_file": str(dat),
            }

            for term, vals in parsed.items():
                long_rows.append({
                    "system": system,
                    "rep": rep,
                    "term": term,
                    "average_kcal_per_mol": vals["average_kcal_per_mol"],
                    "sd_prop": vals["sd_prop"],
                    "sd": vals["sd"],
                    "sem_prop": vals["sem_prop"],
                    "sem": vals["sem"],
                    "source_file": str(dat),
                    "source_line": vals["source_line"],
                })

                wide[f"{term}_avg"] = vals["average_kcal_per_mol"]
                wide[f"{term}_sd"] = vals["sd"]
                wide[f"{term}_sem"] = vals["sem"]

            wide_rows.append(wide)

    long_fields = [
        "system", "rep", "term",
        "average_kcal_per_mol",
        "sd_prop", "sd", "sem_prop", "sem",
        "source_file", "source_line"
    ]

    write_csv(
        out / "mmpbsa_delta_terms_by_rep_long.csv",
        long_rows,
        long_fields
    )

    # wide 表字段自动收集
    wide_fields = ["system", "rep", "source_file"]
    extra_fields = sorted({k for row in wide_rows for k in row.keys() if k not in wide_fields})
    write_csv(
        out / "mmpbsa_delta_terms_by_rep_wide.csv",
        wide_rows,
        wide_fields + extra_fields
    )

    if warnings:
        write_csv(
            out / "mmpbsa_delta_parse_warnings.csv",
            warnings,
            ["system", "rep", "reason", "file"]
        )

    # 按 system 汇总三次重复
    grouped = {}
    for row in long_rows:
        key = (row["system"], row["term"])
        grouped.setdefault(key, []).append(float(row["average_kcal_per_mol"]))

    summary_rows = []
    for (system, term), values in sorted(grouped.items()):
        summary_rows.append({
            "system": system,
            "term": term,
            "replicate_mean_kcal_per_mol": mean(values),
            "replicate_sd_kcal_per_mol": safe_sd(values),
            "n_reps": len(values),
            "rep_values": ";".join(f"{v:.3f}" for v in values),
        })

    write_csv(
        out / "mmpbsa_delta_summary_by_system.csv",
        summary_rows,
        [
            "system",
            "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps",
            "rep_values",
        ]
    )

    delta_total_rows = [r for r in summary_rows if r["term"] == "DELTA_TOTAL"]

    write_csv(
        out / "mmpbsa_delta_total_summary.csv",
        delta_total_rows,
        [
            "system",
            "term",
            "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol",
            "n_reps",
            "rep_values",
        ]
    )

    print()
    print("============================================================")
    print("MM/GBSA ΔTOTAL summary")
    print("============================================================")

    if not delta_total_rows:
        print("[ERROR] Still no DELTA_TOTAL parsed.")
        print("[HINT] Please check whether FINAL_RESULTS_MMPBSA_GB.dat contains ΔTOTAL.")
    else:
        for r in delta_total_rows:
            print(
                f"{r['system']}: "
                f"{r['replicate_mean_kcal_per_mol']:.3f} ± "
                f"{r['replicate_sd_kcal_per_mol']:.3f} kcal/mol "
                f"(n={r['n_reps']}; reps={r['rep_values']})"
            )

if __name__ == "__main__":
    main()
