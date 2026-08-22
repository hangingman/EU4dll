# EU4 Linux ランタイム追跡手順

## 目的

`MENU_BAR_LOAD_GAME` が `translationMap` にロードされた後、EU4本体でどの関数を通って表示準備へ渡されるかを観測する。追跡はGDBのブレークポイントとスタック表示だけで行い、本体の命令・データを書き換えない。

## 再現手順

1. EU4を終了し、対象バイナリの場所を確認する。
2. 翻訳Modを有効にし、`MENU_BAR_LOAD_GAME` が表示されるメニューへ到達できる状態にする。
3. リポジトリルートで次を実行する。

```sh
EU4_BIN="$HOME/.steam/debian-installation/steamapps/common/Europa Universalis IV/eu4" \
  ./tools/trace_eu4_runtime.sh 2>&1 | tee runtime-trace.log
```

必要な起動引数はスクリプトの末尾に追加する。

```sh
EU4_BIN=/path/to/eu4 ./tools/trace_eu4_runtime.sh -- -arg value
```

4. ゲームを通常どおり起動し、対象メニューを操作する。
5. `TRACE symbol=...`、`tid`、レジスタ、`bt` の出力を保存する。呼び出しが多い場合は、対象メニューへ到達するまでのログと到達後のログを分ける。

## 観測対象

`readelf -Ws` でEU4 v1.37.5に存在することを確認したシンボルを候補にする。

| シンボル | 現時点で言える役割 | 未確認事項 |
| --- | --- | --- |
| `LocalizeAddLocalization` | localisation登録処理とみられる本体シンボル | `MENU_BAR_LOAD_GAME` の登録時に呼ばれるか、引数の型と所有権 |
| `LocalizeAddLocalizationYAMLBuffer` | YAMLバッファを受けるlocalisation登録関連シンボル | 登録済み値から表示値を生成する経路との関係 |
| `YmlParse` | YAML構文解析シンボル | 翻訳Modのロード時に本体が呼ぶか、コールバック引数の意味 |
| `PdxLocalizeInitialize` / `ReloadPdxLocalize` | localisation機構の初期化・再ロード関連シンボル | 通常のメニュー表示時の呼び出し頻度 |
| `CTextBox::ChangeTextBox` | テキストボックス更新シンボル | 一般メニューの文字列を受け取るか、文字コード・バッファ形式 |

`PdxLocalize` と `InternalPdxLocalize` は多数のテンプレート実体が存在するため、現段階では一括ブレークしない。特定の呼び出し経路が得られた後に、対象実体を一つずつ検討する。

## 判定上の注意

- シンボルの存在は、実行時にその経路が通ることを意味しない。
- ブレークポイントのヒットだけでは引数の型、文字列の寿命、登録値と表示値の同一性は確定しない。
- `MENU_BAR_LOAD_GAME` のASCII・UTF-8・UTF-16相当のメモリアドレス探索は、この手順の出力だけでは行わない。
- ハング、過剰なログ、再現性のない停止が起きた場合は追跡を中止し、フックやインラインパッチへ変更しない。

## 実機トレース結果（EU4 v1.37.5）

`runtime-trace.log`で次のヒットを確認した。

| シンボル | ヒット数 | 主な呼び出し元 |
| --- | ---: | --- |
| `PdxLocalizeInitialize` | 2 | `PdxLocalizeSetup`、`ReloadPdxLocalizeHelper` |
| `LocalizeAddLocalizationYAMLBuffer` | 300 | `ReadLocalizationFileHelper` |
| `YmlParse` | 300 | `LocalizeAddLocalizationYAMLBuffer` |
| `ReloadPdxLocalize` | 1 | `main` |
| `CTextBox::ChangeTextBox` | 0 | — |

主要経路は `PdxLocalizeSetup` → `PdxLocalizeReadFolder` → `ReadLocalizationFileHelper` → `LocalizeAddLocalizationYAMLBuffer` → `YmlParse` だった。これは翻訳ファイルの読み込み経路を示すが、`MENU_BAR_LOAD_GAME`が表示時にどの `PdxLocalize` 実体またはテキスト更新関数へ渡るかは示さない。`CTextBox::ChangeTextBox` は今回の操作でヒットしなかった。

`LocalizeAddLocalizationYAMLBuffer` の `rsi` はファイルごとに変化するバッファ長とみられ、`rdx`は共通のlocalisationデータ領域とみられる。GDB出力だけでは引数の型、文字列の寿命、対象キーとの対応は確定しない。
