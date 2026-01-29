---
name: setup-gaussian-splatting
description: Gaussian Splattingプロジェクトの環境構築を行う。CUDA拡張のビルドエラーが発生した場合のトラブルシューティングも含む。
---

# Gaussian Splatting 環境構築スキル

このスキルは、3D Gaussian Splatting プロジェクトの環境構築手順と、発生しやすい問題の解決方法をまとめたものです。

## 背景

オリジナルの `environment.yml` は古い構成（Python 3.7 + PyTorch 1.12.1 + CUDA 11.6）を使用しており、最新の NVIDIA ドライバー環境では CUDA バージョンの不一致エラーが発生します。

## よくあるエラーと原因

### エラー1: CUDA バージョン不一致

```
RuntimeError: The detected CUDA version (13.0) mismatches the version that was used to compile PyTorch (11.2).
```

**原因**: システムの CUDA ドライバーと PyTorch のビルド時 CUDA バージョンが異なる

**解決策**: PyTorch と CUDA toolkit を一致させた環境を使用する

### エラー2: torch モジュールが見つからない

```
ModuleNotFoundError: No module named 'torch'
```

**原因**: pip がビルド環境を分離しているため、PyTorch が見つからない

**解決策**: `--no-build-isolation` オプションを使用する

## 推奨環境構築手順

### 方法1: setup.sh スクリプト（推奨）

```bash
./setup.sh
```

### 方法2: 手動セットアップ

```bash
# 1. Conda 環境を作成（Python 3.10）
conda create -n gaussian_splatting python=3.10 -y

# 2. PyTorch + CUDA toolkit をインストール
conda install -n gaussian_splatting -y \
    pytorch=2.5.1 \
    torchvision=0.20.1 \
    torchaudio=2.5.1 \
    pytorch-cuda=12.4 \
    cuda-toolkit=12.4 \
    cuda-nvcc=12.4 \
    plyfile tqdm \
    -c pytorch -c nvidia -c conda-forge

# 3. pip パッケージをインストール
conda run -n gaussian_splatting pip install opencv-python joblib

# 4. Git サブモジュールを初期化
git submodule update --init --recursive

# 5. CUDA 拡張をビルド（--no-build-isolation が重要）
conda run -n gaussian_splatting pip install --no-build-isolation ./submodules/diff-gaussian-rasterization
conda run -n gaussian_splatting pip install --no-build-isolation ./submodules/simple-knn
conda run -n gaussian_splatting pip install --no-build-isolation ./submodules/fused-ssim
```

### 方法3: Docker

```bash
docker compose build
docker compose run --rm gaussian-splatting
```

## 動作確認

```bash
conda run -n gaussian_splatting python -c "
import torch
print(f'PyTorch: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
import diff_gaussian_rasterization
import simple_knn
import fused_ssim
print('All modules OK!')
"
```

## 重要なポイント

1. **conda から cuda-nvcc をインストール**: システムの nvcc ではなく、conda 環境内の nvcc を使うことで、PyTorch との CUDA バージョンを一致させる

2. **--no-build-isolation オプション**: CUDA 拡張のビルド時に現在の環境を使用させる

3. **Python 3.10 推奨**: Python 3.7 は古すぎて、最新の PyTorch と互換性がない

4. **CUDA 12.4 推奨**: 最新の NVIDIA ドライバー（525.60+）と互換性がある

## ファイル構成

```
gaussian-splatting/
├── Dockerfile              # Docker イメージ定義
├── docker-compose.yml      # Compose 設定
├── .dockerignore           # ビルド除外設定
├── DOCKER_README.md        # Docker 使用ガイド
├── environment.yml         # オリジナル（古い）
├── environment_cuda12.yml  # CUDA 12.4 対応版
├── setup.sh                # セットアップスクリプト
└── submodules/
    ├── diff-gaussian-rasterization/
    ├── simple-knn/
    └── fused-ssim/
```

## トラブルシューティング

### GPU が認識されない

```bash
nvidia-smi  # ドライバー確認
python -c "import torch; print(torch.cuda.is_available())"
```

### メモリ不足

```bash
# 解像度を下げて実行
python train.py -s /data -m /output --resolution 2
```

### サブモジュールが空

```bash
git submodule update --init --recursive
```
