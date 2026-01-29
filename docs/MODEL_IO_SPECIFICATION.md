# Gaussian Splatting モデル 入出力仕様

このドキュメントは、3D Gaussian Splatting モデルの入力データ形式と出力データ形式を詳細に説明します。

## 入力データ

### 必要なディレクトリ構造

```
<scene_name>/
├── images/                 # 入力画像（必須）
│   ├── 000001.jpg
│   ├── 000002.jpg
│   └── ...
└── sparse/0/               # COLMAP データ（必須）
    ├── cameras.bin         # カメラ内部パラメータ
    ├── images.bin          # カメラ外部パラメータ
    └── points3D.bin        # 初期3D点群
```

### 入力画像

| 項目 | 仕様 |
|-----|------|
| 形式 | JPEG, PNG |
| 推奨枚数 | 50〜500枚 |
| 解像度 | 任意（高解像度ほどVRAM消費増） |
| 撮影条件 | 様々な角度から対象を撮影 |

### COLMAP データ

Structure from Motion (SfM) による3D再構成データ。

#### cameras.bin

カメラの内部パラメータ（intrinsics）を格納。

| フィールド | 説明 |
|-----------|------|
| camera_id | カメラID |
| model | カメラモデル（PINHOLE, SIMPLE_PINHOLE等） |
| width | 画像幅 |
| height | 画像高さ |
| params | fx, fy, cx, cy 等 |

#### images.bin

各画像のカメラ外部パラメータ（extrinsics）を格納。

| フィールド | 説明 |
|-----------|------|
| image_id | 画像ID |
| qvec | 回転（クォータニオン） |
| tvec | 並進ベクトル |
| camera_id | 対応するカメラID |
| name | 画像ファイル名 |

#### points3D.bin

初期3D点群データ。

| フィールド | 説明 |
|-----------|------|
| point3D_id | 点ID |
| xyz | 3D座標 |
| rgb | 色情報 |
| error | 再投影誤差 |
| track | 観測した画像リスト |

### 入力点群（input.ply）

学習開始時に COLMAP の points3D.bin から変換される点群。

```
ply
format binary_little_endian 1.0
element vertex 136029
property float x          # X座標
property float y          # Y座標
property float z          # Z座標
property float nx         # 法線X（使用されない）
property float ny         # 法線Y（使用されない）
property float nz         # 法線Z（使用されない）
property uchar red        # 赤
property uchar green      # 緑
property uchar blue       # 青
end_header
```

## 出力データ

### 出力ディレクトリ構造

```
output/<scene_name>/
├── point_cloud/
│   └── iteration_<N>/
│       └── point_cloud.ply    # 学習済み3Dガウシアンモデル
├── cameras.json               # カメラパラメータ（JSON形式）
├── cfg_args                   # 学習設定
├── exposure.json              # 露出補正データ
├── input.ply                  # 入力点群（コピー）
├── train/                     # レンダリング結果（学習セット）
│   └── ours_<iteration>/
│       ├── renders/           # レンダリング画像
│       └── gt/                # Ground Truth画像
└── test/                      # レンダリング結果（テストセット）
    └── ours_<iteration>/
        ├── renders/
        └── gt/
```

### 3D Gaussian モデル（point_cloud.ply）

学習済みの3Dガウシアン表現。各ガウシアンは以下のプロパティを持つ。

```
ply
format binary_little_endian 1.0
element vertex 1696149          # ガウシアン数
property float x                # 位置 X
property float y                # 位置 Y
property float z                # 位置 Z
property float nx               # 法線 X（未使用）
property float ny               # 法線 Y（未使用）
property float nz               # 法線 Z（未使用）
property float f_dc_0           # 球面調和関数 DC成分 (R)
property float f_dc_1           # 球面調和関数 DC成分 (G)
property float f_dc_2           # 球面調和関数 DC成分 (B)
property float f_rest_0         # 球面調和関数 高次成分 0
property float f_rest_1         # 球面調和関数 高次成分 1
...
property float f_rest_44        # 球面調和関数 高次成分 44
property float opacity          # 不透明度
property float scale_0          # スケール X
property float scale_1          # スケール Y
property float scale_2          # スケール Z
property float rot_0            # 回転 クォータニオン w
property float rot_1            # 回転 クォータニオン x
property float rot_2            # 回転 クォータニオン y
property float rot_3            # 回転 クォータニオン z
end_header
```

#### プロパティ詳細

| カテゴリ | プロパティ数 | 説明 |
|---------|------------|------|
| 位置 | 3 (x, y, z) | 3D空間でのガウシアン中心位置 |
| 法線 | 3 (nx, ny, nz) | 未使用（互換性のため保持） |
| 色（DC） | 3 (f_dc_0〜2) | 球面調和関数のDC成分（基本色） |
| 色（高次） | 45 (f_rest_0〜44) | 球面調和関数の高次成分（視点依存色） |
| 不透明度 | 1 (opacity) | シグモイド活性化前の値 |
| スケール | 3 (scale_0〜2) | 対数スケール（exp適用前） |
| 回転 | 4 (rot_0〜3) | クォータニオン（正規化前） |

#### サイズの目安

| ガウシアン数 | ファイルサイズ |
|-------------|--------------|
| 100万 | 約240 MB |
| 170万 | 約400 MB |
| 300万 | 約720 MB |

### カメラパラメータ（cameras.json）

各カメラの内部・外部パラメータをJSON形式で格納。

```json
[
  {
    "id": 0,
    "img_name": "000001.jpg",
    "width": 1957,
    "height": 1091,
    "position": [3.398, 0.683, -2.299],
    "rotation": [
      [0.786, -0.016, -0.617],
      [-0.028, 0.997, -0.063],
      [0.617, 0.067, 0.783]
    ],
    "fx": 1163.25,
    "fy": 1156.28
  },
  ...
]
```

| フィールド | 型 | 説明 |
|-----------|-----|------|
| id | int | カメラID |
| img_name | string | 画像ファイル名 |
| width | int | 画像幅 |
| height | int | 画像高さ |
| position | float[3] | カメラ位置（ワールド座標） |
| rotation | float[3][3] | 回転行列 |
| fx | float | 焦点距離 X |
| fy | float | 焦点距離 Y |

### 学習設定（cfg_args）

学習時のコマンドライン引数を保存。

```python
Namespace(
    sh_degree=3,                    # 球面調和関数の次数
    source_path='data/tandt/truck', # データセットパス
    model_path='output/truck',      # 出力パス
    images='images',                # 画像ディレクトリ名
    resolution=-1,                  # 解像度（-1=自動）
    white_background=False,         # 白背景フラグ
    eval=False                      # 評価モードフラグ
)
```

### レンダリング画像

| 項目 | 仕様 |
|-----|------|
| 形式 | PNG |
| 色深度 | 8bit RGB |
| 解像度 | 入力画像と同一 |
| 命名規則 | `%05d.png` (00000.png, 00001.png, ...) |

## データフロー図

```
┌─────────────────────────────────────────────────────────────┐
│                        入力                                  │
├─────────────────────────────────────────────────────────────┤
│  images/              sparse/0/                              │
│  ├── *.jpg  ───────►  ├── cameras.bin                       │
│  └── *.png            ├── images.bin                        │
│                       └── points3D.bin                      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      train.py                                │
│  ・初期点群からガウシアン初期化                              │
│  ・微分可能レンダリング                                      │
│  ・密度制御（Densification）                                │
│  ・最適化（位置、色、スケール、回転、不透明度）              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                        出力                                  │
├─────────────────────────────────────────────────────────────┤
│  point_cloud/iteration_N/                                    │
│  └── point_cloud.ply    ← 3Dガウシアンモデル                │
│                                                              │
│  cameras.json           ← カメラパラメータ                  │
│  cfg_args               ← 学習設定                          │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      render.py                               │
│  ・学習済みモデルをロード                                    │
│  ・各カメラ視点からレンダリング                              │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                    レンダリング結果                          │
├─────────────────────────────────────────────────────────────┤
│  train/ours_N/renders/   ← レンダリング画像                 │
│  train/ours_N/gt/        ← Ground Truth                     │
└─────────────────────────────────────────────────────────────┘
```

## 参考

- [3D Gaussian Splatting 論文](https://repo-sam.inria.fr/fungraph/3d-gaussian-splatting/)
- [COLMAP ドキュメント](https://colmap.github.io/)
- [PLY ファイル形式](https://paulbourke.net/dataformats/ply/)
