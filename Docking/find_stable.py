# find_stable.py (English version)
import pandas as pd
# ===== Configuration =====
INPUT_FILE = "A35R_comparison.xlsx"          # Must be in the same folder as this script
OUTPUT_FILE = "A35R_stable_compounds.xlsx"
SHEET_NAME = "merge and change"
THRESHOLD = 0.3                               # affinity change threshold (kcal/mol)
# =========================
# Read data
df = pd.read_excel(INPUT_FILE, sheet_name=SHEET_NAME)
# Calculate absolute difference
df["Delta"] = (df["Affinity_1"] - df["Affinity_2"]).abs()
# Select compounds with small change
stable = df[df["Delta"] <= THRESHOLD].copy()
stable.sort_values("Delta", inplace=True)
# Keep necessary columns
columns_to_keep = ["Drug_ID", "Affinity_1", "Affinity_2", "Delta", "Rank_1", "Rank_2", "Rank_shift"]
stable = stable[columns_to_keep]
# Safe sheet name (no special characters)
safe_sheet = f"Delta_le_{THRESHOLD}kcal_per_mol"
# Write to Excel
with pd.ExcelWriter(OUTPUT_FILE) as writer:
    stable.to_excel(writer, sheet_name=safe_sheet, index=False)
    summary = pd.DataFrame({
        "Metric": ["Total compounds", "Compounds with Delta <= threshold", "Threshold (kcal/mol)"],
        "Value": [len(df), len(stable), THRESHOLD]
    })
    summary.to_excel(writer, sheet_name="Summary", index=False)
print(f"Done! {len(stable)} out of {len(df)} compounds have affinity change <= {THRESHOLD} kcal/mol.")
print(f"Output saved to: {OUTPUT_FILE}")