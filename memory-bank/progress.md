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
- 前回候補 `CTextBuffer::ChangeString()` / `CTextBox::ChangeString(CString const&)` はbreakpointを設定できたが、`/tmp/eu4dll-candidate-trace.log`（9484 bytes）のTRACEが0件で、今回の起動・操作では呼ばれなかった。表示経路は未確定で成功扱いにしない。
- `CTextBox::UpdateTextSprite()` / `CTextBox::ChangeString(CString const&, FontFormatting, bool)` はbreakpoint設定後のMENU画面トレースで0ヒットだったため、候補から外し成功扱いにしない。
- `readelf -Ws` と `objdump -dC` の結果から、次の表示テキスト生成・設定候補を `CTextSprite::SetText(...)`（`0x20d9da4`, 2151 bytes）と `CGraphics::CreateTextSprite(...)`（`0x2079b00`, 443 bytes）の2つに限定した。前者はCStringの内部コピー、フォント・テクスチャ処理、頂点再計算を行い、後者はスプライト生成と設定仮想関数呼び出しを行う。
- `tools/trace_eu4_runtime.gdb` は上記2候補だけを停止し、各ヒットを `symbol/tid/pc` の1行で記録する。既存のlocalisation読み込み300回ログ、レジスタ、バックトレースの出力は削除した。
- `/tmp/eu4dll-sprite-trace.log`（45921 bytes）で `CGraphics::CreateTextSprite` 236回（全てtid=1、pc=`0x2079b00`）と `CTextSprite::SetText` 444回（全てtid=1、pc=`0x20d9da4`）の実機ヒットを確認した。EU4 v1.37.5は正常終了し、MENU画面まで到達して「ロード」表示状態を確認した。
- 短いTRACEは文字列引数を記録していないため、上記ヒットと `MENU_BAR_LOAD_GAME` の直接対応、引数の意味、文字列形式、文字列の寿命は未確認である。従って、`CGraphics::CreateTextSprite` → `CTextSprite::SetText` を現在最有力の表示生成経路として記録するが、因果関係は断定しない。
- `MENU_BAR_LOAD_GAME` の安全な文字列ポインタ根拠は未確認で、ASCII/UTF-8/UTF-16相当のメモリ探索は実施していない。次の最小ステップは、未確認ポインタの無条件読み取りを追加せず、静的解析または安全な条件付き観測方法を検討することとする。全 `PdxLocalize` テンプレート一括フック、`open`/`read` フック、インラインパッチは禁止する。

## 未完了

- 既知文字列のゲーム本体内ランタイム追跡（今回の観測はtranslationMap到達まで）。
- Linux版の置換地点確定。
