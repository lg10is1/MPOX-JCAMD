# Figure legends, methods text, and reviewer-response draft

## Output directory

All Nature-style figures were saved in:

`<PROJECT_ROOT>/gromacs-runs/nature_figures_gmx_mmpbsa`

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

ΔGbind = Gcomplex − Greceptor − Gligand

The plotted ΔTOTAL corresponds to the final MM/GBSA binding free energy. More negative ΔTOTAL values indicate more favorable predicted binding under the same computational protocol. Energy-decomposition terms include ΔVDWAALS, ΔEEL, ΔEGB, ΔESURF, ΔGGAS, ΔGSOLV, and ΔTOTAL.

---

## MD summary table

| metric                | system    |   replicate_mean |   replicate_sd |   n_reps | rep_values              |
|:----------------------|:----------|-----------------:|---------------:|---------:|:------------------------|
| contacts_prot_lig     | drugs2263 |          24.5766 |         2.0393 |        3 | 23.9924;22.8932;26.8442 |
| gyrate_protein        | drugs2263 |           3.6006 |         1.2511 |        3 | 2.1571;4.3721;4.2725    |
| hbond_prot_lig        | drugs2263 |           0.8182 |         0.3506 |        3 | 1.0366;0.4137;1.0042    |
| mindist_prot_lig      | drugs2263 |           0.2125 |         0.0169 |        3 | 0.2043;0.2319;0.2013    |
| rmsd_backbone         | drugs2263 |           2.0247 |         0.18   |        3 | 2.2161;1.9994;1.8587    |
| rmsd_ligand_heavy     | drugs2263 |           2.4872 |         0.0404 |        3 | 2.4497;2.4819;2.5301    |
| rmsf_backbone_residue | drugs2263 |           0.8391 |         0.2131 |        3 | 0.9375;0.9852;0.5945    |
| contacts_prot_lig     | drugs3003 |          18.4009 |         1.3799 |        3 | 18.3965;19.7830;17.0232 |
| gyrate_protein        | drugs3003 |           2.65   |         0.8713 |        3 | 2.5666;1.8234;3.5600    |
| hbond_prot_lig        | drugs3003 |           1.0017 |         0.2692 |        3 | 1.2330;1.0660;0.7063    |
| mindist_prot_lig      | drugs3003 |           0.2346 |         0.0179 |        3 | 0.2275;0.2212;0.2550    |
| rmsd_backbone         | drugs3003 |           1.9338 |         0.8307 |        3 | 1.8251;2.8135;1.1629    |
| rmsd_ligand_heavy     | drugs3003 |           0.87   |         0.1067 |        3 | 0.8064;0.8103;0.9931    |
| rmsf_backbone_residue | drugs3003 |           0.6811 |         0.2049 |        3 | 0.8448;0.7470;0.4514    |
| contacts_prot_lig     | drugs3523 |          27.253  |         5.8837 |        3 | 21.8962;26.3125;33.5503 |
| gyrate_protein        | drugs3523 |           2.9399 |         0.4911 |        3 | 2.6024;2.7141;3.5032    |
| hbond_prot_lig        | drugs3523 |           0.7646 |         0.435  |        3 | 0.2687;1.0820;0.9430    |
| mindist_prot_lig      | drugs3523 |           0.2292 |         0.016  |        3 | 0.2477;0.2213;0.2187    |
| rmsd_backbone         | drugs3523 |           1.7324 |         0.1346 |        3 | 1.8110;1.5770;1.8092    |
| rmsd_ligand_heavy     | drugs3523 |           1.8349 |         0.191  |        3 | 1.8345;1.6441;2.0261    |
| rmsf_backbone_residue | drugs3523 |           0.6765 |         0.0316 |        3 | 0.6986;0.6905;0.6403    |

---

## MM/GBSA summary table

| term          | system    |   replicate_mean_kcal_per_mol |   replicate_sd_kcal_per_mol |   n_reps | rep_values                 |
|:--------------|:----------|------------------------------:|----------------------------:|---------:|:---------------------------|
| DELTA_1_4_EEL | drugs2263 |                         0     |                       0     |        3 | 0.000;-0.000;0.000         |
| DELTA_EEL     | drugs2263 |                       111.837 |                     203.304 |        3 | 86.380;-77.540;326.670     |
| DELTA_EGB     | drugs2263 |                       -98.937 |                     193.98  |        3 | -78.300;83.900;-302.410    |
| DELTA_ESURF   | drugs2263 |                        -3.993 |                       0.625 |        3 | -3.810;-3.480;-4.690       |
| DELTA_GGAS    | drugs2263 |                        82.437 |                     199.983 |        3 | 59.980;-105.370;292.700    |
| DELTA_GSOLV   | drugs2263 |                      -102.933 |                     194.592 |        3 | -82.110;80.410;-307.100    |
| DELTA_TOTAL   | drugs2263 |                       -20.493 |                       5.472 |        3 | -22.130;-24.960;-14.390    |
| DELTA_VDWAALS | drugs2263 |                       -29.397 |                       4.016 |        3 | -26.400;-27.830;-33.960    |
| DELTA_1_4_EEL | drugs3003 |                         0     |                       0     |        3 | -0.000;-0.000;-0.000       |
| DELTA_EEL     | drugs3003 |                      -208.993 |                      57.177 |        3 | -228.610;-144.590;-253.780 |
| DELTA_EGB     | drugs3003 |                       224.627 |                      54.082 |        3 | 243.400;163.660;266.820    |
| DELTA_ESURF   | drugs3003 |                        -3.89  |                       0.495 |        3 | -3.640;-4.460;-3.570       |
| DELTA_GGAS    | drugs3003 |                      -238.703 |                      53.731 |        3 | -257.720;-178.050;-280.340 |
| DELTA_GSOLV   | drugs3003 |                       220.733 |                      54.567 |        3 | 239.760;159.200;263.240    |
| DELTA_TOTAL   | drugs3003 |                       -17.97  |                       0.875 |        3 | -17.960;-18.850;-17.100    |
| DELTA_VDWAALS | drugs3003 |                       -29.713 |                       3.484 |        3 | -29.110;-33.460;-26.570    |
| DELTA_1_4_EEL | drugs3523 |                         0     |                       0     |        3 | 0.000;-0.000;-0.000        |
| DELTA_EEL     | drugs3523 |                        55.077 |                      19.736 |        3 | 34.830;56.140;74.260       |
| DELTA_EGB     | drugs3523 |                       -39.95  |                      13.278 |        3 | -25.070;-44.190;-50.590    |
| DELTA_ESURF   | drugs3523 |                        -4.92  |                       2.667 |        3 | -2.930;-3.880;-7.950       |
| DELTA_GGAS    | drugs3523 |                        12.467 |                       6.06  |        3 | 9.820;19.400;8.180         |
| DELTA_GSOLV   | drugs3523 |                       -44.867 |                      15.525 |        3 | -27.990;-48.070;-58.540    |
| DELTA_TOTAL   | drugs3523 |                       -32.4   |                      16.416 |        3 | -18.170;-28.670;-50.360    |
| DELTA_VDWAALS | drugs3523 |                       -42.613 |                      21.16  |        3 | -25.010;-36.740;-66.090    |

---

## Methods text for manuscript

Molecular dynamics simulations were performed to evaluate the post-docking stability of the A35R-ligand complexes. The three experimentally validated candidate ligands, drugs2263, drugs3003, and drugs3523, were subjected to independent MD simulations after Amber-based system construction and parameterization. The Amber topologies and coordinates were converted into GROMACS-compatible topology and coordinate files while preserving the ligand GAFF2 parameters and assigned charges. Each complex was energy-minimized, equilibrated under NVT and NPT ensembles, and then subjected to 100 ns production MD. For each ligand, three independent replicates were performed using different random seeds. Trajectories were processed with periodic boundary correction, centering, and least-squares fitting before analysis.

Trajectory stability was evaluated using protein backbone RMSD, ligand heavy-atom RMSD, residue-level RMSF, radius of gyration, protein-ligand hydrogen bonds, protein-ligand minimum distance, and protein-ligand contact number. To focus on the equilibrated part of the trajectories, summary statistics were calculated over the selected production window, while full time-series plots were retained for visual inspection.

MM/GBSA binding free-energy estimation was performed using gmx_MMPBSA. For each replicate, frames from the equilibrated trajectory window were extracted and used for MM/GBSA calculation. The receptor and ligand groups were defined as Protein and LIG, respectively. The Generalized Born model was used with physiological salt concentration. The final binding free energy was calculated as ΔGbind = Gcomplex − Greceptor − Gligand, and the total binding free energy was reported as ΔTOTAL. Energy-decomposition terms, including ΔVDWAALS, ΔEEL, ΔEGB, ΔESURF, ΔGGAS, and ΔGSOLV, were used to interpret the dominant energetic contributions.

---

## Results text for manuscript

To reduce the dependence on docking scores alone, we further evaluated the post-docking stability of the three A35R-ligand complexes using 100 ns GROMACS MD simulations with three independent replicates for each ligand. Overall, all three complexes remained analyzable during the production simulations, supporting the physical stability of the modeled systems. Ligand heavy-atom RMSD provided direct information on whether the original docking pose was retained after MD relaxation. A lower and less variable ligand RMSD indicates a more stable binding pose, whereas persistent protein-ligand contacts and short minimum distances support sustained ligand-pocket association.

The MM/GBSA analysis provided a quantitative post-MD estimate of ligand binding energetics. The current MM/GBSA results indicate the following ΔTOTAL values across replicates: drugs2263: -20.49 ± 5.47 kcal/mol; drugs3003: -17.97 ± 0.88 kcal/mol; drugs3523: -32.40 ± 16.42 kcal/mol. Energy decomposition further separates the binding contribution into van der Waals, electrostatic, polar solvation, nonpolar solvation, gas-phase, and solvation terms. Therefore, the revised analysis no longer relies exclusively on docking scores, but combines docking, SPR validation, MD stability, and MM/GBSA energy estimation to support ligand prioritization.

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

We agree with the reviewer that the previous interaction analysis was mainly descriptive. To address this issue, we added quantitative MD-based stability assessment and MM/GBSA energy decomposition. The revised Results now include ligand heavy-atom RMSD, protein backbone RMSD, RMSF, radius of gyration, hydrogen bonds, minimum distance, contact number, and MM/GBSA ΔTOTAL values. The energy-decomposition analysis further identifies the relative contributions of van der Waals, electrostatic, polar solvation, nonpolar solvation, gas-phase, and solvation terms. We have also revised the wording of the proposed “dual binding model” to avoid overstatement and present it as a model supported by docking, SPR validation, MD stability, and MM/GBSA energetics, while acknowledging that further structural or mutagenesis experiments would be needed for definitive mechanistic confirmation.

