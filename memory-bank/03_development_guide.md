# 開発ガイド

このドキュメントでは、プロジェクトの開発環境のセットアップ方法について説明します。

## D言語およびDubのセットアップ

このプロジェクトはD言語で記述されており、パッケージ管理にはDubを使用しています。
以下の手順でD言語コンパイラとDubをセットアップします。

### 1. D言語コンパイラのインストール

D言語コンパイラにはDMD, GDC, LDCがありますが、本プロジェクトではDMDを推奨します。
以下のコマンドでDMDをインストールします。

```bash
curl -fsSL https://dlang.org/install.sh | bash -s dmd
```

インストール後、環境変数を設定するためにシェルを再起動するか、以下のコマンドを実行します。

```bash
source ~/dlang/dmd-2.x.x/activate
```
(2.x.x はインストールされたDMDのバージョンに置き換えてください)

### 2. Dubのインストール

Dubは通常、DMDのインストール時に一緒にインストールされます。
もしDubがインストールされていない場合は、以下のコマンドでインストールできます。

```bash
curl -fsSL https://dlang.org/install.sh | bash -s dub
```

### 3. バージョンの確認

インストール後、以下のコマンドでDMDとDubのバージョンを確認します。

#### DMDのバージョン

```bash
dmd --version
```

**現在の環境での確認結果:**
```
DMD64 D Compiler v2.111.0
Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved written by Walter Bright
```

#### Dubのバージョン

```bash
dub --version
```

**現在の環境での確認結果:**
```
DUB version 1.40.0-1, built on May  3 2025
```

### 4. プロジェクトのビルド

プロジェクトのルートディレクトリで以下のコマンドを実行すると、Dubが依存関係を解決し、プロジェクトをビルドします。

```bash
dub build
```

**ビルドの確認:**
`Makefile` の `all` ターゲットを実行することでビルドが可能です。

```bash
make all
```

上記コマンド実行後、エラーが表示されずに完了すれば、ビルドは成功です。
