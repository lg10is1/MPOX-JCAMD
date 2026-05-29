#!/usr/bin/env bash
set -euo pipefail

BASE="<PROJECT_ROOT>/gromacs-runs"
cd "$BASE"

echo -e "system\trep\tpbc_xtc\tfit_xtc\trmsd_bb\trmsd_lig\trmsf\trg\thbond\tmindist\tcontacts\tstatus" > gmx_analysis_output_check.tsv

for SYS in drugs2263 drugs3003 drugs3523
do
  for REP in rep1 rep2 rep3
  do
    D="gmx_md100_3rep/${SYS}/${REP}"
    A="${D}/analysis"

    check_file() {
      local f="$1"
      if [[ -s "$f" ]]; then
        echo "YES"
      else
        echo "NO"
      fi
    }

    PBC=$(check_file "$A/md_100ns_center_fit.xtc")
    FIT=$(check_file "$A/md_100ns_fit.xtc")
    RMSD_BB=$(check_file "$A/rmsd_backbone.xvg")
    RMSD_LIG=$(check_file "$A/rmsd_ligand_heavy.xvg")
    RMSF=$(check_file "$A/rmsf_backbone_residue.xvg")
    RG=$(check_file "$A/gyrate_protein.xvg")
    HBOND=$(check_file "$A/hbond_prot_lig.xvg")
    MINDIST=$(check_file "$A/mindist_prot_lig.xvg")
    CONTACTS=$(check_file "$A/contacts_prot_lig.xvg")

    STATUS="PASS"
    for v in "$RMSD_BB" "$RMSD_LIG" "$RMSF" "$RG" "$HBOND" "$MINDIST"; do
      if [[ "$v" != "YES" ]]; then
        STATUS="CHECK_REQUIRED"
      fi
    done

    echo -e "${SYS}\t${REP}\t${PBC}\t${FIT}\t${RMSD_BB}\t${RMSD_LIG}\t${RMSF}\t${RG}\t${HBOND}\t${MINDIST}\t${CONTACTS}\t${STATUS}" >> gmx_analysis_output_check.tsv
  done
done

column -t gmx_analysis_output_check.tsv || cat gmx_analysis_output_check.tsv

echo
echo "[INFO] Dangerous keyword scan in analysis logs:"
grep -E "Fatal error|Segmentation fault|Cannot|Error|No such|Invalid|Selection" gmx_analysis_*.out gmx_analysis_*.err 2>/dev/null || echo "No obvious analysis errors found."
