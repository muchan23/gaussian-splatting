---
name: train-gaussian-splatting
description: Gaussian Splattingの学習と推論（レンダリング）を実行する。データセットのダウンロード、学習、レンダリング、結果確認までの一連の流れを案内する。
---

# Gaussian Splatting 学習・推論スキル

このスキルは、環境構築完了後の学習と推論のワークフローをまとめたものです。

## 前提条件

- conda 環境 `gaussian_splatting` が構築済みであること
- CUDA 拡張モジュール（diff-gaussian-rasterization, simple-knn, fused-ssim）がビルド済みであること

## データセットの準備

### 公式サンプルデータセット

| データセット | サイズ | 内容 |
|-------------|-------|------|
| [T&T+DB COLMAP](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/datasets/input/tandt_db.zip) | 650MB | truck, train, drjohnson, playroom |
| [Mip-NeRF360](http://storage.googleapis.com/gresearch/refraw360/360_v2.zip) | 12GB | garden, bicycle, etc. |

### ダウンロードと展開

```bash
mkdir -p data && cd data
wget https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/datasets/input/tandt_db.zip
unzip tandt_db.zip
```

### データセット構造

```
data/
├── tandt/
│   ├── truck/
│   │   ├── images/      ← 入力画像
│   │   └── sparse/0/    ← COLMAPデータ
│   └── train/
└── db/
    ├── drjohnson/
    └── playroom/
```

## 学習の実行

### 基本コマンド

```bash
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  python train.py -s data/tandt/truck -m output/truck
```

### 主要なオプション

| オプション | デフォルト | 説明 |
|-----------|-----------|------|
| `-s` | 必須 | データセットのパス |
| `-m` | 必須 | 出力先のパス |
| `--iterations` | 30000 | 学習イテレーション数 |
| `--resolution` | -1 | 画像解像度（-1=自動、2=1/2サイズ） |
| `--eval` | false | テストセット分割を有効化 |

### 短時間での動作確認

```bash
# 7000イテレーションで約3分（RTX 4090）
python train.py -s data/tandt/truck -m output/truck --iterations 7000
```

### 高品質学習

```bash
# 30000イテレーションで約15分
python train.py -s data/tandt/truck -m output/truck --iterations 30000
```

## レンダリング（推論）

### 基本コマンド

```bash
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  python render.py -m output/truck
```

### 出力先

```
output/truck/
├── train/ours_<iteration>/
│   ├── renders/    ← レンダリング結果
│   └── gt/         ← Ground Truth（元画像）
└── test/ours_<iteration>/
    ├── renders/
    └── gt/
```

## メトリクス計算

```bash
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  python metrics.py -m output/truck
```

出力例：
```
PSNR: 25.xx
SSIM: 0.8x
LPIPS: 0.1x
```

## 結果の確認

### ファイル構成

```
output/<scene_name>/
├── point_cloud/
│   └── iteration_<N>/
│       └── point_cloud.ply    ← 3Dガウシアンモデル
├── train/ours_<N>/
│   ├── renders/               ← レンダリング画像（PNG）
│   └── gt/                    ← 元画像
├── cameras.json               ← カメラパラメータ
├── cfg_args                   ← 学習設定
└── input.ply                  ← 入力点群
```

### 画像の確認

```bash
# レンダリング結果
ls output/truck/train/ours_7000/renders/

# 枚数確認
ls output/truck/train/ours_7000/renders/ | wc -l
```

## トラブルシューティング

### torchvision インポートエラー

```
RuntimeError: operator torchvision::nms does not exist
```

**原因**: conda の PyTorch/torchvision パッケージの互換性問題

**解決策**: pip から PyTorch を再インストール

```bash
mamba run -n gaussian_splatting pip uninstall torch torchvision torchaudio -y
mamba run -n gaussian_splatting pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
```

### CUDA バージョン不一致

```
RuntimeError: The detected CUDA version (13.0) mismatches the version that was used to compile PyTorch (12.4)
```

**解決策**: `CUDA_HOME` を conda 環境のパスに設定

```bash
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting pip install --no-build-isolation ./submodules/diff-gaussian-rasterization
```

### メモリ不足

```bash
# 解像度を下げて実行
python train.py -s data/tandt/truck -m output/truck --resolution 2
```

## 完全なワークフロー例

```bash
# 1. データセットダウンロード
cd /workspace/gaussian-splatting
mkdir -p data && cd data
wget https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/datasets/input/tandt_db.zip
unzip tandt_db.zip
cd ..

# 2. 学習
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  python train.py -s data/tandt/truck -m output/truck --iterations 7000

# 3. レンダリング
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  python render.py -m output/truck

# 4. 結果確認
ls output/truck/train/ours_7000/renders/
```
