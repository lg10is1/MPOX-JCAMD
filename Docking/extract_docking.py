# -*- coding: utf-8 -*-
"""
Extract the best binding energy from AutoDock Vina log files.
This script scans a directory containing Vina output logs (in the format drugs*_log.txt),
parses the affinity of the top-ranked mode, and saves a ranked Excel file.
Usage:
    1. Set LOG_DIR to the folder containing your *log.txt files.
    2. Set OUTPUT_EXCEL to the desired path for the output Excel file.
    3. Run: python extract_vina_scores.py
"""
import os
import glob
import re
import pandas as pd
# ================= CONFIGURATION =================
# Directory containing the Vina log files (drugs*_log.txt)
LOG_DIR = "./logs"        # <-- Modify this path as needed
# Output Excel file path
OUTPUT_EXCEL = "./docking_scores.xlsx"   # <-- Modify this path as needed
# =================================================
results = []
log_files = glob.glob(os.path.join(LOG_DIR, "drugs*_log.txt"))
if not log_files:
    print(f"Error: No drugs*_log.txt files found in {LOG_DIR}. Please check the path.")
    exit()
for filepath in log_files:
    filename = os.path.basename(filepath)
    drug_id = filename.replace("_log.txt", "")   # e.g., drugs1
    with open(filepath, "r") as f:
        content = f.read()
    # Match the affinity of the first mode, e.g., "   1         -8.3"
    match = re.search(r"^\s+1\s+(-?\d+\.?\d*)\s+", content, re.MULTILINE)
    affinity = float(match.group(1)) if match else None
    results.append({"Drug_ID": drug_id, "Affinity (kcal/mol)": affinity})
df = pd.DataFrame(results)
df_sorted = df.dropna(subset=["Affinity (kcal/mol)"]).sort_values("Affinity (kcal/mol)")
df_sorted.to_excel(OUTPUT_EXCEL, index=False)
print(f"Done! Processed {len(log_files)} files, {len(df_sorted)} valid entries.")
print(f"Output saved to: {OUTPUT_EXCEL}")