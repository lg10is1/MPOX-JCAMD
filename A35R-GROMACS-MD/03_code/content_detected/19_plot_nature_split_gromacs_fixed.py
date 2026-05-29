#!/usr/bin/env python3
import argparse
import csv
import math
import statistics
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.ticker import MaxNLocator

SYSTEMS = ["drugs2263", "drugs3003", "drugs3523"]
REPS = ["rep1", "rep2", "rep3"]

SYSTEM_COLORS = {
    "drugs2263": "#3B6EA8",
    "drugs3003": "#2F8F6B",
    "drugs3523": "#C65A2E",
}

METRICS = {
    "rmsd_backbone": {
        "csv": "rmsd_backbone.csv",
        "xvg": "rmsd_backbone.xvg",
        "x_label": "Time (ns)",
        "y_label": "Backbone RMSD (nm)",
        "title": "Protein backbone RMSD",
        "x_type": "time",
        "description": "Protein backbone RMSD reflects the global conformational deviation of A35R during MD.",
    },
    "rmsd_ligand_heavy": {
        "csv": "rmsd_ligand_heavy.csv",
        "xvg": "rmsd_ligand_heavy.xvg",
        "x_label": "Time (ns)",
        "y_label": "Ligand RMSD (nm)",
        "title": "Ligand heavy-atom RMSD",
        "x_type": "time",
        "description": "Ligand heavy-atom RMSD reflects the stability of the docking-derived ligand pose after protein alignment.",
    },
    "rmsf_backbone_residue": {
        "csv": "rmsf_backbone_residue.csv",
        "xvg": "rmsf_backbone_residue.xvg",
        "x_label": "Residue index",
        "y_label": "Backbone RMSF (nm)",
        "title": "Protein backbone RMSF",
        "x_type": "residue",
        "description": "Backbone RMSF reflects residue-level flexibility of A35R.",
    },
    "gyrate_protein": {
        "csv": "gyrate_protein.csv",
        "xvg": "gyrate_protein.xvg",
        "x_label": "Time (ns)",
        "y_label": "Rg (nm)",
        "title": "Protein radius of gyration",
        "x_type": "time",
        "description": "Radius of gyration reflects the compactness of the A35R structure.",
    },
    "hbond_prot_lig": {
        "csv": "hbond_prot_lig.csv",
        "xvg": "hbond_prot_lig.xvg",
        "x_label": "Time (ns)",
        "y_label": "Hydrogen bonds",
        "title": "Protein-ligand hydrogen bonds",
        "x_type": "time",
        "description": "Hydrogen-bond number reflects directional polar interactions between A35R and the ligand.",
    },
    "mindist_prot_lig": {
        "csv": "mindist_prot_lig.csv",
        "xvg": "mindist_prot_lig.xvg",
        "x_label": "Time (ns)",
        "y_label": "Minimum distance (nm)",
        "title": "Protein-ligand minimum distance",
        "x_type": "time",
        "description": "Minimum distance reflects whether the ligand remains associated with the protein.",
    },
    "contacts_prot_lig": {
        "csv": "contacts_prot_lig.csv",
        "xvg": "contacts_prot_lig.xvg",
        "x_label": "Time (ns)",
        "y_label": "Contacts",
        "title": "Protein-ligand contacts",
        "x_type": "time",
        "description": "Contact number reflects the extent of close nonbonded protein-ligand interactions.",
    },
}

def setup_style():
    plt.rcParams.update({
        "font.family": "DejaVu Sans",
        "font.size": 7,
        "axes.labelsize": 8,
        "axes.titlesize": 8,
        "xtick.labelsize": 7,
        "ytick.labelsize": 7,
        "legend.fontsize": 6,
        "axes.linewidth": 0.8,
        "xtick.major.width": 0.7,
        "ytick.major.width": 0.7,
        "xtick.major.size": 3,
        "ytick.major.size": 3,
        "pdf.fonttype": 42,
        "ps.fonttype": 42,
        "svg.fonttype": "none",
        "savefig.dpi": 600,
        "figure.dpi": 300,
    })

def mm_to_inch(mm):
    return mm / 25.4

def read_xvg(path):
    path = Path(path)
    rows = []
    if not path.exists() or path.stat().st_size == 0:
        return rows

    with path.open(errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("@"):
                continue
            parts = s.split()
            try:
                vals = [float(x) for x in parts]
            except Exception:
                continue
            if len(vals) >= 2:
                rows.append(vals)
    return rows

def read_csv_numeric(path):
    path = Path(path)
    rows = []
    if not path.exists() or path.stat().st_size == 0:
        return rows

    with path.open(newline="", errors="ignore") as f:
        reader = csv.reader(f)
        all_rows = list(reader)

    if not all_rows:
        return rows

    start = 0
    try:
        [float(x) for x in all_rows[0]]
    except Exception:
        start = 1

    for r in all_rows[start:]:
        if len(r) < 2:
            continue
        try:
            vals = [float(x) for x in r]
        except Exception:
            continue
        rows.append(vals)

    return rows

def auto_time_to_ns(xs_raw):
    """
    GROMACS xvg may be in ps or ns depending on -tu option.
    If max time is >1000, interpret as ps and convert to ns.
    If max time is <=200, interpret as already ns.
    """
    vals = [x for x in xs_raw if math.isfinite(x)]
    if not vals:
        return xs_raw, "unknown"

    xmax = max(vals)

    if xmax > 1000:
        return [x / 1000.0 for x in xs_raw], "ps_to_ns"
    else:
        return xs_raw[:], "already_ns"

def load_series(root, system, rep, metric):
    meta = METRICS[metric]
    analysis = root / system / rep / "analysis"

    csv_path = analysis / meta["csv"]
    xvg_path = analysis / meta["xvg"]

    rows = read_csv_numeric(csv_path)
    source = csv_path

    if not rows:
        rows = read_xvg(xvg_path)
        source = xvg_path

    if not rows:
        return [], [], source, "no_data"

    xs_raw = []
    ys = []

    for vals in rows:
        if len(vals) < 2:
            continue
        xs_raw.append(vals[0])
        ys.append(vals[1])

    if meta["x_type"] == "time":
        xs, unit_mode = auto_time_to_ns(xs_raw)
    else:
        xs = xs_raw
        unit_mode = "residue_index"

    return xs, ys, source, unit_mode

def finite(vals):
    return [v for v in vals if v is not None and math.isfinite(v)]

def rolling_mean(ys, window):
    n = len(ys)
    if n == 0:
        return []
    if window <= 1:
        return ys[:]
    window = min(window, n)
    if window % 2 == 0:
        window -= 1
    if window < 3:
        return ys[:]

    half = window // 2
    out = []

    for i in range(n):
        lo = max(0, i - half)
        hi = min(n, i + half + 1)
        sub = finite(ys[lo:hi])
        out.append(statistics.mean(sub) if sub else math.nan)

    return out

def compute_ylim(all_y, metric):
    vals = finite(all_y)
    if not vals:
        return None

    ymin = min(vals)
    ymax = max(vals)

    if metric in ["hbond_prot_lig", "contacts_prot_lig"]:
        ymin = 0
        pad = max(0.5, ymax * 0.15)
        return ymin, ymax + pad

    pad = (ymax - ymin) * 0.12 if ymax > ymin else max(0.1, abs(ymax) * 0.1)
    return max(0, ymin - pad), ymax + pad

def format_axis(ax, metric, xlim=None, ylim=None):
    meta = METRICS[metric]

    ax.set_xlabel(meta["x_label"])
    ax.set_ylabel(meta["y_label"])

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    ax.tick_params(direction="out", length=3, width=0.7)

    if meta["x_type"] == "time":
        ax.set_xlim(0, 100 if xlim is None else xlim[1])
        ax.xaxis.set_major_locator(MaxNLocator(6))
    else:
        if xlim is not None:
            ax.set_xlim(xlim)
        ax.xaxis.set_major_locator(MaxNLocator(6, integer=True))

    if ylim is not None:
        ax.set_ylim(ylim)

    if metric in ["hbond_prot_lig", "contacts_prot_lig"]:
        ax.yaxis.set_major_locator(MaxNLocator(integer=True))

def save_all(fig, prefix):
    prefix = Path(prefix)
    prefix.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(prefix.with_suffix(".png"), dpi=600, bbox_inches="tight")
    fig.savefig(prefix.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(prefix.with_suffix(".svg"), bbox_inches="tight")
    plt.close(fig)

def summarize(xs, ys, metric):
    vals = finite(ys)
    if not vals:
        return {}

    d = {
        "mean_all": statistics.mean(vals),
        "sd_all": statistics.stdev(vals) if len(vals) > 1 else 0.0,
        "min_all": min(vals),
        "max_all": max(vals),
        "last": vals[-1],
        "n": len(vals),
    }

    if METRICS[metric]["x_type"] == "time":
        last50 = [y for x, y in zip(xs, ys) if x >= 50]
        last50 = finite(last50)
        if last50:
            d["mean_50_100ns"] = statistics.mean(last50)
            d["sd_50_100ns"] = statistics.stdev(last50) if len(last50) > 1 else 0.0
            d["n_50_100ns"] = len(last50)
        else:
            d["mean_50_100ns"] = ""
            d["sd_50_100ns"] = ""
            d["n_50_100ns"] = 0
    else:
        d["mean_50_100ns"] = ""
        d["sd_50_100ns"] = ""
        d["n_50_100ns"] = 0

    return d

def plot_single(root, outdir, system, rep, metric, smooth_window):
    xs, ys, source, unit_mode = load_series(root, system, rep, metric)

    if not xs or not ys:
        print(f"[MISS] {system} {rep} {metric}: {source}")
        return None

    color = SYSTEM_COLORS[system]
    meta = METRICS[metric]

    fig, ax = plt.subplots(figsize=(mm_to_inch(89), mm_to_inch(62)))

    ylim = compute_ylim(ys, metric)

    if meta["x_type"] == "time":
        y_smooth = rolling_mean(ys, smooth_window)
        ax.plot(xs, ys, color=color, alpha=0.25, linewidth=0.45)
        ax.plot(xs, y_smooth, color=color, alpha=1.0, linewidth=1.25)
    else:
        ax.plot(xs, ys, color=color, linewidth=1.15)

    ax.set_title(f"{meta['title']} | {system} {rep}", pad=4)
    format_axis(ax, metric, ylim=ylim)

    fig.tight_layout()

    prefix = outdir / "per_replicate" / system / rep / f"{metric}_{system}_{rep}"
    save_all(fig, prefix)

    stat = summarize(xs, ys, metric)
    stat.update({
        "metric": metric,
        "system": system,
        "rep": rep,
        "source": str(source),
        "time_unit_mode": unit_mode,
        "x_min": min(xs),
        "x_max": max(xs),
        "figure_png": str(prefix.with_suffix(".png")),
        "figure_pdf": str(prefix.with_suffix(".pdf")),
        "figure_svg": str(prefix.with_suffix(".svg")),
    })

    return stat

def plot_panel(root, outdir, system, metric, smooth_window):
    meta = METRICS[metric]
    color = SYSTEM_COLORS[system]

    data = []
    all_y = []
    all_x = []

    for rep in REPS:
        xs, ys, source, unit_mode = load_series(root, system, rep, metric)
        if xs and ys:
            data.append((rep, xs, ys, source, unit_mode))
            all_y.extend(ys)
            all_x.extend(xs)

    if not data:
        return None

    ylim = compute_ylim(all_y, metric)

    if meta["x_type"] == "time":
        xlim = (0, 100)
    else:
        xlim = (min(all_x), max(all_x)) if all_x else None

    fig, axes = plt.subplots(
        nrows=len(data),
        ncols=1,
        figsize=(mm_to_inch(95), mm_to_inch(43 * len(data))),
        sharex=(meta["x_type"] == "time"),
        sharey=True,
    )

    if len(data) == 1:
        axes = [axes]

    for ax, (rep, xs, ys, source, unit_mode) in zip(axes, data):
        if meta["x_type"] == "time":
            y_smooth = rolling_mean(ys, smooth_window)
            ax.plot(xs, ys, color=color, alpha=0.25, linewidth=0.45)
            ax.plot(xs, y_smooth, color=color, alpha=1.0, linewidth=1.2)
        else:
            ax.plot(xs, ys, color=color, linewidth=1.1)

        ax.text(
            0.02, 0.86,
            f"{rep}",
            transform=ax.transAxes,
            ha="left",
            va="top",
            fontsize=7.5,
            fontweight="bold",
        )

        ax.text(
            0.98, 0.86,
            unit_mode,
            transform=ax.transAxes,
            ha="right",
            va="top",
            fontsize=5.5,
            color="0.35",
        )

        format_axis(ax, metric, xlim=xlim, ylim=ylim)
        ax.set_title("")

    axes[0].set_title(f"{meta['title']} | {system}", pad=4)

    fig.tight_layout(h_pad=1.0)

    prefix = outdir / "per_system_three_reps_panel" / system / f"{metric}_{system}_three_reps_separate_panels"
    save_all(fig, prefix)

    return {
        "metric": metric,
        "system": system,
        "figure_png": str(prefix.with_suffix(".png")),
        "figure_pdf": str(prefix.with_suffix(".pdf")),
        "figure_svg": str(prefix.with_suffix(".svg")),
    }

def write_csv(path, rows, fields):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(k, "") for k in fields})

def write_doc(outdir):
    text = """# GROMACS MD figure documentation

## Important correction

The plotting script uses automatic time-unit detection. If the maximum trajectory time is larger than 1000, the time values are interpreted as ps and converted to ns. If the maximum trajectory time is approximately 100, the time values are interpreted as already being in ns. This prevents artificial compression of 100 ns trajectories into 0.1 ns.

## Figure structure

Two figure types were generated:

1. Per-replicate figures:
   Each figure contains one compound, one replicate, and one metric.

2. Per-system three-replicate panel figures:
   Each figure contains one compound and one metric. The three independent replicates are shown as vertically stacked panels, not overlaid curves.

## Plot style

For time-dependent metrics, the light line shows the raw trajectory and the darker line shows a moving-average trend. This preserves trajectory-level fluctuations while making long-term trends easier to inspect. For RMSF, residue-level profiles are plotted directly.

## Recommended manuscript usage

For the main or supplementary MD stability figure, the most informative panels are:

- ligand heavy-atom RMSD
- protein-ligand minimum distance
- protein-ligand contacts
- protein-ligand hydrogen bonds
- protein backbone RMSD
- protein backbone RMSF

## Methods text

After completion of three independent 100 ns GROMACS simulations for each A35R-ligand complex, trajectories were processed to correct periodic boundary effects and fitted to the protein backbone. Protein backbone RMSD, ligand heavy-atom RMSD, backbone RMSF, radius of gyration, protein-ligand hydrogen bonds, minimum distance, and contact number were calculated to evaluate complex stability. Each compound and replicate was plotted separately to avoid masking replicate-specific behavior. Time units were automatically checked during plotting to ensure that trajectories were displayed over the correct 0-100 ns range.

## General figure legend

MD-based stability analysis of A35R-ligand complexes. For each ligand, three independent 100 ns GROMACS simulations were analyzed separately. Raw trajectory values are shown as light lines, and moving-average trends are shown as darker lines. Each replicate is displayed in a separate panel to avoid curve overlap and to allow direct inspection of replicate-specific stability behavior.
"""
    (outdir / "SCI_methods_and_figure_legends_fixed.md").write_text(text)
    (outdir / "SCI_methods_and_figure_legends_fixed.txt").write_text(text)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_md100_3rep")
    parser.add_argument("--out", default="gmx_nature_split_figures_v2")
    parser.add_argument("--smooth-window", type=int, default=101)
    args = parser.parse_args()

    setup_style()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    stats = []
    fig_index = []

    for metric in METRICS:
        print(f"\n===== {metric} =====")

        for system in SYSTEMS:
            for rep in REPS:
                s = plot_single(root, outdir, system, rep, metric, args.smooth_window)
                if s:
                    stats.append(s)
                    fig_index.append({
                        "level": "per_replicate",
                        "metric": metric,
                        "system": system,
                        "rep": rep,
                        "png": s["figure_png"],
                        "pdf": s["figure_pdf"],
                        "svg": s["figure_svg"],
                    })
                    print(f"[OK] single {metric} {system} {rep} x=({s['x_min']:.3f},{s['x_max']:.3f}) mode={s['time_unit_mode']}")

            p = plot_panel(root, outdir, system, metric, args.smooth_window)
            if p:
                fig_index.append({
                    "level": "per_system_three_reps_panel",
                    "metric": metric,
                    "system": system,
                    "rep": "rep1_rep2_rep3_separate_panels",
                    "png": p["figure_png"],
                    "pdf": p["figure_pdf"],
                    "svg": p["figure_svg"],
                })
                print(f"[OK] panel {metric} {system}")

    stat_fields = [
        "metric", "system", "rep", "source", "time_unit_mode",
        "x_min", "x_max",
        "mean_all", "sd_all", "min_all", "max_all", "last", "n",
        "mean_50_100ns", "sd_50_100ns", "n_50_100ns",
        "figure_png", "figure_pdf", "figure_svg",
    ]

    index_fields = ["level", "metric", "system", "rep", "png", "pdf", "svg"]

    write_csv(outdir / "per_replicate_summary_statistics.csv", stats, stat_fields)
    write_csv(outdir / "figure_file_index.tsv", fig_index, index_fields)
    write_doc(outdir)

    print("\n============================================================")
    print("[DONE] Replot finished")
    print("============================================================")
    print(f"[OUTDIR] {outdir}")
    print(f"[STATS] {outdir / 'per_replicate_summary_statistics.csv'}")
    print(f"[DOC] {outdir / 'SCI_methods_and_figure_legends_fixed.md'}")

if __name__ == "__main__":
    main()
