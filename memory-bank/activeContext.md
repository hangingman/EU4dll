# Active Context

## 現在の焦点

EU4 v1.37.5 Linux版で、起動初期の翻訳ロードによる文字列破損を避け、EU4本体の正規localisation初期化後に翻訳処理を接続できる境界を特定する。

## 確定した実機結果（2026/08/23）

- Japanese Language modは無効。Waifu Universalisは維持。`eu4dll_translations`は有効。
- `LD_PRELOAD`でDLLをロードし、通常動作では`loadTranslationMods()`をconstructor内で実行すると、画面表示文字列が`???`になる現象を確認した。
- `EU4DLL_SKIP_TRANSLATIONS=1`で`loadTranslationMods()`をスキップすると、`SetText`最初の5ヒットは`length=0,0,0,13("Connect to ID"),4("Back")`となり、翻訳ロード時の`ID??`/`??`から正常な英語へ戻った。EU4は正常終了した。
- この差分から、`loadTranslationMods()`単体、または起動初期の大量YAMLパース・Dランタイム・GC・メモリ確保が文字列破損の有力原因と判定する。単なるDLLロードだけが原因とは扱わない。
- 現在のDLLは翻訳YAMLを独自の`translationMap`へロードするだけで、SetText置換は実装していない。

## 現在の診断実装

- `source/plugin/dllmain.d`に`EU4DLL_SKIP_TRANSLATIONS=1`の実行時分岐がある。
- 指定時は`loadTranslationMods()`を呼ばず、診断マーカーをログへ出す。未指定時の既定動作は従来どおり。
- `make all`、`make test`、`git diff --check`は診断分岐追加後に成功している。

## 設計判断

- `loadTranslationMods()`をconstructor内で実行しない。constructorではロガーと必要最小限のバージョン確認に限定する。
- EU4本体の正規localisation初期化後に、翻訳ロードを一度だけ遅延実行する方式を検討する。
- `SetText`はまず置換なしの観測対象とし、実際の翻訳済み表示値がどの引数に到達するか確認する。表示値との一致、所有権、寿命、再入、安全な復帰を確認するまで置換フックを実装しない。
- Windows版アドレス、全`PdxLocalize`一括フック、`open`/`read`フック、SDL/OpenGL描画層フックは対象外。

## 次の作業

1. DLL付き同一実機実行で、`PdxLocalizeInitialize`と`ReloadPdxLocalize`の入口・復帰を限定観測する。
2. `PdxLocalizeSetup`→`PdxLocalizeReadFolder`→`LocalizeAddLocalizationYAMLBuffer`→`YmlParse`の順序と、最終localisation構築完了候補を確認する。
3. 候補境界のスレッド、再入、呼び出し回数、constructorログとの時系列を記録する。
4. 境界の安全性を確認した後、constructor外での翻訳ロードを置換なしで検証する。
5. その後に`SetText`の少数引数を観測し、翻訳表示値との一致を確認する。

## 保留

- `SetText`トランポリン、AOB、命令境界、相対アドレス、W^X、一時CString、置換PoCは、遅延ロード境界と表示値の一致確認後まで保留する。
- `translationMap`のloaded結果は、ゲーム画面表示や表示経路の証拠とは扱わない。