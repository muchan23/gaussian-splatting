#!/bin/bash
# Gaussian Splatting Setup Script
# Tested: Python 3.10 + PyTorch 2.5.1 + CUDA 12.4

set -e

ENV_NAME="gaussian_splatting"

echo "=== Gaussian Splatting Environment Setup ==="

# Check for conda/mamba
if command -v mamba &> /dev/null; then
    CONDA_CMD="mamba"
elif command -v conda &> /dev/null; then
    CONDA_CMD="conda"
else
    echo "Error: conda or mamba not found. Please install Miniconda/Anaconda first."
    exit 1
fi

echo "Using: $CONDA_CMD"

# Check if environment already exists
if $CONDA_CMD env list | grep -q "^$ENV_NAME "; then
    echo "Environment '$ENV_NAME' already exists."
    read -p "Remove and recreate? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        $CONDA_CMD env remove -n $ENV_NAME -y
    else
        echo "Aborting."
        exit 1
    fi
fi

echo ""
echo "=== Creating conda environment ==="
$CONDA_CMD create -n $ENV_NAME python=3.10 -y

echo ""
echo "=== Installing PyTorch and CUDA toolkit ==="
$CONDA_CMD run -n $ENV_NAME $CONDA_CMD install -y \
    pytorch=2.5.1 \
    torchvision=0.20.1 \
    torchaudio=2.5.1 \
    pytorch-cuda=12.4 \
    cuda-toolkit=12.4 \
    cuda-nvcc=12.4 \
    plyfile \
    tqdm \
    -c pytorch -c nvidia -c conda-forge

echo ""
echo "=== Installing pip packages ==="
$CONDA_CMD run -n $ENV_NAME pip install opencv-python joblib

echo ""
echo "=== Initializing git submodules ==="
if [ -f .gitmodules ]; then
    git submodule update --init --recursive
fi

echo ""
echo "=== Building CUDA extensions ==="
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

$CONDA_CMD run -n $ENV_NAME pip install --no-build-isolation "$SCRIPT_DIR/submodules/diff-gaussian-rasterization"
$CONDA_CMD run -n $ENV_NAME pip install --no-build-isolation "$SCRIPT_DIR/submodules/simple-knn"
$CONDA_CMD run -n $ENV_NAME pip install --no-build-isolation "$SCRIPT_DIR/submodules/fused-ssim"

echo ""
echo "=== Verifying installation ==="
$CONDA_CMD run -n $ENV_NAME python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
import diff_gaussian_rasterization
import simple_knn
import fused_ssim
print('All CUDA extensions loaded successfully!')
"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Activate the environment with:"
echo "  conda activate $ENV_NAME"
echo ""
echo "Run training with:"
echo "  python train.py -s <path_to_data> -m <output_path>"
