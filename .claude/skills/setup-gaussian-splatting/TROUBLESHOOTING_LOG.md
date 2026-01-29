# 環境構築トラブルシューティングログ

このドキュメントは、Gaussian Splatting の環境構築で発生した問題と解決過程を記録したものです。

## 環境情報

- OS: Ubuntu 24.04.3 LTS
- GPU: NVIDIA GeForce RTX 4090
- NVIDIA Driver: 580.95.05
- System CUDA: 13.0

## 試行1: オリジナルの environment.yml を使用

### 実行したコマンド

```bash
mamba env create --file environment.yml
```

### 発生したエラー

```
RuntimeError:
The detected CUDA version (13.0) mismatches the version that was used to compile
PyTorch (11.2). Please make sure to use the same CUDA versions.
```

### 原因分析

1. `environment.yml` は PyTorch 1.12.1 + CUDA 11.6 を指定
2. しかし、conda がインストールした PyTorch は CUDA 11.2 でビルドされていた
3. サブモジュールのビルド時、システムの nvcc (CUDA 13.0) が使用された
4. PyTorch の CUDA バージョン (11.2) と nvcc のバージョン (13.0) が不一致

### 学び

- PyTorch の `torch.version.cuda` とシステムの `nvcc --version` が一致する必要がある
- conda の cudatoolkit はランタイムのみで、nvcc（コンパイラ）は含まれない

## 試行2: CUDA 12.4 環境を作成

### 方針変更

1. Python 3.7 → 3.10 にアップグレード
2. PyTorch 1.12.1 → 2.5.1 にアップグレード
3. CUDA 11.6 → 12.4 にアップグレード
4. **重要**: `cuda-toolkit` と `cuda-nvcc` を conda からインストール

### 作成した environment_cuda12.yml

```yaml
name: gaussian_splatting
channels:
  - pytorch
  - nvidia
  - conda-forge
  - defaults
dependencies:
  - python=3.10
  - pip
  - pytorch=2.5.1
  - torchvision=0.20.1
  - torchaudio=2.5.1
  - pytorch-cuda=12.4
  - cuda-toolkit=12.4
  - cuda-nvcc=12.4
  - plyfile
  - tqdm
  - pip:
    - opencv-python
    - joblib
```

### 結果

- 環境作成は成功
- サブモジュールは別途ビルドが必要（pip でインストールするとビルド環境分離の問題）

## 試行3: サブモジュールのビルド

### 最初の試み

```bash
mamba run -n gaussian_splatting pip install ./submodules/diff-gaussian-rasterization
```

### 発生したエラー

```
ModuleNotFoundError: No module named 'torch'
```

### 原因

pip がビルド環境を分離（isolated build）しているため、現在の conda 環境の torch が見つからない

### 解決策

`--no-build-isolation` オプションを追加

```bash
mamba run -n gaussian_splatting pip install --no-build-isolation ./submodules/diff-gaussian-rasterization
```

### 結果

成功！3つのサブモジュールすべてがビルド完了

## 最終的な動作確認

```python
import torch
print(f'PyTorch: {torch.__version__}')          # 2.5.1.post303
print(f'CUDA available: {torch.cuda.is_available()}')  # True
print(f'GPU: {torch.cuda.get_device_name(0)}')  # NVIDIA GeForce RTX 4090

import diff_gaussian_rasterization  # ✓
import simple_knn                    # ✓
import fused_ssim                    # ✓
```

## 重要な発見

### 1. conda の CUDA パッケージの違い

| パッケージ | 内容 |
|-----------|------|
| `cudatoolkit` | ランタイムライブラリのみ（nvcc なし） |
| `cuda-toolkit` | 完全な CUDA Toolkit（nvcc 含む） |
| `cuda-nvcc` | nvcc コンパイラのみ |

### 2. CUDA バージョンの互換性

- NVIDIA Driver は後方互換性がある（新しいドライバーで古い CUDA コードを実行可能）
- しかし、**コンパイル時**は PyTorch のビルド CUDA バージョンと nvcc のバージョンが一致する必要がある
- conda から `cuda-nvcc` をインストールすることで、この問題を回避

### 3. pip の --no-build-isolation

- PEP 517 以降、pip はデフォルトでビルド環境を分離する
- CUDA 拡張のように `torch` に依存するパッケージは、現在の環境を使う必要がある
- `--no-build-isolation` で分離を無効化

## 推奨構成（2024年以降）

```
Python: 3.10+
PyTorch: 2.x
CUDA: 12.x（ドライバー 525.60+）
```

オリジナルの Python 3.7 + PyTorch 1.12.1 は古すぎるため、新規セットアップでは避けるべき。
