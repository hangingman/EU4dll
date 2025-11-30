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

## 4. 翻訳ファイルの展開 (オプション)

本リポジトリは、`EU4JPModAppendixI`サブモジュールを利用して、翻訳ソースから翻訳MODファイルを生成できます。

`Makefile`には、生成されたYAML翻訳ファイルをEU4のMODディレクトリにコピーするための`deploy_translations`ターゲットが含まれています。

```bash
make deploy_translations
```

**前提条件:**
このコマンドを実行する前に、`submodules/EU4JPModAppendixI/`ディレクトリ内で`main.py`スクリプトを実行し、翻訳ファイル (`submodules/EU4JPModAppendixI/source/localisation/`内) を生成しておく必要があります。`main.py`の実行にはPython環境と`PARATRANZ_SECRET`環境変数が必要です。詳細はサブモジュールのドキュメントを参照してください。
