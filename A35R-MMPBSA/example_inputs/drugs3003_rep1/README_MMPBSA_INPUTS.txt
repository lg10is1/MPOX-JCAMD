System: drugs3003
Repeat: rep1

Clean index groups:
  0 Protein
  1 LIG
  2 Protein_LIG
  3 System

Production trajectory:
  mmpbsa_50_100_dt500_fit.xtc
  Time window: 50000-100000 ps
  Sampling interval: 500 ps

Quick-test trajectory:
  mmpbsa_test_90_100_dt1000_fit.xtc
  Time window: 90000-100000 ps
  Sampling interval: 1000 ps

gmx_MMPBSA command should use:
  -cs md_100ns.tpr
  -ct mmpbsa_50_100_dt500_fit.xtc
  -ci mmpbsa_index.ndx
  -cg 0 1
  -cp topol.top

Meaning:
  receptor group = 0 Protein
  ligand group   = 1 LIG


