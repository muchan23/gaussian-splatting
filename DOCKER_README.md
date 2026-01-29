# Gaussian Splatting - Docker Setup

Docker を使用して Gaussian Splatting 環境を簡単に構築できます。

## 動作確認済み環境

- Python 3.10
- PyTorch 2.5.1
- CUDA 12.4
- RTX 4090 (Compute Capability 8.9)

## 前提条件

- Docker (20.10+)
- Docker Compose (v2.0+)
- NVIDIA GPU (Compute Capability 7.0+)
- NVIDIA Driver 525.60+ (CUDA 12.x 対応)
- NVIDIA Container Toolkit

### NVIDIA Container Toolkit のインストール

```bash
# Ubuntu/Debian
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
  sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
  sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
sudo apt-get update
sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker
```

## クイックスタート

### 1. イメージのビルド

```bash
docker compose build
```

### 2. インタラクティブシェルで使用

```bash
docker compose run --rm gaussian-splatting
```

コンテナ内で:
```bash
# 学習
python train.py -s /data -m /output/my_model

# レンダリング
python render.py -m /output/my_model

# 評価
python metrics.py -m /output/my_model
```

## データの準備

`data/` ディレクトリにデータセットを配置してください。

### COLMAP形式

```
data/
├── images/
│   ├── IMG_001.jpg
│   ├── IMG_002.jpg
│   └── ...
└── sparse/
    └── 0/
        ├── cameras.bin
        ├── images.bin
        └── points3D.bin
```

### 画像のみの場合（COLMAP処理）

```bash
docker compose run --rm gaussian-splatting python convert.py -s /data
```

## 使用例

### 基本的な学習

```bash
docker compose run --rm gaussian-splatting \
  python train.py -s /data -m /output/my_model
```

### 高品質学習（推奨設定）

```bash
docker compose run --rm gaussian-splatting \
  python train.py \
  -s /data \
  -m /output/my_model \
  --iterations 30000 \
  --densify_until_iter 15000 \
  --test_iterations 7000 15000 30000
```

### リアルタイムビューア接続

ホストから接続可能（ポート6009）:
```bash
docker compose run --rm gaussian-splatting \
  python train.py -s /data -m /output/my_model --ip 0.0.0.0
```

### レンダリング

```bash
docker compose run --rm gaussian-splatting \
  python render.py -m /output/my_model
```

### メトリクス計算

```bash
docker compose run --rm gaussian-splatting \
  python metrics.py -m /output/my_model
```

## GPU メモリに関する注意

- フル解像度学習には24GB VRAM推奨
- VRAMが少ない場合は `--resolution 2` で画像を1/2にダウンスケール

## トラブルシューティング

### GPU が認識されない

```bash
# NVIDIA Container Toolkitの確認
docker run --rm --gpus all nvidia/cuda:11.6.2-base-ubuntu20.04 nvidia-smi
```

### ビルドエラー

```bash
# キャッシュなしで再ビルド
docker compose build --no-cache
```

### CUDA メモリ不足

```bash
# 解像度を下げて実行
python train.py -s /data -m /output/model --resolution 2
```

## ディレクトリ構造

```
gaussian-splatting/
├── Dockerfile          # Dockerイメージ定義
├── docker-compose.yml  # Compose設定
├── .dockerignore       # ビルド除外設定
├── data/               # 入力データセット（マウント）
├── output/             # 出力モデル（マウント）
└── ...
```
