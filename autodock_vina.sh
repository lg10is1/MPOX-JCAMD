conda activate autodock_vina

for f in /path/to/ligands_pdbqt/drugs*.pdbqt; do
    b=$(basename $f .pdbqt)
    echo "Processing ligand $b"
    mkdir -p /path/to/output/$b
    vina \
        --config /path/to/config_target.txt \
        --ligand $f \
        --out /path/to/output/$b/out.pdbqt \
        --log /path/to/output/log_file/${b}_log.txt \
        --cpu 8 \
        --num_modes 1
done