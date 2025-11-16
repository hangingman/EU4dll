# プロジェクト概要

このプロジェクトは、Paradox Interactive社のゲーム「Europa Universalis IV」において、日本語などの2バイト文字を正しく表示させるためのDLL（ダイナミックリンクライブラリ）です。

## 主な機能

-   ゲーム内のテキスト描画処理に介入し、2バイト文字のレンダリングを可能にします。

## プロジェクトの目的

元々C++で書かれておりWindowsでしか動作しないこのDLLを、Linux環境でも動作するようにし、将来的にはD言語で書き直すことを目指しています。

## ライセンス

MITライセンスです。

## 謝辞

このプロジェクトは、[matanki-saito/EU4dll](https://github.com/matanki-saito/EU4dll) をフォークしたものです。
