#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

echo "============================================================"
echo "[INFO] Make Nature-style split GROMACS figures"
echo "[INFO] BASE=$BASE"
echo "============================================================"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[ERROR] python3 not found."
  exit 1
fi

python3 - <<'PY'
try:
    import matplotlib
    print("[OK] matplotlib:", matplotlib.__version__)
except Exception as e:
    print("[ERROR] matplotlib is not available:", e)
    print("Please run one of the following:")
    print("  conda activate amber_rebuild")
    print("  conda install -c conda-forge matplotlib numpy -y")
    raise SystemExit(1)
PY

cat > 18_plot_nature_split_gromacs.py <<'PY'
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

# Nature-like, color-blind friendly muted palette
SYSTEM_COLORS = {
    "drugs2263": "#0072B2",   # muted blue
    "drugs3003": "#009E73",   # muted green
    "drugs3523": "#D55E00",   # muted vermillion
}

REP_LINESTYLES = {
    "rep1": "-",
    "rep2": "-",
    "rep3": "-",
}

METRICS = {
    "rmsd_backbone": {
        "csv": "rmsd_backbone.csv",
        "xvg": "rmsd_backbone.xvg",
        "x_label": "Time (ns)",
        "y_label": "Protein backbone RMSD (nm)",
        "title": "Protein backbone RMSD",
        "x_type": "time",
        "y_type": "continuous",
        "description": "Protein backbone RMSD evaluates the global conformational deviation of A35R relative to the reference structure after structural fitting.",
    },
    "rmsd_ligand_heavy": {
        "csv": "rmsd_ligand_heavy.csv",
        "xvg": "rmsd_ligand_heavy.xvg",
        "x_label": "Time (ns)",
        "y_label": "Ligand heavy-atom RMSD (nm)",
        "title": "Ligand heavy-atom RMSD",
        "x_type": "time",
        "y_type": "continuous",
        "description": "Ligand heavy-atom RMSD evaluates whether the docking-derived ligand pose is preserved during MD after protein alignment.",
    },
    "rmsf_backbone_residue": {
        "csv": "rmsf_backbone_residue.csv",
        "xvg": "rmsf_backbone_residue.xvg",
        "x_label": "Residue index",
        "y_label": "Backbone RMSF (nm)",
        "title": "Protein backbone RMSF",
        "x_type": "residue",
        "y_type": "continuous",
        "description": "Backbone RMSF quantifies residue-level flexibility of A35R during the simulation.",
    },
    "gyrate_protein": {
        "csv": "gyrate_protein.csv",
        "xvg": "gyrate_protein.xvg",
        "x_label": "Time (ns)",
        "y_label": "Radius of gyration (nm)",
        "title": "Protein radius of gyration",
        "x_type": "time",
        "y_type": "continuous",
        "description": "Radius of gyration reports the overall compactness of A35R during MD.",
    },
    "hbond_prot_lig": {
        "csv": "hbond_prot_lig.csv",
        "xvg": "hbond_prot_lig.xvg",
        "x_label": "Time (ns)",
        "y_label": "Protein-ligand hydrogen bonds",
        "title": "Protein-ligand hydrogen bonds",
        "x_type": "time",
        "y_type": "count",
        "description": "Hydrogen-bond number measures directional polar interactions between A35R and the ligand.",
    },
    "mindist_prot_lig": {
        "csv": "mindist_prot_lig.csv",
        "xvg": "mindist_prot_lig.xvg",
        "x_label": "Time (ns)",
        "y_label": "Minimum distance (nm)",
        "title": "Protein-ligand minimum distance",
        "x_type": "time",
        "y_type": "continuous",
        "description": "Minimum distance measures the closest atomic distance between A35R and the ligand, indicating whether the ligand remains associated with the protein.",
    },
    "contacts_prot_lig": {
        "csv": "contacts_prot_lig.csv",
        "xvg": "contacts_prot_lig.xvg",
        "x_label": "Time (ns)",
        "y_label": "Protein-ligand contacts",
        "title": "Protein-ligand contacts",
        "x_type": "time",
        "y_type": "count",
        "description": "Contact number measures the extent of close nonbonded contacts between A35R and the ligand.",
    },
}

def setup_nature_style():
    plt.rcParams.update({
        "font.family": "Arial",
        "font.sans-serif": ["Arial", "Helvetica", "DejaVu Sans"],
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
        "figure.dpi": 300,
        "savefig.dpi": 600,
        "savefig.bbox": "tight",
        "savefig.transparent": False,
    })

def mm_to_inch(mm):
    return mm / 25.4

def read_xvg(path):
    rows = []
    path = Path(path)
    if not path.exists() or path.stat().st_size == 0:
        return rows

    with path.open(errors="ignore") as f:
        for line in f:
            s = line.strip()
            if not s:
                continue
            if s.startswith("#") or s.startswith("@"):
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
    if not path.exists() or path.stat().st_size == 0:
        return []

    rows = []
    with path.open(newline="", errors="ignore") as f:
        reader = csv.reader(f)
        all_rows = list(reader)

    if not all_rows:
        return []

    # If first row is header, skip it
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

def load_metric_series(root, system, rep, metric):
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
        return [], [], source

    xs = []
    ys = []

    for vals in rows:
        if len(vals) < 2:
            continue
        x = vals[0]
        y = vals[1]

        if meta["x_type"] == "time":
            x = x / 1000.0

        xs.append(x)
        ys.append(y)

    return xs, ys, source

def rolling_mean(values, window):
    if window <= 1 or len(values) < window:
        return values[:]

    out = []
    half = window // 2

    prefix = [0.0]
    for v in values:
        prefix.append(prefix[-1] + v)

    n = len(values)
    for i in range(n):
        lo = max(0, i - half)
        hi = min(n, i + half + 1)
        out.append((prefix[hi] - prefix[lo]) / (hi - lo))
    return out

def finite_values(vals):
    return [v for v in vals if v is not None and not math.isnan(v) and math.isfinite(v)]

def summarize_series(xs, ys, metric):
    vals = finite_values(ys)
    if not vals:
        return None

    meta = METRICS[metric]
    result = {
        "mean_all": statistics.mean(vals),
        "sd_all": statistics.stdev(vals) if len(vals) > 1 else 0.0,
        "min_all": min(vals),
        "max_all": max(vals),
        "last": vals[-1],
        "n": len(vals),
    }

    if meta["x_type"] == "time":
        last50 = [y for x, y in zip(xs, ys) if x >= 50.0]
        last50 = finite_values(last50)
        if last50:
            result.update({
                "mean_50_100ns": statistics.mean(last50),
                "sd_50_100ns": statistics.stdev(last50) if len(last50) > 1 else 0.0,
                "n_50_100ns": len(last50),
            })
        else:
            result.update({
                "mean_50_100ns": math.nan,
                "sd_50_100ns": math.nan,
                "n_50_100ns": 0,
            })
    else:
        result.update({
            "mean_50_100ns": math.nan,
            "sd_50_100ns": math.nan,
            "n_50_100ns": 0,
        })

    return result

def format_axis(ax, metric, xs, ys):
    meta = METRICS[metric]

    ax.set_xlabel(meta["x_label"])
    ax.set_ylabel(meta["y_label"])

    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.tick_params(direction="out", length=3, width=0.7)

    if meta["x_type"] == "time":
        ax.set_xlim(0, 100)
        ax.xaxis.set_major_locator(MaxNLocator(6))
    else:
        ax.xaxis.set_major_locator(MaxNLocator(6, integer=True))

    vals = finite_values(ys)
    if vals:
        ymin = min(vals)
        ymax = max(vals)
        if meta["y_type"] == "count":
            ymin = 0
            ymax = max(1, ymax)
            pad = max(0.5, ymax * 0.12)
        else:
            pad = (ymax - ymin) * 0.08 if ymax > ymin else ymax * 0.1 + 0.1
        ax.set_ylim(max(0, ymin - pad), ymax + pad)

    if meta["y_type"] == "count":
        ax.yaxis.set_major_locator(MaxNLocator(integer=True))

def save_figure(fig, out_prefix):
    out_prefix = Path(out_prefix)
    out_prefix.parent.mkdir(parents=True, exist_ok=True)
    for ext in ["png", "pdf", "svg"]:
        fig.savefig(out_prefix.with_suffix(f".{ext}"))
    plt.close(fig)

def plot_single_replicate(root, outdir, system, rep, metric, smooth_window):
    xs, ys, source = load_metric_series(root, system, rep, metric)
    if not xs or not ys:
        print(f"[MISS] {system} {rep} {metric}: {source}")
        return None

    meta = METRICS[metric]
    color = SYSTEM_COLORS[system]

    fig, ax = plt.subplots(figsize=(mm_to_inch(89), mm_to_inch(62)))

    if meta["x_type"] == "time":
        y_smooth = rolling_mean(ys, smooth_window)
        ax.plot(xs, ys, color=color, alpha=0.20, linewidth=0.45)
        ax.plot(xs, y_smooth, color=color, alpha=1.0, linewidth=1.2)
    else:
        ax.plot(xs, ys, color=color, linewidth=1.0)

    ax.set_title(f"{metric} | {system} {rep}", pad=4)
    format_axis(ax, metric, xs, ys)

    fig.tight_layout()

    out_prefix = outdir / "per_replicate" / system / rep / f"{metric}_{system}_{rep}"
    save_figure(fig, out_prefix)

    stats = summarize_series(xs, ys, metric)

    return {
        "metric": metric,
        "system": system,
        "rep": rep,
        "source": str(source),
        "figure_png": str(out_prefix.with_suffix(".png")),
        "figure_pdf": str(out_prefix.with_suffix(".pdf")),
        "figure_svg": str(out_prefix.with_suffix(".svg")),
        **stats,
    }

def plot_system_three_reps_panel(root, outdir, system, metric, smooth_window):
    meta = METRICS[metric]
    color = SYSTEM_COLORS[system]

    data = []
    for rep in REPS:
        xs, ys, source = load_metric_series(root, system, rep, metric)
        if xs and ys:
            data.append((rep, xs, ys, source))

    if not data:
        return None

    fig_height = 45 * len(data)
    fig, axes = plt.subplots(
        nrows=len(data),
        ncols=1,
        figsize=(mm_to_inch(89), mm_to_inch(fig_height)),
        sharex=(meta["x_type"] == "time"),
    )

    if len(data) == 1:
        axes = [axes]

    for ax, (rep, xs, ys, source) in zip(axes, data):
        if meta["x_type"] == "time":
            y_smooth = rolling_mean(ys, smooth_window)
            ax.plot(xs, ys, color=color, alpha=0.20, linewidth=0.45)
            ax.plot(xs, y_smooth, color=color, alpha=1.0, linewidth=1.1)
        else:
            ax.plot(xs, ys, color=color, linewidth=1.0)

        ax.text(
            0.02, 0.88, rep,
            transform=ax.transAxes,
            ha="left",
            va="top",
            fontsize=7,
            fontweight="bold",
        )
        format_axis(ax, metric, xs, ys)
        ax.set_title("")

    axes[0].set_title(f"{metric} | {system}", pad=4)

    fig.tight_layout()

    out_prefix = outdir / "per_system_three_reps_panel" / system / f"{metric}_{system}_three_reps_separate_panels"
    save_figure(fig, out_prefix)

    return {
        "metric": metric,
        "system": system,
        "figure_png": str(out_prefix.with_suffix(".png")),
        "figure_pdf": str(out_prefix.with_suffix(".pdf")),
        "figure_svg": str(out_prefix.with_suffix(".svg")),
    }

def write_csv(path, rows, fieldnames):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames)
        w.writeheader()
        for r in rows:
            clean = {}
            for k in fieldnames:
                clean[k] = r.get(k, "")
            w.writerow(clean)

def write_methods_and_legend_doc(outdir):
    doc = outdir / "SCI_methods_and_figure_legends.md"

    text = """# GROMACS MD Analysis and Figure Description

## Methods text for manuscript

### Molecular dynamics trajectory analysis

The Amber/AmberTools-parameterized A35R-ligand complex systems were converted to GROMACS format and subjected to three independent 100 ns molecular dynamics simulations for each ligand. After completion of the simulations, trajectories were processed to correct periodic boundary effects and to fit the protein backbone to the reference structure. The stability of each A35R-ligand complex was evaluated using protein backbone RMSD, ligand heavy-atom RMSD, protein backbone RMSF, radius of gyration, protein-ligand hydrogen bonds, protein-ligand minimum distance, and protein-ligand contact number.

Protein backbone RMSD was used to assess the global conformational stability of A35R. Ligand heavy-atom RMSD was calculated after protein alignment to evaluate whether the docking-derived ligand pose was maintained during MD. RMSF was used to quantify residue-level flexibility of the protein backbone. The radius of gyration was calculated to evaluate the compactness of the protein structure. Protein-ligand hydrogen bonds were used to assess persistent directional polar interactions. Protein-ligand minimum distance and contact number were used to determine whether the ligand remained associated with the binding region during the simulations.

For visualization, each ligand and each replicate were plotted separately to avoid masking replicate-specific behavior. For time-dependent metrics, raw trajectories are shown as light lines and moving-average smoothed curves are shown as darker lines. RMSF profiles are plotted as residue-level curves. All plots were exported in PNG, PDF, and SVG formats for manuscript preparation.

## Figure organization

The generated figures are organized into two levels:

1. `per_replicate/`: one independent figure for each compound, replicate, and metric.
2. `per_system_three_reps_panel/`: one figure per compound and metric, with the three replicates shown in separate stacked panels rather than overlaid curves.

This organization allows the stability behavior of each independent simulation to be inspected directly while also providing compound-level replicate comparison.

## Figure legends for SCI manuscript or supplementary figures

### Protein backbone RMSD

Protein backbone RMSD of the A35R-ligand complex during 100 ns MD simulations. Each compound and replicate is shown separately. Lower and more plateau-like RMSD values indicate greater global structural stability of the protein complex.

### Ligand heavy-atom RMSD

Ligand heavy-atom RMSD after protein backbone alignment during 100 ns MD simulations. This metric evaluates whether the docking-derived ligand binding pose is retained. A low ligand RMSD indicates stable pose maintenance, whereas a high ligand RMSD with persistent protein-ligand contacts suggests pose rearrangement rather than complete dissociation.

### Protein backbone RMSF

Backbone RMSF profile of A35R during the 100 ns simulations. RMSF reflects residue-level flexibility. Peaks correspond to flexible loops or terminal regions, whereas low RMSF around the binding region indicates local stabilization.

### Radius of gyration

Radius of gyration of A35R during 100 ns MD simulations. This metric evaluates the compactness of the protein structure. Stable Rg values indicate that the protein does not undergo major unfolding or abnormal expansion.

### Protein-ligand hydrogen bonds

Number of hydrogen bonds between A35R and the ligand during 100 ns MD simulations. Persistent hydrogen bonds indicate stable directional polar interactions that may contribute to ligand anchoring.

### Protein-ligand minimum distance

Minimum distance between A35R and the ligand during 100 ns MD simulations. Sustained short distances indicate that the ligand remains associated with the protein, whereas a sudden increase may suggest ligand dissociation.

### Protein-ligand contacts

Number of protein-ligand contacts during 100 ns MD simulations. A higher and persistent contact number indicates a larger or more stable interaction interface between the ligand and A35R.

## Suggested results description

The three ligands displayed different MD stability profiles. drugs3003 showed the most stable docking-derived pose, as indicated by the lowest ligand heavy-atom RMSD across three replicates. drugs3523 maintained the largest number of protein-ligand contacts and showed relatively stable protein backbone behavior, although moderate ligand pose rearrangement was observed. drugs2263 retained close proximity to A35R but exhibited a higher ligand RMSD, suggesting that the initial docking pose was less stable and shifted to an alternative binding orientation during MD.

"""
    doc.write_text(text)

    txt = outdir / "SCI_methods_and_figure_legends.txt"
    txt.write_text(text)

def write_readme(outdir):
    readme = outdir / "README_NATURE_SPLIT_FIGURES.md"
    text = """# Nature-style split GROMACS figures

## Directory structure

- `per_replicate/`
  - One figure for each compound, replicate, and metric.
  - Example: `per_replicate/drugs3003/rep1/rmsd_ligand_heavy_drugs3003_rep1.pdf`

- `per_system_three_reps_panel/`
  - One figure for each compound and metric.
  - The three replicates are shown as separate stacked panels, not overlaid curves.

- `per_replicate_summary_statistics.csv`
  - Summary statistics for every compound, replicate, and metric.

- `figure_file_index.tsv`
  - Index of all generated figure files.

- `SCI_methods_and_figure_legends.md`
  - Methods and figure legend text suitable for manuscript or supplementary information.

## Plotting style

- Single-column figure width: 89 mm.
- Export formats: PNG, PDF, SVG.
- Time-dependent plots show raw trajectory as a light line and moving-average trend as a darker line.
- Colors are muted and color-blind friendly:
  - drugs2263: blue
  - drugs3003: green
  - drugs3523: vermillion

## Recommended figures for SCI response

For reviewer response, prioritize:
1. Ligand heavy-atom RMSD
2. Protein-ligand minimum distance
3. Protein-ligand contacts
4. Hydrogen bonds
5. Protein backbone RMSD
6. RMSF profile

"""
    readme.write_text(text)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default="gmx_md100_3rep")
    parser.add_argument("--out", default="gmx_nature_split_figures")
    parser.add_argument("--smooth-window", type=int, default=101)
    args = parser.parse_args()

    setup_nature_style()

    root = Path(args.root).resolve()
    outdir = Path(args.out).resolve()
    outdir.mkdir(parents=True, exist_ok=True)

    all_stats = []
    fig_index = []

    print("[INFO] root:", root)
    print("[INFO] outdir:", outdir)

    for metric in METRICS:
        print(f"\n============================================================")
        print(f"[METRIC] {metric}")
        print(f"============================================================")

        for system in SYSTEMS:
            for rep in REPS:
                stat = plot_single_replicate(
                    root=root,
                    outdir=outdir,
                    system=system,
                    rep=rep,
                    metric=metric,
                    smooth_window=args.smooth_window,
                )

                if stat is not None:
                    all_stats.append(stat)
                    fig_index.append({
                        "level": "per_replicate",
                        "metric": metric,
                        "system": system,
                        "rep": rep,
                        "png": stat["figure_png"],
                        "pdf": stat["figure_pdf"],
                        "svg": stat["figure_svg"],
                        "description": METRICS[metric]["description"],
                    })
                    print(f"[OK] per-replicate {metric} {system} {rep}")

            panel = plot_system_three_reps_panel(
                root=root,
                outdir=outdir,
                system=system,
                metric=metric,
                smooth_window=args.smooth_window,
            )

            if panel is not None:
                fig_index.append({
                    "level": "per_system_three_reps_panel",
                    "metric": metric,
                    "system": system,
                    "rep": "rep1_rep2_rep3_separate_panels",
                    "png": panel["figure_png"],
                    "pdf": panel["figure_pdf"],
                    "svg": panel["figure_svg"],
                    "description": METRICS[metric]["description"],
                })
                print(f"[OK] per-system panel {metric} {system}")

    stat_fields = [
        "metric", "system", "rep", "source",
        "mean_all", "sd_all", "min_all", "max_all", "last", "n",
        "mean_50_100ns", "sd_50_100ns", "n_50_100ns",
        "figure_png", "figure_pdf", "figure_svg",
    ]
    write_csv(outdir / "per_replicate_summary_statistics.csv", all_stats, stat_fields)

    index_fields = [
        "level", "metric", "system", "rep",
        "png", "pdf", "svg", "description",
    ]
    write_csv(outdir / "figure_file_index.tsv", fig_index, index_fields)

    write_methods_and_legend_doc(outdir)
    write_readme(outdir)

    print("\n============================================================")
    print("[DONE] Nature-style split figures generated.")
    print("============================================================")
    print(f"[OUTDIR] {outdir}")
    print(f"[STATS] {outdir / 'per_replicate_summary_statistics.csv'}")
    print(f"[INDEX] {outdir / 'figure_file_index.tsv'}")
    print(f"[DOC]   {outdir / 'SCI_methods_and_figure_legends.md'}")
    print(f"[README]{outdir / 'README_NATURE_SPLIT_FIGURES.md'}")

if __name__ == "__main__":
    main()
PY

chmod +x 18_plot_nature_split_gromacs.py

echo "============================================================"
echo "[INFO] Run plotting script"
echo "============================================================"

python3 18_plot_nature_split_gromacs.py \
  --root gmx_md100_3rep \
  --out gmx_nature_split_figures \
  --smooth-window 101

echo "============================================================"
echo "[INFO] Check generated files"
echo "============================================================"

echo "[INFO] Number of PNG files:"
find gmx_nature_split_figures -name "*.png" | wc -l

echo "[INFO] Number of PDF files:"
find gmx_nature_split_figures -name "*.pdf" | wc -l

echo "[INFO] Number of SVG files:"
find gmx_nature_split_figures -name "*.svg" | wc -l

echo
echo "[INFO] Example output files:"
find gmx_nature_split_figures -type f | head -n 30

echo
echo "[DONE] All figures and documents generated."
