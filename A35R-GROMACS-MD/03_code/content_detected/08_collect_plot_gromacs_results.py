#!/usr/bin/env python3
"""
08_collect_plot_gromacs_results.py

Collect GROMACS analysis CSV files from:
  gmx_md100_3rep/${SYS}/${REP}/analysis/

Generate:
  - combined CSV files for each metric
  - summary_table.csv
  - summary_by_system_metric.csv
  - PNG plots

Run:
  python3 08_collect_plot_gromacs_results.py \
    --root gmx_md100_3rep \
    --out gmx_analysis_summary
"""

import argparse
from pathlib import Path
import math
import warnings

import pandas as pd
import matplotlib.pyplot as plt


METRICS = {
    "rmsd_backbone": "rmsd_backbone.csv",
    "rmsd_ligand_heavy": "rmsd_ligand_heavy.csv",
    "rmsf_backbone_residue": "rmsf_backbone_residue.csv",
    "gyrate_protein": "gyrate_protein.csv",
    "hbond_prot_lig": "hbond_prot_lig.csv",
    "mindist_prot_lig": "mindist_prot_lig.csv",
    "contacts_prot_lig": "contacts_prot_lig.csv",
}

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]


def read_csv(path: Path):
    if not path.exists() or path.stat().st_size == 0:
        return None
    try:
        df = pd.read_csv(path)
        if df.empty:
            return None
        return df
    except Exception as e:
        warnings.warn(f"Could not read {path}: {e}")
        return None


def numeric_y_columns(df):
    cols = []
    for c in df.columns:
        if c.lower() in {"time", "time_ns", "time_ps", "residue", "residue_index"}:
            continue
        if pd.api.types.is_numeric_dtype(df[c]):
            cols.append(c)
    return cols


def guess_x_column(df, metric):
    lower = {c.lower(): c for c in df.columns}
    if "time_ns" in lower:
        return lower["time_ns"]
    if "time" in lower:
        return lower["time"]
    if "residue" in lower:
        return lower["residue"]
    if "residue_index" in lower:
        return lower["residue_index"]
    return df.columns[0]


def add_metadata(df, system, rep, metric):
    df = df.copy()
    df.insert(0, "metric", metric)
    df.insert(0, "rep", rep)
    df.insert(0, "system", system)
    return df


def summarize_metric(df, metric):
    ycols = numeric_y_columns(df)
    if not ycols:
        return []
    y = ycols[0]
    x = guess_x_column(df, metric)

    tmp = df[["system", "rep", x, y]].copy()
    tmp[y] = pd.to_numeric(tmp[y], errors="coerce")
    tmp = tmp.dropna(subset=[y])

    rows = []
    for (system, rep), sub in tmp.groupby(["system", "rep"]):
        if sub.empty:
            continue
        if "rmsf" not in metric and pd.api.types.is_numeric_dtype(sub[x]):
            xmax = sub[x].max()
            xmin = sub[x].min()
            cutoff = xmin + 0.5 * (xmax - xmin)
            sub2 = sub[sub[x] >= cutoff]
            if sub2.empty:
                sub2 = sub
        else:
            sub2 = sub

        rows.append({
            "system": system,
            "rep": rep,
            "metric": metric,
            "value_column": y,
            "n": int(sub2[y].shape[0]),
            "mean": float(sub2[y].mean()),
            "std": float(sub2[y].std(ddof=1)) if sub2[y].shape[0] > 1 else float("nan"),
            "min": float(sub2[y].min()),
            "max": float(sub2[y].max()),
            "median": float(sub2[y].median()),
            "final_or_last": float(sub[y].iloc[-1]),
            "summary_window": "second_half_time_series_or_all_residues",
        })
    return rows


def plot_time_series(df, metric, outdir):
    ycols = numeric_y_columns(df)
    if not ycols:
        return
    y = ycols[0]
    x = guess_x_column(df, metric)

    plt.figure(figsize=(8, 5))
    for (system, rep), sub in df.groupby(["system", "rep"]):
        if x not in sub.columns or y not in sub.columns:
            continue
        plt.plot(sub[x], sub[y], linewidth=1.0, alpha=0.85, label=f"{system}-{rep}")
    plt.xlabel(x)
    plt.ylabel(y)
    plt.title(metric)
    plt.legend(fontsize=7, ncol=2)
    plt.tight_layout()
    plt.savefig(outdir / f"{metric}.png", dpi=300)
    plt.close()


def plot_rmsf(df, metric, outdir):
    ycols = numeric_y_columns(df)
    if not ycols:
        return
    y = ycols[0]
    x = guess_x_column(df, metric)

    plt.figure(figsize=(8, 5))
    for (system, rep), sub in df.groupby(["system", "rep"]):
        plt.plot(sub[x], sub[y], linewidth=1.0, alpha=0.85, label=f"{system}-{rep}")
    plt.xlabel(x)
    plt.ylabel(y)
    plt.title(metric)
    plt.legend(fontsize=7, ncol=2)
    plt.tight_layout()
    plt.savefig(outdir / f"{metric}.png", dpi=300)
    plt.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_md100_3rep", help="Root directory containing system/rep folders")
    parser.add_argument("--out", default="gmx_analysis_summary", help="Output summary directory")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    all_summary_rows = []

    for metric, fname in METRICS.items():
        frames = []
        for system in SYSTEMS:
            for rep in REPS:
                path = root / system / rep / "analysis" / fname
                df = read_csv(path)
                if df is None:
                    print(f"[MISS] {path}")
                    continue
                frames.append(add_metadata(df, system, rep, metric))

        if not frames:
            print(f"[WARN] No data for metric: {metric}")
            continue

        combined = pd.concat(frames, ignore_index=True)
        combined_path = outdir / f"combined_{metric}.csv"
        combined.to_csv(combined_path, index=False)
        print(f"[WRITE] {combined_path}")

        all_summary_rows.extend(summarize_metric(combined, metric))

        if "rmsf" in metric:
            plot_rmsf(combined, metric, outdir)
        else:
            plot_time_series(combined, metric, outdir)

    if all_summary_rows:
        summary = pd.DataFrame(all_summary_rows)
        summary.to_csv(outdir / "summary_table.csv", index=False)

        grouped = (
            summary.groupby(["system", "metric"], as_index=False)
            .agg(
                rep_mean=("mean", "mean"),
                rep_sd=("mean", "std"),
                rep_n=("mean", "count"),
                final_mean=("final_or_last", "mean"),
                final_sd=("final_or_last", "std"),
            )
        )
        grouped.to_csv(outdir / "summary_by_system_metric.csv", index=False)

        print(f"[WRITE] {outdir / 'summary_table.csv'}")
        print(f"[WRITE] {outdir / 'summary_by_system_metric.csv'}")
    else:
        print("[WARN] No summary rows generated.")

    print("[DONE] Collection and plotting finished.")


if __name__ == "__main__":
    main()

