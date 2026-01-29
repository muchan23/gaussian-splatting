# Gaussian Splatting Docker Image
# Tested configuration: Python 3.10 + PyTorch 2.5.1 + CUDA 12.4

FROM nvidia/cuda:12.4.1-devel-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    wget \
    curl \
    build-essential \
    cmake \
    ninja-build \
    libgl1-mesa-glx \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender-dev \
    libglew-dev \
    libassimp-dev \
    libboost-all-dev \
    libgtk-3-dev \
    libopencv-dev \
    libglfw3-dev \
    libavdevice-dev \
    libavcodec-dev \
    libeigen3-dev \
    libxxf86vm-dev \
    libembree-dev \
    imagemagick \
    colmap \
    && rm -rf /var/lib/apt/lists/*

# Install Miniconda
ENV CONDA_DIR=/opt/conda
RUN wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O /tmp/miniconda.sh \
    && bash /tmp/miniconda.sh -b -p $CONDA_DIR \
    && rm /tmp/miniconda.sh
ENV PATH=$CONDA_DIR/bin:$PATH

# Set working directory
WORKDIR /workspace/gaussian-splatting

# Create conda environment with Python 3.10 and PyTorch 2.5.1 + CUDA 12.4
RUN conda create -n gaussian_splatting python=3.10 -y \
    && conda run -n gaussian_splatting conda install -y \
        pytorch=2.5.1 \
        torchvision=0.20.1 \
        torchaudio=2.5.1 \
        pytorch-cuda=12.4 \
        cuda-toolkit=12.4 \
        cuda-nvcc=12.4 \
        plyfile \
        tqdm \
        -c pytorch -c nvidia -c conda-forge

# Install pip packages
RUN conda run -n gaussian_splatting pip install \
    opencv-python \
    joblib

# Copy all source code
COPY . .

# Initialize submodules if needed
RUN if [ -f .gitmodules ] && [ ! -d "submodules/diff-gaussian-rasterization/cuda_rasterizer" ]; then \
        git submodule update --init --recursive; \
    fi

# Build and install CUDA extensions with --no-build-isolation
ENV CUDA_HOME=/opt/conda/envs/gaussian_splatting
RUN conda run -n gaussian_splatting pip install --no-build-isolation ./submodules/diff-gaussian-rasterization \
    && conda run -n gaussian_splatting pip install --no-build-isolation ./submodules/simple-knn \
    && conda run -n gaussian_splatting pip install --no-build-isolation ./submodules/fused-ssim

# Verify installation
RUN conda run -n gaussian_splatting python -c "\
import torch; \
import diff_gaussian_rasterization; \
import simple_knn; \
import fused_ssim; \
print('All modules verified!')"

# Create directories for data and output
RUN mkdir -p /data /output

# Set environment variables
ENV NVIDIA_VISIBLE_DEVICES=all
ENV NVIDIA_DRIVER_CAPABILITIES=compute,utility,graphics

# Default command
CMD ["conda", "run", "--no-capture-output", "-n", "gaussian_splatting", "bash"]
