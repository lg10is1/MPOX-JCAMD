#!/usr/bin/env python3
import argparse
import csv
import math
import re
import statistics
from pathlib import Path

TERMS = [
    "VDWAALS", "EEL",
    "EGB", "EPB",
    "ESURF", "ENPOLAR", "EDISPER",
    "DELTA G gas", "DELTA G solv", "DELTA TOTAL"
]

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

COLORS = {
    "drugs2263": "#4C78A8",
    "drugs3003": "#59A14F",
    "drugs3523": "#E15759",
}

def mean(xs):
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return statistics.mean(xs) if xs else float("nan")

def sd(xs):
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return statistics.stdev(xs) if len(xs) >= 2 else float("nan")

def sem(xs):
    xs = [x for x in xs if x is not None and not math.isnan(x)]
    return statistics.stdev(xs) / math.sqrt(len(xs)) if len(xs) >= 2 else float("nan")

def parse_float_list(line):
    return [float(x) for x in re.findall(r"[-+]?\d+\.\d+(?:[Ee][-+]?\d+)?|[-+]?\d+(?:[Ee][-+]?\d+)", line)]

def detect_model(line, current):
    u = line.upper()
    if "GENERALIZED BORN" in u or "GB" in u and "CALCULATION" in u:
        return "GB"
    if "POISSON BOLTZMANN" in u or "PB" in u and "CALCULATION" in u:
        return "PB"
    return current

def parse_dat(dat_path):
    rows = []
    if not dat_path.exists():
        return rows

    model = "NA"
    in_diff = False

    for raw in dat_path.read_text(errors="ignore").splitlines():
        line = raw.strip()
        if not line:
            continue

        model = detect_model(line, model)
        upper = line.upper()

        if "DIFFERENCES" in upper or "DELTA" in upper and "COMPLEX" in upper and "RECEPTOR" in upper:
            in_diff = True
            continue

        if upper.endswith(":") and any(x in upper for x in ["COMPLEX", "RECEPTOR", "LIGAND"]):
            in_diff = False

        # We mainly want the Differences table.
        if not in_diff:
            continue

        for term in TERMS:
            if upper.startswith(term.upper()):
                nums = parse_float_list(line)
                if nums:
                    rows.append({
                        "model": model,
                        "term": term,
                        "average": nums[0],
                        "sd_prop": nums[1] if len(nums) > 1 else float("nan"),
                        "sd": nums[2] if len(nums) > 2 else float("nan"),
                        "source": str(dat_path)
                    })
                break

    # Fallback: if parser did not catch difference table, parse any DELTA TOTAL-like line.
    if not rows:
        for raw in dat_path.read_text(errors="ignore").splitlines():
            line = raw.strip()
            upper = line.upper()
            model = detect_model(line, model)
            for term in TERMS:
                if upper.startswith(term.upper()):
                    nums = parse_float_list(line)
                    if nums:
                        rows.append({
                            "model": model,
                            "term": term,
                            "average": nums[0],
                            "sd_prop": nums[1] if len(nums) > 1 else float("nan"),
                            "sd": nums[2] if len(nums) > 2 else float("nan"),
                            "source": str(dat_path)
                        })
                    break
    return rows

def write_csv(path, rows, fieldnames):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print(f"[WRITE] {path}")

def collect(root):
    all_rows = []
    for sys in SYSTEMS:
        for rep in REPS:
            d = root / sys / rep

            files = [
                ("GB", d / "FINAL_RESULTS_MMPBSA_GB.dat"),
                ("GB_PB", d / "FINAL_RESULTS_MMPBSA_GB_PB.dat"),
                ("DECOMP_GB", d / "FINAL_RESULTS_MMPBSA_DECOMP_GB.dat"),
                ("TEST", d / "FINAL_RESULTS_MMPBSA_GB_TEST.dat"),
            ]

            for calc, dat in files:
                if not dat.exists():
                    continue
                parsed = parse_dat(dat)
                for r in parsed:
                    r["system"] = sys
                    r["rep"] = rep
                    r["calc"] = calc
                    all_rows.append(r)
    return all_rows

def summarize(rows):
    summary = []
    keys = sorted(set((r["calc"], r["model"], r["system"], r["term"]) for r in rows))
    for calc, model, sys, term in keys:
        vals = [r["average"] for r in rows if r["calc"] == calc and r["model"] == model and r["system"] == sys and r["term"] == term]
        summary.append({
            "calc": calc,
            "model": model,
            "system": sys,
            "term": term,
            "n_reps": len(vals),
            "mean": mean(vals),
            "sd": sd(vals),
            "sem": sem(vals),
            "values": ";".join(f"{v:.6g}" for v in vals)
        })
    return summary

def plot_delta_total(summary, outdir):
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"[WARN] matplotlib not available: {e}")
        return

    plt.rcParams.update({
        "font.family": "Arial",
        "font.size": 8,
        "axes.linewidth": 0.8,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "xtick.major.width": 0.8,
        "ytick.major.width": 0.8,
    })

    for calc in sorted(set(r["calc"] for r in summary)):
        for model in sorted(set(r["model"] for r in summary if r["calc"] == calc)):
            data = []
            labels = []
            colors = []
            for sys in SYSTEMS:
                match = [r for r in summary if r["calc"] == calc and r["model"] == model and r["system"] == sys and r["term"] == "DELTA TOTAL"]
                if not match:
                    continue
                vals = [float(x) for x in match[0]["values"].split(";") if x]
                data.append(vals)
                labels.append(sys)
                colors.append(COLORS.get(sys, "#777777"))

            if not data:
                continue

            fig, ax = plt.subplots(figsize=(3.2, 2.6))
            bp = ax.boxplot(data, patch_artist=True, widths=0.55, showfliers=True)
            for patch, c in zip(bp["boxes"], colors):
                patch.set_facecolor(c)
                patch.set_alpha(0.55)
                patch.set_linewidth(0.8)
            for elem in ["whiskers", "caps", "medians"]:
                for item in bp[elem]:
                    item.set_linewidth(0.8)

            for i, vals in enumerate(data, start=1):
                ax.scatter([i] * len(vals), vals, s=18, zorder=3, color=colors[i-1], edgecolor="black", linewidth=0.3)

            ax.axhline(0, color="black", linewidth=0.6, linestyle="--")
            ax.set_xticklabels(labels, rotation=20, ha="right")
            ax.set_ylabel("Binding free energy, 螖G (kcal/mol)")
            ax.set_title(f"{calc} | {model} | 螖Gbind")
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            fig.tight_layout()
            path = outdir / f"fig_delta_total_{calc}_{model}.pdf"
            fig.savefig(path)
            fig.savefig(path.with_suffix(".png"), dpi=600)
            plt.close(fig)
            print(f"[WRITE] {path}")

def plot_components(summary, outdir):
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"[WARN] matplotlib not available: {e}")
        return

    terms = ["VDWAALS", "EEL", "EGB", "EPB", "ESURF", "ENPOLAR", "EDISPER", "DELTA G gas", "DELTA G solv", "DELTA TOTAL"]

    for calc in sorted(set(r["calc"] for r in summary)):
        for model in sorted(set(r["model"] for r in summary if r["calc"] == calc)):
            available_terms = []
            for t in terms:
                if any(r["calc"] == calc and r["model"] == model and r["term"] == t for r in summary):
                    available_terms.append(t)

            if not available_terms:
                continue

            x = list(range(len(available_terms)))
            width = 0.23

            fig, ax = plt.subplots(figsize=(6.8, 3.0))
            for si, sys in enumerate(SYSTEMS):
                ys = []
                es = []
                for t in available_terms:
                    m = [r for r in summary if r["calc"] == calc and r["model"] == model and r["system"] == sys and r["term"] == t]
                    if m:
                        ys.append(float(m[0]["mean"]))
                        es.append(float(m[0]["sd"]) if m[0]["sd"] == m[0]["sd"] else 0.0)
                    else:
                        ys.append(float("nan"))
                        es.append(0.0)

                xpos = [v + (si - 1) * width for v in x]
                ax.bar(xpos, ys, width=width, yerr=es, capsize=2, label=sys, color=COLORS.get(sys, "#777777"), alpha=0.75, linewidth=0.4, edgecolor="black")

            ax.axhline(0, color="black", linewidth=0.6)
            ax.set_xticks(x)
            ax.set_xticklabels(available_terms, rotation=35, ha="right")
            ax.set_ylabel("Energy component (kcal/mol)")
            ax.set_title(f"{calc} | {model} | MM/PB(GB)SA components")
            ax.legend(frameon=False, fontsize=7)
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            fig.tight_layout()
            path = outdir / f"fig_components_{calc}_{model}.pdf"
            fig.savefig(path)
            fig.savefig(path.with_suffix(".png"), dpi=600)
            plt.close(fig)
            print(f"[WRITE] {path}")

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default="gmx_mmpbsa_50_100ns")
    ap.add_argument("--out", default="gmx_mmpbsa_summary")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    rows = collect(root)
    if not rows:
        print("[ERROR] No gmx_MMPBSA result rows parsed.")
        return

    write_csv(
        outdir / "mmpbsa_replicate_energy_terms.csv",
        rows,
        ["system", "rep", "calc", "model", "term", "average", "sd_prop", "sd", "source"]
    )

    summary = summarize(rows)
    write_csv(
        outdir / "mmpbsa_system_summary.csv",
        summary,
        ["calc", "model", "system", "term", "n_reps", "mean", "sd", "sem", "values"]
    )

    # A reviewer-friendly compact table: DELTA TOTAL only.
    compact = [r for r in summary if r["term"] == "DELTA TOTAL"]
    write_csv(
        outdir / "mmpbsa_delta_total_summary.csv",
        compact,
        ["calc", "model", "system", "term", "n_reps", "mean", "sd", "sem", "values"]
    )

    plot_delta_total(summary, outdir)
    plot_components(summary, outdir)

    print("\n[DONE] Collection finished.")
    print(f"Summary directory: {outdir}")

if __name__ == "__main__":
    main()


