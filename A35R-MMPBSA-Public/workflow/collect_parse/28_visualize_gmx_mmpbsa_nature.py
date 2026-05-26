#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import re
import math
from pathlib import Path
from statistics import mean, stdev

import numpy as np
import pandas as pd

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator


SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

# Nature/Okabe-Ito-like muted palette
SYSTEM_COLORS = {
    "drugs2263": "#0072B2",  # muted blue
    "drugs3003": "#D55E00",  # vermillion
    "drugs3523": "#009E73",  # green
}

REP_COLORS = {
    "rep1": "#0072B2",
    "rep2": "#CC79A7",
    "rep3": "#F0E442",
}

REP_LINESTYLES = {
    "rep1": "-",
    "rep2": "--",
    "rep3": "-.",
}

METRICS = {
    "rmsd_backbone": {
        "label": "Protein backbone RMSD",
        "ylabel": "Backbone RMSD (nm)",
        "xlabel": "Time (ns)",
        "kind": "time",
        "patterns": [
            "rmsd_backbone.csv", "rmsd_backbone.xvg",
            "*rmsd*backbone*.csv", "*rmsd*backbone*.xvg",
            "*rmsd*bb*.csv", "*rmsd*bb*.xvg",
        ],
    },
    "rmsd_ligand_heavy": {
        "label": "Ligand heavy-atom RMSD",
        "ylabel": "Ligand RMSD (nm)",
        "xlabel": "Time (ns)",
        "kind": "time",
        "patterns": [
            "rmsd_ligand_heavy.csv", "rmsd_ligand_heavy.xvg",
            "*rmsd*ligand*heavy*.csv", "*rmsd*ligand*heavy*.xvg",
            "*rmsd*lig*.csv", "*rmsd*lig*.xvg",
        ],
    },
    "rmsf_backbone_residue": {
        "label": "Protein backbone RMSF",
        "ylabel": "Backbone RMSF (nm)",
        "xlabel": "Residue index",
        "kind": "residue",
        "patterns": [
            "rmsf_backbone_residue.csv", "rmsf_backbone_residue.xvg",
            "*rmsf*backbone*.csv", "*rmsf*backbone*.xvg",
            "*rmsf*.csv", "*rmsf*.xvg",
        ],
    },
    "gyrate_protein": {
        "label": "Protein radius of gyration",
        "ylabel": "Rg (nm)",
        "xlabel": "Time (ns)",
        "kind": "time",
        "patterns": [
            "gyrate_protein.csv", "gyrate_protein.xvg",
            "*gyrate*protein*.csv", "*gyrate*protein*.xvg",
            "*rg*.csv", "*rg*.xvg",
        ],
    },
    "hbond_prot_lig": {
        "label": "Protein-ligand hydrogen bonds",
        "ylabel": "Number of H-bonds",
        "xlabel": "Time (ns)",
        "kind": "time",
        "patterns": [
            "hbond_prot_lig.csv", "hbond_prot_lig.xvg",
            "*hbond*prot*lig*.csv", "*hbond*prot*lig*.xvg",
            "*hb*.csv", "*hb*.xvg",
        ],
    },
    "mindist_prot_lig": {
        "label": "Protein-ligand minimum distance",
        "ylabel": "Minimum distance (nm)",
        "xlabel": "Time (ns)",
        "kind": "time",
        "patterns": [
            "mindist_prot_lig.csv", "mindist_prot_lig.xvg",
            "*mindist*prot*lig*.csv", "*mindist*prot*lig*.xvg",
            "*minimum*distance*.csv", "*minimum*distance*.xvg",
        ],
    },
    "contacts_prot_lig": {
        "label": "Protein-ligand contacts",
        "ylabel": "Number of contacts",
        "xlabel": "Time (ns)",
        "kind": "time",
        "patterns": [
            "contacts_prot_lig.csv", "contacts_prot_lig.xvg",
            "*contact*prot*lig*.csv", "*contact*prot*lig*.xvg",
            "*contacts*.csv", "*contacts*.xvg",
        ],
    },
}

DELTA_TERMS = [
    "DELTA_VDWAALS",
    "DELTA_EEL",
    "DELTA_EGB",
    "DELTA_ESURF",
    "DELTA_GGAS",
    "DELTA_GSOLV",
    "DELTA_TOTAL",
]

TERM_LABELS = {
    "DELTA_VDWAALS": "螖VDWAALS",
    "DELTA_EEL": "螖EEL",
    "DELTA_EGB": "螖EGB",
    "DELTA_ESURF": "螖ESURF",
    "DELTA_GGAS": "螖GGAS",
    "DELTA_GSOLV": "螖GSOLV",
    "DELTA_TOTAL": "螖TOTAL",
}


def set_nature_style():
    plt.rcParams.update({
        "font.family": "DejaVu Sans",
        "font.size": 8.5,
        "axes.labelsize": 8.5,
        "axes.titlesize": 9.5,
        "xtick.labelsize": 7.5,
        "ytick.labelsize": 7.5,
        "legend.fontsize": 7.5,
        "axes.linewidth": 0.8,
        "xtick.major.width": 0.7,
        "ytick.major.width": 0.7,
        "xtick.major.size": 3,
        "ytick.major.size": 3,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "savefig.dpi": 600,
        "figure.dpi": 150,
    })


def clean_axis(ax):
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.grid(False)
    ax.tick_params(direction="out")


def save_figure(fig, outbase: Path):
    outbase.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(str(outbase.with_suffix(".pdf")), bbox_inches="tight")
    fig.savefig(str(outbase.with_suffix(".png")), bbox_inches="tight", dpi=600)
    fig.savefig(str(outbase.with_suffix(".svg")), bbox_inches="tight")
    plt.close(fig)


def find_metric_file(analysis_dir: Path, metric: str):
    info = METRICS[metric]
    for pat in info["patterns"]:
        matches = sorted(analysis_dir.glob(pat))
        matches = [m for m in matches if m.is_file() and m.stat().st_size > 0]
        if matches:
            return matches[0]
    return None


def read_xvg(path: Path):
    rows = []
    with path.open("r", errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("@"):
                continue
            parts = s.split()
            vals = []
            for p in parts:
                try:
                    vals.append(float(p))
                except ValueError:
                    pass
            if len(vals) >= 2:
                rows.append(vals)
    if not rows:
        return pd.DataFrame()
    maxlen = max(len(r) for r in rows)
    padded = [r + [np.nan] * (maxlen - len(r)) for r in rows]
    cols = [f"col{i}" for i in range(maxlen)]
    return pd.DataFrame(padded, columns=cols)


def read_csv_table(path: Path):
    try:
        df = pd.read_csv(path)
        if df.shape[1] == 1:
            df2 = pd.read_csv(path, sep=r"\s+", comment="#", engine="python")
            if df2.shape[1] > 1:
                df = df2
    except Exception:
        try:
            df = pd.read_csv(path, sep=r"\s+", comment="#", engine="python")
        except Exception:
            return pd.DataFrame()
    df = df.loc[:, ~df.columns.duplicated()]
    return df


def read_numeric_series(path: Path, metric: str, target_ns=100.0):
    if path.suffix.lower() == ".xvg":
        df = read_xvg(path)
    else:
        df = read_csv_table(path)

    if df.empty:
        return pd.DataFrame(columns=["x", "y"])

    numeric_cols = []
    for c in df.columns:
        v = pd.to_numeric(df[c], errors="coerce")
        if v.notna().sum() >= max(2, int(0.5 * len(v))):
            df[c] = v
            numeric_cols.append(c)

    if len(numeric_cols) < 2:
        return pd.DataFrame(columns=["x", "y"])

    lower_cols = {str(c).lower(): c for c in numeric_cols}

    x_col = None
    y_col = None

    if METRICS[metric]["kind"] == "time":
        for key in ["time_ns", "time (ns)", "time", "t", "col0"]:
            if key in lower_cols:
                x_col = lower_cols[key]
                break
    else:
        for key in ["residue", "resid", "residue_index", "residue index", "res", "col0"]:
            if key in lower_cols:
                x_col = lower_cols[key]
                break

    if x_col is None:
        x_col = numeric_cols[0]

    # Prefer value-like columns. Otherwise use the second numeric column.
    for key in [
        "value", "rmsd", "rmsf", "rg", "gyrate",
        "hbonds", "hbond", "hydrogen bonds",
        "mindist", "minimum distance", "contacts", "contact",
        "col1"
    ]:
        if key in lower_cols and lower_cols[key] != x_col:
            y_col = lower_cols[key]
            break

    if y_col is None:
        candidates = [c for c in numeric_cols if c != x_col]
        if not candidates:
            return pd.DataFrame(columns=["x", "y"])
        y_col = candidates[0]

    out = pd.DataFrame({
        "x": pd.to_numeric(df[x_col], errors="coerce"),
        "y": pd.to_numeric(df[y_col], errors="coerce"),
    }).dropna()

    if out.empty:
        return pd.DataFrame(columns=["x", "y"])

    # GROMACS usually outputs time in ps. If x is far above target ns, convert ps to ns.
    if METRICS[metric]["kind"] == "time":
        xmax = float(out["x"].max())
        if xmax > target_ns * 2.5:
            out["x"] = out["x"] / 1000.0

    return out


def collect_md_data(root: Path, target_ns: float):
    records = []
    missing = []

    for sys in SYSTEMS:
        for rep in REPS:
            analysis_dir = root / sys / rep / "analysis"
            if not analysis_dir.exists():
                missing.append((sys, rep, "analysis_dir", str(analysis_dir)))
                continue

            for metric in METRICS:
                f = find_metric_file(analysis_dir, metric)
                if f is None:
                    missing.append((sys, rep, metric, "missing"))
                    continue

                df = read_numeric_series(f, metric, target_ns=target_ns)
                if df.empty:
                    missing.append((sys, rep, metric, f"unreadable:{f}"))
                    continue

                df["system"] = sys
                df["rep"] = rep
                df["metric"] = metric
                df["source_file"] = str(f)
                records.append(df)

    if records:
        all_df = pd.concat(records, ignore_index=True)
    else:
        all_df = pd.DataFrame(columns=["x", "y", "system", "rep", "metric", "source_file"])

    miss_df = pd.DataFrame(missing, columns=["system", "rep", "metric", "status"])
    return all_df, miss_df


def summarize_md(md_df: pd.DataFrame, start_ns: float, end_ns: float):
    rows = []

    if md_df.empty:
        return pd.DataFrame()

    for (sys, rep, metric), sub in md_df.groupby(["system", "rep", "metric"]):
        kind = METRICS[metric]["kind"]
        tmp = sub.copy()

        if kind == "time":
            tmp_win = tmp[(tmp["x"] >= start_ns) & (tmp["x"] <= end_ns)].copy()
            if tmp_win.empty:
                tmp_win = tmp
            x_min = float(tmp_win["x"].min())
            x_max = float(tmp_win["x"].max())
        else:
            tmp_win = tmp
            x_min = float(tmp_win["x"].min())
            x_max = float(tmp_win["x"].max())

        y = tmp_win["y"].astype(float).replace([np.inf, -np.inf], np.nan).dropna()

        if len(y) == 0:
            continue

        rows.append({
            "system": sys,
            "rep": rep,
            "metric": metric,
            "metric_label": METRICS[metric]["label"],
            "mean": float(y.mean()),
            "sd": float(y.std(ddof=1)) if len(y) > 1 else 0.0,
            "median": float(y.median()),
            "min": float(y.min()),
            "max": float(y.max()),
            "n_points": int(len(y)),
            "x_min_used": x_min,
            "x_max_used": x_max,
        })

    rep_summary = pd.DataFrame(rows)

    sys_rows = []
    if not rep_summary.empty:
        for (sys, metric), sub in rep_summary.groupby(["system", "metric"]):
            vals = sub["mean"].astype(float).tolist()
            sys_rows.append({
                "system": sys,
                "metric": metric,
                "metric_label": METRICS[metric]["label"],
                "replicate_mean": float(np.mean(vals)),
                "replicate_sd": float(np.std(vals, ddof=1)) if len(vals) > 1 else 0.0,
                "n_reps": int(len(vals)),
                "rep_values": ";".join([f"{v:.4f}" for v in vals]),
            })

    sys_summary = pd.DataFrame(sys_rows)

    return rep_summary, sys_summary


def plot_md_timeseries(md_df, outdir: Path, start_ns: float, end_ns: float):
    panel_dir = outdir / "figures_pdf" / "md_three_reps_separate_panels"
    single_dir = outdir / "figures_pdf" / "md_each_rep_single_panel"
    png_panel_dir = outdir / "figures_png" / "md_three_reps_separate_panels"
    svg_panel_dir = outdir / "figures_svg" / "md_three_reps_separate_panels"

    for metric, info in METRICS.items():
        metric_df = md_df[md_df["metric"] == metric].copy()
        if metric_df.empty:
            continue

        for sys in SYSTEMS:
            sys_df = metric_df[metric_df["system"] == sys]
            if sys_df.empty:
                continue

            # Three separate panels in one figure
            fig, axes = plt.subplots(1, 3, figsize=(7.2, 2.25), sharey=False)
            for ax, rep in zip(axes, REPS):
                sub = sys_df[sys_df["rep"] == rep].sort_values("x")
                if sub.empty:
                    ax.text(0.5, 0.5, "No data", ha="center", va="center")
                else:
                    ax.plot(
                        sub["x"], sub["y"],
                        color=REP_COLORS[rep],
                        lw=1.15,
                        linestyle=REP_LINESTYLES[rep],
                    )
                    if info["kind"] == "time":
                        ax.axvspan(start_ns, end_ns, color="#BDBDBD", alpha=0.18, lw=0)
                        ax.set_xlim(left=max(0, float(sub["x"].min())))
                    ax.set_title(rep)
                ax.set_xlabel(info["xlabel"])
                if ax is axes[0]:
                    ax.set_ylabel(info["ylabel"])
                clean_axis(ax)

            fig.suptitle(f"{sys} | {info['label']}", y=1.04, fontsize=9.5)
            fig.tight_layout()

            # Save in all formats manually
            panel_base_pdf = panel_dir / f"{metric}_{sys}_three_reps_separate_panels.pdf"
            panel_base_png = png_panel_dir / f"{metric}_{sys}_three_reps_separate_panels.png"
            panel_base_svg = svg_panel_dir / f"{metric}_{sys}_three_reps_separate_panels.svg"
            panel_base_pdf.parent.mkdir(parents=True, exist_ok=True)
            panel_base_png.parent.mkdir(parents=True, exist_ok=True)
            panel_base_svg.parent.mkdir(parents=True, exist_ok=True)
            fig.savefig(panel_base_pdf, bbox_inches="tight")
            fig.savefig(panel_base_png, bbox_inches="tight", dpi=600)
            fig.savefig(panel_base_svg, bbox_inches="tight")
            plt.close(fig)

            # Each rep as independent figure
            for rep in REPS:
                sub = sys_df[sys_df["rep"] == rep].sort_values("x")
                if sub.empty:
                    continue
                fig, ax = plt.subplots(figsize=(3.2, 2.35))
                ax.plot(
                    sub["x"], sub["y"],
                    color=SYSTEM_COLORS[sys],
                    lw=1.25,
                )
                if info["kind"] == "time":
                    ax.axvspan(start_ns, end_ns, color="#BDBDBD", alpha=0.18, lw=0)
                ax.set_title(f"{sys} {rep}")
                ax.set_xlabel(info["xlabel"])
                ax.set_ylabel(info["ylabel"])
                clean_axis(ax)
                fig.tight_layout()

                for fmt_root, suffix in [
                    (outdir / "figures_pdf" / "md_each_rep_single_panel", ".pdf"),
                    (outdir / "figures_png" / "md_each_rep_single_panel", ".png"),
                    (outdir / "figures_svg" / "md_each_rep_single_panel", ".svg"),
                ]:
                    f = fmt_root / sys / rep / f"{metric}_{sys}_{rep}{suffix}"
                    f.parent.mkdir(parents=True, exist_ok=True)
                    if suffix == ".png":
                        fig.savefig(f, bbox_inches="tight", dpi=600)
                    else:
                        fig.savefig(f, bbox_inches="tight")
                plt.close(fig)


def plot_md_summary(sys_summary, rep_summary, outdir: Path):
    if sys_summary.empty:
        return

    for metric, info in METRICS.items():
        sub = sys_summary[sys_summary["metric"] == metric].copy()
        rep_sub = rep_summary[rep_summary["metric"] == metric].copy()
        if sub.empty:
            continue

        fig, ax = plt.subplots(figsize=(3.5, 2.65))
        x = np.arange(len(SYSTEMS))
        means = []
        errs = []
        colors = []
        for sys in SYSTEMS:
            row = sub[sub["system"] == sys]
            if row.empty:
                means.append(np.nan)
                errs.append(0)
            else:
                means.append(float(row["replicate_mean"].iloc[0]))
                errs.append(float(row["replicate_sd"].iloc[0]))
            colors.append(SYSTEM_COLORS[sys])

        ax.bar(
            x, means, yerr=errs, capsize=3,
            color=colors, edgecolor="black", linewidth=0.55,
            alpha=0.88,
        )

        for i, sys in enumerate(SYSTEMS):
            vals = rep_sub[rep_sub["system"] == sys]["mean"].astype(float).values
            if len(vals) > 0:
                jitter = np.linspace(-0.08, 0.08, len(vals))
                ax.scatter(
                    np.full(len(vals), i) + jitter,
                    vals,
                    s=18,
                    color="white",
                    edgecolor="black",
                    linewidth=0.55,
                    zorder=3,
                )

        ax.set_xticks(x)
        ax.set_xticklabels(SYSTEMS, rotation=25, ha="right")
        ax.set_ylabel(info["ylabel"])
        ax.set_title(info["label"])
        clean_axis(ax)
        fig.tight_layout()
        save_figure(fig, outdir / "figures_pdf" / "md_summary_bars" / f"{metric}_summary")


def normalize_line(raw: str) -> str:
    s = raw.strip()
    s = re.sub(r"^\d+:\s*", "", s)
    s = s.replace("螖", "DELTA_")
    s = s.replace("|", " ")
    s = re.sub(r"\s+", " ", s).strip()
    return s


def parse_delta_section(dat_file: Path):
    results = {}
    if not dat_file.exists() or dat_file.stat().st_size == 0:
        return results

    float_re = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[Ee][-+]?\d+)?")
    in_delta = False

    for raw in dat_file.read_text(errors="ignore").splitlines():
        s = normalize_line(raw)
        low = s.lower()

        if "delta (complex - receptor - ligand)" in low:
            in_delta = True
            continue

        if not in_delta:
            continue

        m = re.match(
            r"^DELTA_?(VDWAALS|EEL|1-4\s+EEL|EGB|ESURF|GGAS|GSOLV|TOTAL)\s+(.+)$",
            s,
            flags=re.I,
        )
        if not m:
            continue

        term_raw = m.group(1).upper()
        term_raw = re.sub(r"\s+", " ", term_raw).strip()

        term_map = {
            "VDWAALS": "DELTA_VDWAALS",
            "EEL": "DELTA_EEL",
            "1-4 EEL": "DELTA_1_4_EEL",
            "EGB": "DELTA_EGB",
            "ESURF": "DELTA_ESURF",
            "GGAS": "DELTA_GGAS",
            "GSOLV": "DELTA_GSOLV",
            "TOTAL": "DELTA_TOTAL",
        }

        term = term_map.get(term_raw)
        if term is None:
            continue

        nums = [float(x) for x in float_re.findall(m.group(2))]
        if not nums:
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
            "source_file": str(dat_file),
        }

    return results


def collect_mmpbsa(root: Path, existing_summary_dir: Path):
    long_csv = existing_summary_dir / "mmpbsa_delta_terms_by_rep_long.csv"
    if long_csv.exists() and long_csv.stat().st_size > 0:
        df = pd.read_csv(long_csv)
        if "average_kcal_per_mol" in df.columns:
            return df

    rows = []
    for sys in SYSTEMS:
        for rep in REPS:
            dat = root / sys / rep / "FINAL_RESULTS_MMPBSA_GB.dat"
            parsed = parse_delta_section(dat)
            for term, vals in parsed.items():
                rows.append({
                    "system": sys,
                    "rep": rep,
                    "term": term,
                    "average_kcal_per_mol": vals["average_kcal_per_mol"],
                    "sd": vals["sd"],
                    "sem": vals["sem"],
                    "source_file": vals["source_file"],
                    "source_line": vals["source_line"],
                })

    return pd.DataFrame(rows)


def summarize_mmpbsa(mmpbsa_df: pd.DataFrame):
    rows = []
    if mmpbsa_df.empty:
        return pd.DataFrame()

    for (sys, term), sub in mmpbsa_df.groupby(["system", "term"]):
        vals = pd.to_numeric(sub["average_kcal_per_mol"], errors="coerce").dropna().values
        if len(vals) == 0:
            continue
        rows.append({
            "system": sys,
            "term": term,
            "replicate_mean_kcal_per_mol": float(np.mean(vals)),
            "replicate_sd_kcal_per_mol": float(np.std(vals, ddof=1)) if len(vals) > 1 else 0.0,
            "n_reps": int(len(vals)),
            "rep_values": ";".join([f"{v:.3f}" for v in vals]),
        })
    return pd.DataFrame(rows)


def plot_mmpbsa(mmpbsa_df, mmpbsa_summary, outdir: Path):
    if mmpbsa_df.empty or mmpbsa_summary.empty:
        return

    # 螖TOTAL bar
    delta = mmpbsa_summary[mmpbsa_summary["term"] == "DELTA_TOTAL"].copy()
    delta_rep = mmpbsa_df[mmpbsa_df["term"] == "DELTA_TOTAL"].copy()

    if not delta.empty:
        fig, ax = plt.subplots(figsize=(3.5, 2.65))
        x = np.arange(len(SYSTEMS))

        means = []
        errs = []
        colors = []
        for sys in SYSTEMS:
            row = delta[delta["system"] == sys]
            if row.empty:
                means.append(np.nan)
                errs.append(0)
            else:
                means.append(float(row["replicate_mean_kcal_per_mol"].iloc[0]))
                errs.append(float(row["replicate_sd_kcal_per_mol"].iloc[0]))
            colors.append(SYSTEM_COLORS[sys])

        ax.axhline(0, color="black", lw=0.7)
        ax.bar(
            x, means, yerr=errs, capsize=3,
            color=colors, edgecolor="black", linewidth=0.55, alpha=0.88,
        )

        for i, sys in enumerate(SYSTEMS):
            vals = delta_rep[delta_rep["system"] == sys]["average_kcal_per_mol"].astype(float).values
            if len(vals) > 0:
                jitter = np.linspace(-0.08, 0.08, len(vals))
                ax.scatter(
                    np.full(len(vals), i) + jitter,
                    vals,
                    s=18,
                    color="white",
                    edgecolor="black",
                    linewidth=0.55,
                    zorder=3,
                )

        ax.set_xticks(x)
        ax.set_xticklabels(SYSTEMS, rotation=25, ha="right")
        ax.set_ylabel("MM/GBSA 螖Gbind (kcal/mol)")
        ax.set_title("MM/GBSA binding free energy")
        clean_axis(ax)
        fig.tight_layout()
        save_figure(fig, outdir / "figures_pdf" / "mmpbsa" / "mmpbsa_delta_total_summary")

    # Energy decomposition grouped bars
    terms = [t for t in DELTA_TERMS if t in set(mmpbsa_summary["term"])]
    if terms:
        fig, ax = plt.subplots(figsize=(6.8, 3.0))
        width = 0.23
        x = np.arange(len(terms))

        for i, sys in enumerate(SYSTEMS):
            vals = []
            errs = []
            for term in terms:
                row = mmpbsa_summary[(mmpbsa_summary["system"] == sys) & (mmpbsa_summary["term"] == term)]
                if row.empty:
                    vals.append(np.nan)
                    errs.append(0)
                else:
                    vals.append(float(row["replicate_mean_kcal_per_mol"].iloc[0]))
                    errs.append(float(row["replicate_sd_kcal_per_mol"].iloc[0]))
            ax.bar(
                x + (i - 1) * width,
                vals,
                width=width,
                yerr=errs,
                capsize=2,
                color=SYSTEM_COLORS[sys],
                edgecolor="black",
                linewidth=0.45,
                alpha=0.88,
                label=sys,
            )

        ax.axhline(0, color="black", lw=0.7)
        ax.set_xticks(x)
        ax.set_xticklabels([TERM_LABELS.get(t, t) for t in terms], rotation=35, ha="right")
        ax.set_ylabel("Energy contribution (kcal/mol)")
        ax.set_title("MM/GBSA energy decomposition")
        ax.legend(frameon=False, ncol=3, loc="best")
        clean_axis(ax)
        fig.tight_layout()
        save_figure(fig, outdir / "figures_pdf" / "mmpbsa" / "mmpbsa_energy_decomposition")


def plot_ligand_rmsd_vs_mmpbsa(rep_summary, mmpbsa_df, outdir: Path):
    if rep_summary.empty or mmpbsa_df.empty:
        return

    lig = rep_summary[rep_summary["metric"] == "rmsd_ligand_heavy"].copy()
    dg = mmpbsa_df[mmpbsa_df["term"] == "DELTA_TOTAL"].copy()

    if lig.empty or dg.empty:
        return

    merged = lig.merge(
        dg[["system", "rep", "average_kcal_per_mol"]],
        on=["system", "rep"],
        how="inner",
    )

    if merged.empty:
        return

    fig, ax = plt.subplots(figsize=(3.4, 2.75))
    for sys in SYSTEMS:
        sub = merged[merged["system"] == sys]
        if sub.empty:
            continue
        ax.scatter(
            sub["mean"],
            sub["average_kcal_per_mol"],
            s=38,
            color=SYSTEM_COLORS[sys],
            edgecolor="black",
            linewidth=0.55,
            label=sys,
        )
        for _, r in sub.iterrows():
            ax.text(
                r["mean"],
                r["average_kcal_per_mol"],
                r["rep"].replace("rep", "r"),
                fontsize=6.5,
                ha="left",
                va="bottom",
            )

    ax.axhline(0, color="black", lw=0.7)
    ax.set_xlabel("Ligand heavy-atom RMSD (nm)")
    ax.set_ylabel("MM/GBSA 螖Gbind (kcal/mol)")
    ax.set_title("Pose stability vs binding energy")
    ax.legend(frameon=False, loc="best")
    clean_axis(ax)
    fig.tight_layout()
    save_figure(fig, outdir / "figures_pdf" / "integrated" / "ligand_rmsd_vs_mmpbsa_delta_total")


def write_methods_and_response(outdir: Path, rep_summary, sys_summary, mmpbsa_summary):
    md_table = ""
    if not sys_summary.empty:
        md_table = sys_summary.copy()
        md_table["replicate_mean"] = md_table["replicate_mean"].map(lambda x: f"{x:.4f}")
        md_table["replicate_sd"] = md_table["replicate_sd"].map(lambda x: f"{x:.4f}")
        md_table = md_table[[
            "metric", "system", "replicate_mean", "replicate_sd", "n_reps", "rep_values"
        ]].to_markdown(index=False)

    mmpbsa_table = ""
    if not mmpbsa_summary.empty:
        show = mmpbsa_summary.copy()
        show["replicate_mean_kcal_per_mol"] = show["replicate_mean_kcal_per_mol"].map(lambda x: f"{x:.3f}")
        show["replicate_sd_kcal_per_mol"] = show["replicate_sd_kcal_per_mol"].map(lambda x: f"{x:.3f}")
        mmpbsa_table = show[[
            "term", "system", "replicate_mean_kcal_per_mol",
            "replicate_sd_kcal_per_mol", "n_reps", "rep_values"
        ]].to_markdown(index=False)

    delta_rows = mmpbsa_summary[mmpbsa_summary["term"] == "DELTA_TOTAL"] if not mmpbsa_summary.empty else pd.DataFrame()

    delta_text = []
    if not delta_rows.empty:
        for sys in SYSTEMS:
            row = delta_rows[delta_rows["system"] == sys]
            if not row.empty:
                delta_text.append(
                    f"{sys}: {float(row['replicate_mean_kcal_per_mol'].iloc[0]):.2f} 卤 "
                    f"{float(row['replicate_sd_kcal_per_mol'].iloc[0]):.2f} kcal/mol"
                )
    delta_sentence = "; ".join(delta_text) if delta_text else "MM/GBSA 螖TOTAL values are summarized in the generated table."

    text = f"""# Figure legends, methods text, and reviewer-response draft

## Output directory

All Nature-style figures were saved in:

`{outdir}`

PDF files should be used for manuscript assembly. SVG files can be further edited in Illustrator or Inkscape. PNG files are only for quick checking.

---

## Figure structure

### Figure Sx. MD-based stability assessment of A35R-ligand complexes

Panels include:
1. Protein backbone RMSD: global conformational stability of A35R after ligand binding.
2. Ligand heavy-atom RMSD: stability of the docked binding pose after MD relaxation.
3. Protein backbone RMSF: residue-level flexibility of A35R.
4. Radius of gyration: compactness of the protein structure.
5. Protein-ligand hydrogen bonds: persistence of polar interactions.
6. Protein-ligand minimum distance: whether the ligand remains in close contact with the binding pocket.
7. Protein-ligand contacts: overall contact persistence between ligand and A35R.

For each small molecule, the three independent repeats are shown as separate panels to avoid overplotting.

### Figure Sy. MM/GBSA binding free energy and energy decomposition

The MM/GBSA binding free energy was calculated as:

螖Gbind = Gcomplex 鈭?Greceptor 鈭?Gligand

The plotted 螖TOTAL corresponds to the final MM/GBSA binding free energy. More negative 螖TOTAL values indicate more favorable predicted binding under the same computational protocol. Energy-decomposition terms include 螖VDWAALS, 螖EEL, 螖EGB, 螖ESURF, 螖GGAS, 螖GSOLV, and 螖TOTAL.

---

## MD summary table

{md_table}

---

## MM/GBSA summary table

{mmpbsa_table}

---

## Methods text for manuscript

Molecular dynamics simulations were performed to evaluate the post-docking stability of the A35R-ligand complexes. The three experimentally validated candidate ligands, drugs2263, drugs3003, and drugs3523, were subjected to independent MD simulations after Amber-based system construction and parameterization. The Amber topologies and coordinates were converted into GROMACS-compatible topology and coordinate files while preserving the ligand GAFF2 parameters and assigned charges. Each complex was energy-minimized, equilibrated under NVT and NPT ensembles, and then subjected to 100 ns production MD. For each ligand, three independent replicates were performed using different random seeds. Trajectories were processed with periodic boundary correction, centering, and least-squares fitting before analysis.

Trajectory stability was evaluated using protein backbone RMSD, ligand heavy-atom RMSD, residue-level RMSF, radius of gyration, protein-ligand hydrogen bonds, protein-ligand minimum distance, and protein-ligand contact number. To focus on the equilibrated part of the trajectories, summary statistics were calculated over the selected production window, while full time-series plots were retained for visual inspection.

MM/GBSA binding free-energy estimation was performed using gmx_MMPBSA. For each replicate, frames from the equilibrated trajectory window were extracted and used for MM/GBSA calculation. The receptor and ligand groups were defined as Protein and LIG, respectively. The Generalized Born model was used with physiological salt concentration. The final binding free energy was calculated as 螖Gbind = Gcomplex 鈭?Greceptor 鈭?Gligand, and the total binding free energy was reported as 螖TOTAL. Energy-decomposition terms, including 螖VDWAALS, 螖EEL, 螖EGB, 螖ESURF, 螖GGAS, and 螖GSOLV, were used to interpret the dominant energetic contributions.

---

## Results text for manuscript

To reduce the dependence on docking scores alone, we further evaluated the post-docking stability of the three A35R-ligand complexes using 100 ns GROMACS MD simulations with three independent replicates for each ligand. Overall, all three complexes remained analyzable during the production simulations, supporting the physical stability of the modeled systems. Ligand heavy-atom RMSD provided direct information on whether the original docking pose was retained after MD relaxation. A lower and less variable ligand RMSD indicates a more stable binding pose, whereas persistent protein-ligand contacts and short minimum distances support sustained ligand-pocket association.

The MM/GBSA analysis provided a quantitative post-MD estimate of ligand binding energetics. The current MM/GBSA results indicate the following 螖TOTAL values across replicates: {delta_sentence}. Energy decomposition further separates the binding contribution into van der Waals, electrostatic, polar solvation, nonpolar solvation, gas-phase, and solvation terms. Therefore, the revised analysis no longer relies exclusively on docking scores, but combines docking, SPR validation, MD stability, and MM/GBSA energy estimation to support ligand prioritization.

---

## Response to Reviewer Comment #4

We thank the reviewer for pointing out the limited predictive power of docking scores when used alone. We agree with this concern and have revised the manuscript accordingly. In the revised study, docking scores are no longer treated as stand-alone evidence for biological activity, but only as an initial prioritization criterion. To strengthen the post-docking validation, we added 100 ns molecular dynamics simulations with three independent replicates for each of the three SPR-validated ligands. We analyzed protein backbone RMSD, ligand heavy-atom RMSD, RMSF, radius of gyration, hydrogen-bond persistence, protein-ligand minimum distance, and contact number. In addition, we performed MM/GBSA binding free-energy estimation and energy decomposition using equilibrated MD frames. These additional analyses provide a post-docking refinement layer and allow us to assess whether the docking poses remain stable under dynamic conditions.

Regarding ROC/AUC-based docking validation, we have clarified that a reliable benchmark set of experimentally confirmed A35R actives and decoys is currently unavailable; therefore, a statistically meaningful ROC/AUC analysis was not feasible in this revision. We have added this point as a limitation and avoided overinterpreting docking scores as direct predictors of biological activity.

---

## Response to Reviewer Comment #5

We thank the reviewer for this important question. We have now clarified the treatment of protein protonation in the Methods section. The A35R model was protonated during the Amber-based preparation procedure under standard near-neutral physiological assumptions, and histidine protonation states were retained as assigned during system preparation. The final solvated systems were neutralized with counterions before MD simulation. We have also added a limitation noting that exhaustive pH-dependent alternative protonation-state sampling was not performed, and that future work may examine protonation-state sensitivity once more experimental structural or biochemical data become available.

---

## Response to Reviewer Comment #6

We agree that the original version did not provide sufficient technical detail for reproducing the docking calculations. We have expanded the Methods section to include the protein source, ligand preparation, charge assignment, docking software and version, search-space definition, scoring criterion, post-docking pose selection, and downstream MD/MMGBSA validation. We also clarified that the docking results were used to prioritize candidates for experimental SPR validation and MD-based post-docking assessment, rather than serving as the sole basis for activity prediction.

---

## Response to Reviewer Comment #9

We thank the reviewer for this suggestion. We have added a detailed description of the molecular interactions of the predicted binding poses. In addition to the original docking-pose interaction diagrams, we now report MD-derived interaction stability, including hydrogen-bond counts, protein-ligand minimum distance, and contact persistence. These dynamic descriptors provide a more robust description of ligand-A35R interactions than static docking poses alone.

---

## Response to Reviewer Comment #10

We agree with the reviewer that the previous interaction analysis was mainly descriptive. To address this issue, we added quantitative MD-based stability assessment and MM/GBSA energy decomposition. The revised Results now include ligand heavy-atom RMSD, protein backbone RMSD, RMSF, radius of gyration, hydrogen bonds, minimum distance, contact number, and MM/GBSA 螖TOTAL values. The energy-decomposition analysis further identifies the relative contributions of van der Waals, electrostatic, polar solvation, nonpolar solvation, gas-phase, and solvation terms. We have also revised the wording of the proposed 鈥渄ual binding model鈥?to avoid overstatement and present it as a model supported by docking, SPR validation, MD stability, and MM/GBSA energetics, while acknowledging that further structural or mutagenesis experiments would be needed for definitive mechanistic confirmation.

"""
    out = outdir / "figure_legends_methods_reviewer_response.md"
    out.write_text(text, encoding="utf-8")
    print(f"[WRITE] {out}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--md-root", default="gmx_md100_3rep")
    parser.add_argument("--mmpbsa-root", default="gmx_mmpbsa_50_100ns")
    parser.add_argument("--mmpbsa-summary", default="gmx_mmpbsa_summary_delta_fixed")
    parser.add_argument("--out", default="nature_figures_gmx_mmpbsa")
    parser.add_argument("--start-ns", type=float, default=50.0)
    parser.add_argument("--end-ns", type=float, default=100.0)
    parser.add_argument("--target-ns", type=float, default=100.0)
    args = parser.parse_args()

    set_nature_style()

    md_root = Path(args.md_root).resolve()
    mmpbsa_root = Path(args.mmpbsa_root).resolve()
    mmpbsa_summary_dir = Path(args.mmpbsa_summary).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)
    (outdir / "csv").mkdir(parents=True, exist_ok=True)

    print("============================================================")
    print("[INFO] Nature-style visualization for GROMACS + MM/GBSA")
    print("============================================================")
    print(f"[INFO] md_root={md_root}")
    print(f"[INFO] mmpbsa_root={mmpbsa_root}")
    print(f"[INFO] outdir={outdir}")
    print(f"[INFO] summary window={args.start_ns}-{args.end_ns} ns")

    md_df, miss_df = collect_md_data(md_root, target_ns=args.target_ns)
    md_df.to_csv(outdir / "csv" / "md_all_timeseries_long.csv", index=False)
    miss_df.to_csv(outdir / "csv" / "md_missing_or_unreadable_files.csv", index=False)
    print(f"[WRITE] {outdir / 'csv' / 'md_all_timeseries_long.csv'}")
    print(f"[WRITE] {outdir / 'csv' / 'md_missing_or_unreadable_files.csv'}")

    rep_summary, sys_summary = summarize_md(md_df, args.start_ns, args.end_ns)
    rep_summary.to_csv(outdir / "csv" / "md_summary_by_rep.csv", index=False)
    sys_summary.to_csv(outdir / "csv" / "md_summary_by_system_metric.csv", index=False)
    print(f"[WRITE] {outdir / 'csv' / 'md_summary_by_rep.csv'}")
    print(f"[WRITE] {outdir / 'csv' / 'md_summary_by_system_metric.csv'}")

    plot_md_timeseries(md_df, outdir, args.start_ns, args.end_ns)
    plot_md_summary(sys_summary, rep_summary, outdir)

    mmpbsa_df = collect_mmpbsa(mmpbsa_root, mmpbsa_summary_dir)
    mmpbsa_df.to_csv(outdir / "csv" / "mmpbsa_delta_terms_by_rep_long.csv", index=False)
    print(f"[WRITE] {outdir / 'csv' / 'mmpbsa_delta_terms_by_rep_long.csv'}")

    mmpbsa_summary = summarize_mmpbsa(mmpbsa_df)
    mmpbsa_summary.to_csv(outdir / "csv" / "mmpbsa_delta_summary_by_system.csv", index=False)
    print(f"[WRITE] {outdir / 'csv' / 'mmpbsa_delta_summary_by_system.csv'}")

    delta_total = mmpbsa_summary[mmpbsa_summary["term"] == "DELTA_TOTAL"].copy()
    delta_total.to_csv(outdir / "csv" / "mmpbsa_delta_total_summary.csv", index=False)
    print(f"[WRITE] {outdir / 'csv' / 'mmpbsa_delta_total_summary.csv'}")

    plot_mmpbsa(mmpbsa_df, mmpbsa_summary, outdir)
    plot_ligand_rmsd_vs_mmpbsa(rep_summary, mmpbsa_df, outdir)

    write_methods_and_response(outdir, rep_summary, sys_summary, mmpbsa_summary)

    print("============================================================")
    print("[DONE] Visualization finished")
    print("============================================================")
    print(f"[RESULT] Figures: {outdir}")
    print(f"[RESULT] Methods/response draft: {outdir / 'figure_legends_methods_reviewer_response.md'}")


if __name__ == "__main__":
    main()


