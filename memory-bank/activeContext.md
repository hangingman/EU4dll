# Active Context

## 現在の焦点

Linux版EU4の文字列置換経路を、Ghidra先行ではなく実行時観測から特定する。

## 次の作業

- `MENU_BAR_LOAD_GAME` の表示時に呼ばれる具体的な `PdxLocalize` 実体またはテキスト更新関数を絞る。

## 直近の完了

`Misc.getVersion()`の実行ファイル指定を、個人環境の絶対パスから既存の`BytePattern.setModule()`既定値へ変更した。既定値は`std.file.thisExePath()`で実行中の実行ファイルを解決する。

## 方針変更

FreeType/HarfBuzz、SDL/OpenGL描画API、Windows版アドレスの直接流用は前提にしない。

## 直近の完了

`tests/poc`に`fopen`の対象限定観測を追加した。`localisation`、`.yml`、`.yaml`、フォント拡張子だけをstderrへ出力し、通常のI/Oは記録しない。`make -C tests/poc`と`make test`、`make all`が成功した。

EU4本体を`make run`で起動し、メニュー到達・操作可能を確認した。相対パスの`pattern_eu4jps.log`はEU4インストール先に作成され、起動時の翻訳YAMLロードと`DLL [OK]`を確認できる。`fopen`観測PoCのstderrログは本体DLLにはまだ組み込んでいない。

## 今回の変更

`MENU_BAR_LOAD_GAME`（`Load Game` / `ロード`）を既知観測対象に固定した。翻訳ロード完了時にこのキーだけを照会し、loaded/missing と値を1行記録する。ゲーム本体の `LocalizeAddLocalization`、`YmlParse`、`PdxLocalize` 系、`CTextBox` は安全な呼び出し境界を確認できないため、フックは追加していない。

## 今回の変更

GDBバッチ補助スクリプトを追加した。`LocalizeAddLocalization`、`LocalizeAddLocalizationYAMLBuffer`、`YmlParse`、`PdxLocalizeInitialize`、`ReloadPdxLocalize`、`CTextBox::ChangeTextBox` に停止点を置き、レジスタ、バックトレース、スレッド番号を記録する。スクリプトはアドレス推測、インラインパッチ、シンボルフックを行わない。候補の役割と未確認事項は `memory-bank/details/runtime_trace.md` に記録した。

実機トレースではlocalisation読み込み経路を確認したが、`CTextBox::ChangeTextBox`はヒットせず、表示時の既知キー追跡には至っていない。次は候補を一括で増やさず、表示更新に近い既存テキスト関数を1つずつ観測する。
