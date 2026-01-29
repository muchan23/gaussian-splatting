# 学習・推論ワークフローログ

このドキュメントは、Gaussian Splatting の学習と推論を実行した際の試行錯誤を記録したものです。

## 環境情報

- GPU: NVIDIA GeForce RTX 4090 (48GB VRAM)
- PyTorch: 2.6.0+cu124（pip からインストール）
- CUDA: 12.4

## Step 1: データセットのダウンロード

### 試行1: Mip-NeRF360 データセット

```bash
wget https://storage.googleapis.com/gresearch/refraw360/360_v2/garden.zip
```

**結果**: 404 Not Found（URLが変更されていた）

### 試行2: 公式ページからURL確認

公式ページ（https://jonbarron.info/mipnerf360/）を確認し、正しいURLを発見：
- `http://storage.googleapis.com/gresearch/refraw360/360_v2.zip`（12GB）

### 試行3: T&T+DB データセット（成功）

サイズが小さい公式サンプルデータセットを選択：

```bash
wget https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/datasets/input/tandt_db.zip
unzip tandt_db.zip
```

**結果**: 成功（650MB、4シーン含む）

### 学び

- 公式 README に記載のデータセットを使用するのが確実
- T&T+DB は動作確認に最適なサイズ

## Step 2: 学習の実行

### 試行1: 基本コマンド

```bash
mamba run -n gaussian_splatting python train.py \
  -s data/tandt/truck \
  -m output/truck \
  --iterations 7000
```

**結果**: 成功

- 251枚の画像を読み込み
- 約3分で学習完了
- 402MB の point_cloud.ply を生成

### 出力ログ

```
Optimizing output/truck
Reading camera 1/251...251/251
Number of points at initialization: 205373
Training progress: 7000 [約3分]
Saving Gaussians
```

## Step 3: レンダリング（推論）

### 試行1: 基本コマンド

```bash
mamba run -n gaussian_splatting python render.py -m output/truck
```

**結果**: エラー

```
RuntimeError: operator torchvision::nms does not exist
```

### 原因分析

conda からインストールした torchvision に互換性の問題があった。
PyTorch 2.5.1 と torchvision 0.20.1 の conda パッケージ間で不整合が発生。

### 試行2: torchvision 再インストール（失敗）

```bash
mamba install -n gaussian_splatting --force-reinstall torchvision=0.20.1
```

**結果**: 同じエラーが継続

### 試行3: pip から PyTorch 再インストール（成功）

```bash
# 環境を作り直し
mamba env remove -n gaussian_splatting -y
mamba create -n gaussian_splatting python=3.10 -y

# pip から PyTorch をインストール
mamba run -n gaussian_splatting pip install torch torchvision torchaudio \
  --index-url https://download.pytorch.org/whl/cu124

# その他の依存関係
mamba run -n gaussian_splatting pip install plyfile tqdm opencv-python joblib

# nvcc をインストール
mamba install -n gaussian_splatting -y cuda-nvcc=12.4 -c nvidia

# サブモジュールを再ビルド
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  pip install --no-build-isolation \
  ./submodules/diff-gaussian-rasterization \
  ./submodules/simple-knn \
  ./submodules/fused-ssim
```

**結果**: 成功

### 試行4: レンダリング再実行（成功）

```bash
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting \
  python render.py -m output/truck
```

**結果**: 成功
- 251枚の画像をレンダリング
- 約1分40秒で完了

## 重要な発見

### 1. conda vs pip の問題

| 方法 | PyTorch | torchvision | 結果 |
|-----|---------|-------------|------|
| conda | 2.5.1.post303 | 0.20.1 | ❌ torchvision エラー |
| pip | 2.6.0+cu124 | 0.21.0+cu124 | ✅ 正常動作 |

**結論**: pip から PyTorch をインストールする方が安定

### 2. CUDA_HOME の設定

pip から PyTorch をインストールした場合でも、サブモジュールのビルド時には `CUDA_HOME` の設定が必要：

```bash
CUDA_HOME=/venv/gaussian_splatting mamba run -n gaussian_splatting ...
```

### 3. 学習時間の目安（RTX 4090）

| イテレーション | 時間 | 品質 |
|--------------|------|------|
| 7,000 | 約3分 | 動作確認用 |
| 30,000 | 約15分 | 論文品質 |

### 4. 出力ファイルの場所

```
output/<scene>/
├── point_cloud/iteration_<N>/point_cloud.ply  ← モデル
├── train/ours_<N>/renders/                    ← レンダリング結果
└── train/ours_<N>/gt/                         ← 元画像
```

## 最終的な動作確認済みワークフロー

```bash
# 環境変数設定
export CUDA_HOME=/venv/gaussian_splatting

# 学習
mamba run -n gaussian_splatting python train.py \
  -s data/tandt/truck -m output/truck --iterations 7000

# レンダリング
mamba run -n gaussian_splatting python render.py -m output/truck

# 結果確認
ls output/truck/train/ours_7000/renders/ | wc -l  # → 251
```
