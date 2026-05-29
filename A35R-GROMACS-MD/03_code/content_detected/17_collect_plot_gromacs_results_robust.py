#!/usr/bin/env python3
import argparse
import csv
import math
import statistics
from pathlib import Path

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

METRICS = {
    "rmsd_backbone": {
        "csv": "rmsd_backbone.csv",
        "xvg": "rmsd_backbone.xvg",
        "x": "time_ps",
        "y": "rmsd_nm",
        "xlabel": "Time (ns)",
        "ylabel": "Protein backbone RMSD (nm)",
    },
    "rmsd_ligand_heavy": {
        "csv": "rmsd_ligand_heavy.csv",
        "xvg": "rmsd_ligand_heavy.xvg",
        "x": "time_ps",
        "y": "rmsd_nm",
        "xlabel": "Time (ns)",
        "ylabel": "Ligand heavy-atom RMSD (nm)",
    },
    "rmsf_backbone_residue": {
        "csv": "rmsf_backbone_residue.csv",
        "xvg": "rmsf_backbone_residue.xvg",
        "x": "residue_index",
        "y": "rmsf_nm",
        "xlabel": "Residue index",
        "ylabel": "Backbone RMSF (nm)",
    },
    "gyrate_protein": {
        "csv": "gyrate_protein.csv",
        "xvg": "gyrate_protein.xvg",
        "x": "time_ps",
        "y": "rg_nm",
        "xlabel": "Time (ns)",
        "ylabel": "Radius of gyration (nm)",
    },
    "hbond_prot_lig": {
        "csv": "hbond_prot_lig.csv",
        "xvg": "hbond_prot_lig.xvg",
        "x": "time_ps",
        "y": "hbonds",
        "xlabel": "Time (ns)",
        "ylabel": "Protein-ligand hydrogen bonds",
    },
    "mindist_prot_lig": {
        "csv": "mindist_prot_lig.csv",
        "xvg": "mindist_prot_lig.xvg",
        "x": "time_ps",
        "y": "mindist_nm",
        "xlabel": "Time (ns)",
        "ylabel": "Protein-ligand minimum distance (nm)",
    },
    "contacts_prot_lig": {
        "csv": "contacts_prot_lig.csv",
        "xvg": "contacts_prot_lig.xvg",
        "x": "time_ps",
        "y": "contacts",
        "xlabel": "Time (ns)",
        "ylabel": "Protein-ligand contacts",
    },
}

def infer_header(metric, ncols):
    if metric in ["rmsd_backbone", "rmsd_ligand_heavy"]:
        if ncols >= 2:
            return ["time_ps", "rmsd_nm"] + [f"extra_{i}" for i in range(3, ncols + 1)]

    if metric == "rmsf_backbone_residue":
        if ncols >= 2:
            return ["residue_index", "rmsf_nm"] + [f"extra_{i}" for i in range(3, ncols + 1)]

    if metric == "gyrate_protein":
        if ncols == 2:
            return ["time_ps", "rg_nm"]
        if ncols >= 5:
            return ["time_ps", "rg_nm", "rg_x_nm", "rg_y_nm", "rg_z_nm"] + [f"extra_{i}" for i in range(6, ncols + 1)]

    if metric == "hbond_prot_lig":
        if ncols == 2:
            return ["time_ps", "hbonds"]
        if ncols >= 3:
            return ["time_ps", "hbonds", "pairs"] + [f"extra_{i}" for i in range(4, ncols + 1)]

    if metric == "mindist_prot_lig":
        if ncols == 2:
            return ["time_ps", "mindist_nm"]
        if ncols >= 3:
            return ["time_ps", "mindist_nm", "contacts"] + [f"extra_{i}" for i in range(4, ncols + 1)]

    if metric == "contacts_prot_lig":
        if ncols >= 2:
            return ["time_ps", "contacts"] + [f"extra_{i}" for i in range(3, ncols + 1)]

    return [f"col{i}" for i in range(1, ncols + 1)]

def read_xvg(path, metric):
    path = Path(path)
    if not path.exists() or path.stat().st_size == 0:
        return []

    numeric_rows = []
    with path.open(errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith("#") or s.startswith("@"):
                continue
            parts = s.split()
            vals = []
            ok = True
            for p in parts:
                try:
                    vals.append(float(p))
                except ValueError:
                    ok = False
                    break
            if ok and vals:
                numeric_rows.append(vals)

    if not numeric_rows:
        return []

    ncols = max(len(r) for r in numeric_rows)
    numeric_rows = [r for r in numeric_rows if len(r) == ncols]
    header = infer_header(metric, ncols)

    rows = []
    for vals in numeric_rows:
        row = {}
        for h, v in zip(header, vals):
            row[h] = v
        rows.append(row)
    return rows

def read_csv_numeric(path):
    path = Path(path)
    if not path.exists() or path.stat().st_size == 0:
        return []

    rows = []
    with path.open(newline="", errors="ignore") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            return []

        # 去掉重复列名导致的潜在问题
        fieldnames = []
        seen = set()
        for name in reader.fieldnames:
            if name is None:
                continue
            clean = name.strip()
            if clean in seen:
                continue
            seen.add(clean)
            fieldnames.append(clean)

        for raw in reader:
            row = {}
            for k in fieldnames:
                try:
                    row[k] = float(raw.get(k, "nan"))
                except Exception:
                    row[k] = math.nan
            rows.append(row)

    return rows

def read_metric_table(analysis_dir, metric, meta):
    csv_path = analysis_dir / meta["csv"]
    xvg_path = analysis_dir / meta["xvg"]

    rows = read_csv_numeric(csv_path)
    source = csv_path

    if not rows:
        rows = read_xvg(xvg_path, metric)
        source = xvg_path

    return rows, source

def get_series(rows, xkey, ykey):
    xs, ys = [], []
    for r in rows:
        if xkey not in r or ykey not in r:
            continue
        x = r[xkey]
        y = r[ykey]
        if x is None or y is None:
            continue
        if math.isnan(x) or math.isnan(y):
            continue
        if xkey == "time_ps":
            x = x / 1000.0
        xs.append(x)
        ys.append(y)
    return xs, ys

def safe_mean(vals):
    vals = [float(v) for v in vals if not math.isnan(float(v))]
    return statistics.mean(vals) if vals else math.nan

def safe_sd(vals):
    vals = [float(v) for v in vals if not math.isnan(float(v))]
    if len(vals) == 0:
        return math.nan
    if len(vals) == 1:
        return 0.0
    return statistics.stdev(vals)

def summarize_values(ys):
    vals = [float(v) for v in ys if not math.isnan(float(v))]
    if not vals:
        return None
    return {
        "mean": statistics.mean(vals),
        "sd": statistics.stdev(vals) if len(vals) > 1 else 0.0,
        "min": min(vals),
        "max": max(vals),
        "last": vals[-1],
        "n": len(vals),
    }

def write_combined(outdir, metric, combined_rows):
    out = outdir / f"combined_{metric}.csv"
    with out.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["metric", "system", "rep", "x", "y"])
        w.writeheader()
        for r in combined_rows:
            w.writerow(r)
    print(f"[WRITE] {out}")
    return out

def write_summary(outdir, summary_rows):
    out = outdir / "summary_table.csv"
    with out.open("w", newline="") as f:
        fields = ["metric", "system", "rep", "mean", "sd", "min", "max", "last", "n"]
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in summary_rows:
            w.writerow(r)
    print(f"[WRITE] {out}")

def write_group_summary(outdir, summary_rows):
    grouped = {}
    for r in summary_rows:
        key = (r["metric"], r["system"])
        grouped.setdefault(key, []).append(float(r["mean"]))

    out = outdir / "summary_by_system_metric.csv"
    with out.open("w", newline="") as f:
        fields = ["metric", "system", "replicate_mean_mean", "replicate_mean_sd", "n_reps"]
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for (metric, system), vals in sorted(grouped.items()):
            w.writerow({
                "metric": metric,
                "system": system,
                "replicate_mean_mean": safe_mean(vals),
                "replicate_mean_sd": safe_sd(vals),
                "n_reps": len(vals),
            })
    print(f"[WRITE] {out}")

def plot_metric(outdir, metric, meta, all_series):
    try:
        import matplotlib.pyplot as plt
    except Exception as e:
        print(f"[WARN] matplotlib not available, skip plot {metric}: {e}")
        return

    if not all_series:
        return

    fig = plt.figure(figsize=(8.5, 5.2))

    for label, xs, ys in all_series:
        if not xs or not ys:
            continue
        plt.plot(xs, ys, linewidth=0.8, alpha=0.8, label=label)

    plt.xlabel(meta["xlabel"])
    plt.ylabel(meta["ylabel"])
    plt.title(metric)
    plt.legend(fontsize=6, ncol=3)
    plt.tight_layout()

    png = outdir / f"{metric}.png"
    pdf = outdir / f"{metric}.pdf"

    plt.savefig(png, dpi=300)
    plt.savefig(pdf)
    plt.close(fig)

    print(f"[WRITE] {png}")
    print(f"[WRITE] {pdf}")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_md100_3rep")
    parser.add_argument("--out", default="gmx_analysis_summary")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    all_summary_rows = []

    for metric, meta in METRICS.items():
        combined_rows = []
        plot_series = []

        print(f"\n===== Collecting {metric} =====")

        for system in SYSTEMS:
            for rep in REPS:
                analysis_dir = root / system / rep / "analysis"
                rows, source = read_metric_table(analysis_dir, metric, meta)

                if not rows:
                    print(f"[MISS] {source}")
                    continue

                xs, ys = get_series(rows, meta["x"], meta["y"])

                if not xs or not ys:
                    print(f"[WARN] No usable x/y data: {source}")
                    continue

                label = f"{system}_{rep}"
                plot_series.append((label, xs, ys))

                for x, y in zip(xs, ys):
                    combined_rows.append({
                        "metric": metric,
                        "system": system,
                        "rep": rep,
                        "x": x,
                        "y": y,
                    })

                s = summarize_values(ys)
                if s is not None:
                    all_summary_rows.append({
                        "metric": metric,
                        "system": system,
                        "rep": rep,
                        "mean": s["mean"],
                        "sd": s["sd"],
                        "min": s["min"],
                        "max": s["max"],
                        "last": s["last"],
                        "n": s["n"],
                    })

                print(f"[OK] {system} {rep}: {source} n={len(ys)}")

        if combined_rows:
            write_combined(outdir, metric, combined_rows)
            plot_metric(outdir, metric, meta, plot_series)
        else:
            print(f"[WARN] No data for metric: {metric}")

    if all_summary_rows:
        write_summary(outdir, all_summary_rows)
        write_group_summary(outdir, all_summary_rows)
    else:
        print("[WARN] No summary rows generated.")

    print("\n[DONE] Robust collection and plotting finished.")
    print(f"[OUT] {outdir}")

if __name__ == "__main__":
    main()
