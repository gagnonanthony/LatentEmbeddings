#!/bin/bash
#SBATCH --job-name=embeddings_size_experiment
#SBATCH --output=logs/embeddings_size_experiment_%j.log
#SBATCH --error=logs/embeddings_size_experiment_%j.err
#SBATCH --time=5:00:00
#SBATCH --gpus=h100_10gb:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32GB
#SBATCH --array=1-12
#SBATCH --account=def-larissa1
#SBATCH --mail-user=anthony.gagnon7@usherbrooke.ca
#SBATCH --mail-type=ALL

# Load the necessary modules
module load python/3.12.4
module load scipy-stack vtk arrow
source /home/agagnon/scratch/MMGAE/.venv/bin/activate

# Define the embedding sizes
embedding_sizes=(
    4
    6
    8
    12
    16
    24
    32
    48
    64
    96
    128
    256
)

# Get the setup index
setup_index=$((SLURM_ARRAY_TASK_ID - 1))

# Get the setup
embedding_size=${embedding_sizes[$setup_index]}

# We take the base model config and copy it to the output folder.
mkdir -p outputs/EmbeddingsSize/${embedding_size}
cp outputs/EmbeddingsSize/model_config.json outputs/EmbeddingsSize/${embedding_size}/model_config.json

# Append the embedding size to the model config (there is no hidden_dim in the model config)
jq --argjson embedding_size "${embedding_size}" \
    '.hidden_dim = $embedding_size' \
    outputs/EmbeddingsSize/${embedding_size}/model_config.json \
    > outputs/EmbeddingsSize/${embedding_size}/model_config.tmp.json \
    && mv outputs/EmbeddingsSize/${embedding_size}/model_config.tmp.json \
          outputs/EmbeddingsSize/${embedding_size}/model_config.json

# Run the training script
train --dataset_config data/ABCD/dataset.json \
    --model_config outputs/EmbeddingsSize/${embedding_size}/model_config.json \
    --train_subjects ABCD_train_subjects.txt \
    --val_subjects ABCD_val_subjects.txt \
    --test_subjects ABCD_test_subjects.txt \
    --output_dir outputs/EmbeddingsSize/${embedding_size} \
    --verbose

# Detect the best checkpoint (highest epoch in the filename)
best_checkpoint=$(find outputs/EmbeddingsSize/${embedding_size}/checkpoints/ -name "checkpoint_epoch_*.pt" | sort -V | tail -n 1)

# Run the evaluation script (both on the train/val/test sets and on the external dataset GESTE and BANDA)
evaluate --dataset_config outputs/EmbeddingsSize/${embedding_size}/dataset_config.json \
    --model_config outputs/EmbeddingsSize/${embedding_size}/model_config.json \
    --train_subjects ABCD_train_subjects.txt \
    --val_subjects ABCD_val_subjects.txt \
    --test_subjects ABCD_test_subjects.txt \
    --output_dir outputs/EmbeddingsSize/${embedding_size}/evaluation_ABCD/ \
    --checkpoint_path ${best_checkpoint} \
    --checkpoint_dir outputs/EmbeddingsSize/${embedding_size}/ \
    --save_reconstruction_artifacts \
    --reconstruction_split test \
    --verbose

evaluate --dataset_config data/GESTE/dataset.json \
    --model_config outputs/EmbeddingsSize/${embedding_size}/model_config.json \
    --train_subjects GESTE_included_subjects.txt \
    --val_subjects GESTE_included_subjects.txt \
    --test_subjects GESTE_included_subjects.txt \
    --output_dir outputs/EmbeddingsSize/${embedding_size}/evaluation_GESTE/ \
    --checkpoint_path ${best_checkpoint} \
    --checkpoint_dir outputs/EmbeddingsSize/${embedding_size}/ \
    --refit_normalizer \
    --save_reconstruction_artifacts \
    --reconstruction_split test \
    --verbose

evaluate --dataset_config data/BANDA/dataset.json \
    --model_config outputs/EmbeddingsSize/${embedding_size}/model_config.json \
    --train_subjects BANDA_included_subjects.txt \
    --val_subjects BANDA_included_subjects.txt \
    --test_subjects BANDA_included_subjects.txt \
    --output_dir outputs/EmbeddingsSize/${embedding_size}/evaluation_BANDA/ \
    --checkpoint_path ${best_checkpoint} \
    --checkpoint_dir outputs/EmbeddingsSize/${embedding_size}/ \
    --refit_normalizer \
    --save_reconstruction_artifacts \
    --reconstruction_split test \
    --verbose
