# 開発ガイド

このドキュメントでは、プロジェクトの開発環境のセットアップ方法について説明します。

## 1. D言語コンパイラとGitのインストール

### D言語コンパイラ (LDC)

本プロジェクトでは、DMDではなくLDC (LLVM D Compiler) の使用を必須とします。LDCは大規模なプロジェクトにおいて、より優れた最適化と安定性を提供します。

以下のコマンドでLDCをインストールします。
```bash
curl -fsSL https://dlang.org/install.sh | bash -s ldc
```

インストール後、環境変数を設定するためにシェルを再起動するか、以下のコマンドを実行します。
```bash
source ~/dlang/ldc-x.y.z/activate
```
(`x.y.z` はインストールされたLDCのバージョンに置き換えてください)

### Git

バージョン管理システムとしてGitが必要です。お使いのディストリビューションのパッケージマネージャでインストールしてください。

## 2. リポジトリのセットアップ

### リポジトリのクローンとサブモジュールの初期化

本プロジェクトはGitのサブモジュールを利用しています。リポジトリをクローンする際は、`--recursive`オプションを使用してください。

```bash
git clone --recursive https://github.com/hangingman/EU4dll.git
cd EU4dll
```

すでにクローン済みの場合は、以下のコマンドでサブモジュールを初期化・更新できます。
```bash
git submodule update --init --recursive
```

## 3. プロジェクトのビルド

プロジェクトのルートディレクトリで以下のコマンドを実行すると、LDCを使用してプロジェクトがビルドされます。

```bash
make all
```

`Makefile`は内部で`dub build --compiler=ldc2`を実行します。エラーが表示されずに完了すれば、ビルドは成功です。

## 4. 翻訳ファイルの展開とMODとしての配置 (オプション)

本プロジェクトでは、`EU4JPModAppendixI`サブモジュールを利用して翻訳ソースから翻訳MODファイルを生成し、EU4のランチャーに認識される形式で配置できます。

### MODのフォルダ構成と配置

EU4のランチャーに翻訳ファイルを認識させるには、`ドキュメント/Paradox Interactive/Europa Universalis IV/mod/` フォルダ内に、以下の2つを配置する必要があります。

1.  **`.mod` ファイル**（目次ファイル）: ランチャーが最初に読み込むファイルです。「このMODはここにありますよ」という情報が書かれています。
2.  **MOD本体のフォルダ**: この中に実際の翻訳データ（`localisation`フォルダ）を入れます。

**構成例:**

```text
ドキュメント/Paradox Interactive/Europa Universalis IV/mod/
 │
 ├─ my_japanese_mod.mod  <-- (A) ランチャーが読む目次
 │
 └─ my_japanese_mod/     <-- (B) MODの中身
     └─ localisation/
         └─ replace/     <-- (任意) バニラの訳を完全に上書きしたい場合
             └─ jp_text_l_english.yml  <-- (C) 実際の翻訳ファイル
```

### `.mod` ファイルの記述例

`my_japanese_mod.mod` の中身は以下のようになります。`name`はランチャーに表示されるMOD名、`path`はMOD本体フォルダへの相対パスです。

```ini
name="EU4dll Japanese Translation"
path="mod/eu4dll_translations" # EU4ゲームディレクトリからの相対パス（「mod/」プレフィックスを含む）
supported_version="1.37.5" # 完全一致のバージョン番号を二重引用符で指定
```

### `.yml` 翻訳ファイルの記述ルール

実際の翻訳データ (`jp_text_l_english.yml`など) は、以下のルールに従って記述する必要があります。

*   **文字コード**: UTF-8 (BOMなしで推奨、ただし環境によってはBOM付きが必要な場合あり) で保存してください。
*   **ヘッダー**: 1行目はほとんど言語タグ（例: `l_english:`）で始める必要があります。
*   **キー**: `元の英語のキー:0 "翻訳した日本語"` という形式で書きます。

**記述例:**

```yaml
l_english:
 CORE_PROVINCE:0 "中核州"
 MDEATH_HEIR_SUCCEEDS:0 "[Root.Heir.GetName]が[Root.Monarch.GetName]の後を継承した。"
```

### `deploy_translations` ターゲットの実行

`Makefile`には、上記MOD構成を自動で作成・配置する`deploy_translations`ターゲットが含まれています。

```bash
make deploy_translations
```

**前提条件:**
このコマンドを実行する前に、`submodules/EU4JPModAppendixI/`ディレクトリ内で`main.py`スクリプトを実行し、翻訳ファイル (`submodules/EU4JPModAppendixI/source/localisation/`内) を生成しておく必要があります。`main.py`の実行にはPython環境と`PARATRANZ_SECRET`環境変数が必要です。詳細はサブモジュールのドキュメントを参照してください。
