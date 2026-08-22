# Progress

## 完了

- Linux版EU4の依存関係と動的シンボルを確認した。
- `SDL_*`シンボルは確認できたが、FreeType/HarfBuzzの依存と`FT_*`・`hb_*`シンボルは確認できなかった。
- バイナリ静的解析先行から、動的観測先行へ調査方針を変更した。
- 方針と作業順を`TODO.txt`へ反映した。
- `make test`成功を確認した。
- `Misc.getVersion()`の個人環境依存パスを除去し、`thisExePath()`経由の実行ファイル解決へ変更した。
- `tests/poc`に`LD_PRELOAD`ロード確認と`fopen`の対象限定I/O観測を追加した。
- localisation・YAML・フォント関連パスだけをstderrへ記録し、通常のI/Oを記録しないことをPoCで確認した。
- `make -C tests/poc`、`make test`、`make all`が成功した。
- `make run`でEU4 v1.37.5を`LD_PRELOAD`付きで起動し、メニュー到達と操作可能を確認した。
- `pattern_eu4jps.log`がEU4インストール先に作成され、起動時の翻訳YAMLロードおよび`DLL [OK]`を確認した。
- `MENU_BAR_LOAD_GAME`（`Load Game` / `ロード`）を既知文字列として選定し、翻訳元YAMLを確認した。
- `loadTranslationMods()` 完了時に既知キーだけを照会する1行の観測ログと、値を検証するユニットテストを追加した。
- `LocalizeAddLocalization`、`YmlParse`、`PdxLocalize` 系、`CTextBox` の安全なLinux v1.37.5ランタイム境界は未確認のため、危険なフックは追加していない。
- `readelf -Ws` で v1.37.5 の localisation・YAML・テキストボックス候補シンボルを確認し、GDBブレークポイントだけで観測する `tools/trace_eu4_runtime.sh` と手順 `memory-bank/details/runtime_trace.md` を追加した。
- GDBによる実機の対象メニュー追跡、候補関数の引数・文字列形式・呼び出し元の確定は未実施である。
- GDB実機トレースで `PdxLocalizeInitialize`、`LocalizeAddLocalizationYAMLBuffer`、`YmlParse`、`ReloadPdxLocalize` のヒットと呼び出し経路を確認した。`CTextBox::ChangeTextBox` はヒットしなかった。
- localisation読み込み経路は絞れたが、`MENU_BAR_LOAD_GAME` の表示時の文字列更新関数と引数は未確定である。

## 未完了

- 既知文字列のゲーム本体内ランタイム追跡（今回の観測はtranslationMap到達まで）。
- Linux版の置換地点確定。
