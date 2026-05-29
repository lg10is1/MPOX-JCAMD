conda activate af
cd /path/to/alphafold

python3 docker/run_docker.py \
  --fasta_paths=/path/to/input.fasta \
  --data_dir=/path/to/alphafold_dbs \
  --model_preset=monomer_ptm \
  --max_template_date=2024-01-01 \
  --output_dir=/path/to/output