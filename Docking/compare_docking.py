# -*- coding: utf-8 -*-
import pandas as pd
import numpy as np
# ===== Configuration =====
INPUT_EXCEL = "A35R_2.xlsx"
OUTPUT_EXCEL = "A35R_comparison.xlsx"
SHEET_NAME = 0
# =========================
def spearman_rank_corr(x, y):
    """Manual calculation of Spearman rank correlation (without scipy)"""
    rx = x.rank()
    ry = y.rank()
    n = len(x)
    if n < 2:
        return None, None
    d = rx - ry
    rho = 1 - (6 * (d**2).sum()) / (n * (n**2 - 1))
    # approximate t-statistic (for reference only)
    t_stat = rho * np.sqrt((n - 2) / (1 - rho**2))
    return rho, t_stat
# Read data
df1 = pd.read_excel(INPUT_EXCEL, sheet_name=SHEET_NAME, usecols="A:B")
df2 = pd.read_excel(INPUT_EXCEL, sheet_name=SHEET_NAME, usecols="D:E")
df1.columns = ["Drug_ID", "Affinity_1"]
df2.columns = ["Drug_ID", "Affinity_2"]
df1["Affinity_1"] = pd.to_numeric(df1["Affinity_1"], errors='coerce')
df2["Affinity_2"] = pd.to_numeric(df2["Affinity_2"], errors='coerce')
df1.dropna(subset=["Affinity_1"], inplace=True)
df2.dropna(subset=["Affinity_2"], inplace=True)
# Sort by affinity
df1_sorted = df1.sort_values("Affinity_1").reset_index(drop=True)
df2_sorted = df2.sort_values("Affinity_2").reset_index(drop=True)
df1_sorted["Rank_1"] = df1_sorted.index + 1
df2_sorted["Rank_2"] = df2_sorted.index + 1
# Merge on Drug_ID (intersection)
merged = pd.merge(df1_sorted, df2_sorted, on="Drug_ID", how="inner")
merged["Rank_shift"] = merged["Rank_1"] - merged["Rank_2"]
merged.sort_values("Affinity_2", inplace=True)
# Spearman correlation (manual calculation)
if len(merged) > 2:
    corr, t_val = spearman_rank_corr(merged["Affinity_1"], merged["Affinity_2"])
else:
    corr, t_val = None, None
# Output to Excel
with pd.ExcelWriter(OUTPUT_EXCEL) as writer:
    merged.to_excel(writer, sheet_name="Intersection_and_rank_shift", index=False)
    summary = pd.DataFrame({
        "Metric": ["Total compounds (blind docking)", "Total compounds (restricted docking)",
                   "Intersection count", "Spearman correlation", "Approximate t-value"],
        "Value": [len(df1_sorted), len(df2_sorted), len(merged),
                  f"{corr:.4f}" if corr is not None else "N/A",
                  f"{t_val:.2f}" if t_val is not None else "N/A"]
    })
    summary.to_excel(writer, sheet_name="Summary", index=False)
    # Top-N overlap
    overlap_data = []
    for top_n in [20, 50, 100, 200, 500]:
        top1 = set(df1_sorted.head(top_n)["Drug_ID"])
        top2 = set(df2_sorted.head(top_n)["Drug_ID"])
        common = len(top1 & top2)
        overlap_data.append([top_n, common])
    overlap_df = pd.DataFrame(overlap_data, columns=["Top N", "Overlap"])
    overlap_df.to_excel(writer, sheet_name="TopN_overlap", index=False)
print(f"Analysis complete! Compounds in intersection: {len(merged)}")
if corr is not None:
    print(f"Spearman correlation: {corr:.4f} (approx. t = {t_val:.2f})")
print(f"Results saved to: {OUTPUT_EXCEL}")