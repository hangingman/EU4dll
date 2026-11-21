# Progress

## ReloadPdxLocalize hook診断（2026/08/23）

- EU4 v1.37.5 Linux版はELF64 `EXEC`（非PIE）。13バイトAOBを1件検出し、targetは`0x1fefa3a`だった。
- `mmap`のhint任せによるentry配置と、`size_t CallPatchLength`混在によるsigned/unsigned比較を切り分けた。`fitsRel32()`で`CallPatchLength`を`long`へ明示変換し、entry側には`MAP_32BIT`を使用した。
- 実機ログで`target=0x1fefa3a entry=0x40afa000 distance=1051764161 fits=true`、`hook installed`、`ReloadPdxLocalize call enter`、`call return result=true`を確認した。GDBなし直接起動でEU4は正常終了した。
- constructor入口と`hijackProcess()`入口にD runtime/std.logger非依存のstderr raw markerを追加し、DLLロード後の到達を確認した。`std.logger`のFileLoggerも今回起動で出力された。
- 次はconstructor内の`loadTranslationMods()`を遅延し、`ReloadPdxLocalize`後の一回限り実行を診断専用PoCとして設計する。再入、実行スレッド、失敗時の原文維持、無効化スイッチを要件とする。SetText置換は保留する。

## localisation境界の実機観測（2026/08/23）

- 静的検証 `bash -n`、GDB `/bin/true`、`git diff --check` は成功した。
- DLL付きEU4 v1.37.5を翻訳ロード有効で起動し、EU4は正常終了した。
- `TRACE_LOCALIZE` は全件 `tid=1`。`PdxLocalizeSetup` 1回、`PdxLocalizeInitialize` 2回（各入口・復帰）、`PdxLocalizeReadFolder` 2回入口、`LocalizeAddLocalizationYAMLBuffer` 10回入口、`YmlParse` 10回入口、`ReloadPdxLocalize` 1回（入口・復帰）だった。
- 初回は `PdxLocalizeSetup` → `PdxLocalizeInitialize` 入口 → `LocalizeAddLocalizationYAMLBuffer`/`YmlParse` → `PdxLocalizeInitialize` 復帰 → `PdxLocalizeReadFolder` → 補助10件。次回は `ReloadPdxLocalize` 入口 → `PdxLocalizeInitialize` 入口・復帰 → `PdxLocalizeReadFolder` → `ReloadPdxLocalize` 復帰だった。
- `ReloadPdxLocalize` 復帰は遅延ロード境界の候補だが、localisation構築完了、再入安全性、翻訳ロード実行安全性は未証明。`PdxLocalizeInitialize` 復帰単独も、直後に`ReadFolder`が続くため完了境界としない。
- 次作業はSetText置換ではなく、constructorで翻訳ロードをスキップし、`ReloadPdxLocalize`復帰後に一回だけ翻訳ロードする診断PoCの設計。再入ガード、`tid=1`限定、失敗時のゲーム原文維持、ログマーカー、無効化可能性を要件とし、実装はまだ行わない。


## SetText実引数文字列観測（2026/08/22）

- `tools/trace_eu4_settext_string.gdb` と `.sh` を追加した。既存のDLL付きwrapperを再利用し、`CTextSprite::SetText` の第1 `CString`（`rdx`）だけを観測する。`CreateTextSprite` と既存のtrace/previewスクリプトは変更していない。
- 対象関数の最初の5ヒットに限定し、CString/data NULLを除外、`+8` 長さが `1..64` の場合だけ `TRACE_STRING` と長さ分の `x/<length>xb` を `eval` で記録する。各READに `SETTEXT_READ_##` 識別子を付け、`x/s` は削除した。長さ0や範囲外は `SKIP` とし、無条件読出し、GDB Python、inferior呼出し、フック、メモリ書換えは追加していない。
- 旧版の実機 `/tmp/eu4dll-settext-string.log` では5ヒットを取得し、最初の3件は `length=0` のためSKIP、後2件はREADとなったが、GDB表示は `ID??` と `??` で非ASCIIバイトを判定できなかった。今回のバイト列版は実機未実施である。
- GDB標準機能では任意ポインタのreadable判定を保証できないため、条件を満たしても読出し失敗でGDB/EU4が終了する可能性がある。文字列内容、`MENU_BAR_*`との対応、置換可能性は未確認である。

## SetText観測の保留

- 以前のSetTextバイト列同定、`translationMap`との照合、SetTextフック、翻訳値置換PoCは、localisation境界の診断PoC設計が完了するまで保留する。
- AOB、トランポリン、Open/read、全`PdxLocalize`一括、Windows流用も保留する。

## YAMLキー修正（2026/08/22）

- 修正後に`TRACE_GDB="$PWD/tools/trace_eu4_text_preview.gdb" ./tools/trace_eu4_text_with_dll.sh`を実行した。`/tmp/eu4dll-all-key-preview-fixed2.log`は8009 bytes、GDB wrapperのエラーなし、`TRACE_PREVIEW`は20行（CreateTextSprite 10、SetText 10）だった。EU4 v1.37.5は正常終了し、最新ログに`DLL [OK]`がある。
- 修正後の6キーはすべてloadedで、`MENU_BAR_LOAD_GAME=ロード`、`MENU_BAR_LOAD=ロード`、`MENU_BAR_QUIT=ゲーム終了`、`MENU_BAR_SAVE_GAME=セーブ`、`MENU_BAR_GAME_OPTIONS=ゲームのオプション`、`MENU_BAR_CLOSE=閉じる`を確認した。最新ALLブロックは前回実行の`key_count=117805`で全件loadedであり、今回の6キー実行はALLではない。
- `text_l_english.yml`は今回の6キー実行でパース成功し、以前の`Key 'true' appears multiple times`は修正で解消した。これはYAMLロード、DLL、TRACE_PREVIEW取得、EU4正常終了の確認であり、日本語表示の証明ではない。文字列本体は未読出しで、SetText文字列と翻訳キー・表示値の対応および置換可否は未確認である。
- 最新ALL観測（2026-08-22 21:53:18付近）は`key_count=117805`で全件loaded/missing=0だった。`MENU_BAR_LOAD_GAME`、`MENU_BAR_LOAD`、`MENU_BAR_QUIT`はloadedで確認し、`MENU_BAR_SAVE_GAME`、`MENU_BAR_GAME_OPTIONS`、`MENU_BAR_CLOSE`は最新ALLブロックに存在しなかった。
- 21:53:19付近に修正版DLLの`DLL [OK]`とEU4 v1.37.5のGDB wrapperからの正常起動を確認した。
- `text_l_english.yml`の残存エラーは`Key 'true' appears multiple times in mapping`によるファイル単位スキップだった。d-yaml 0.10.0のYAML 1.1特殊スカラー解決で、未クォートの`on`、`off`、`NO`、`YES`などが真偽値キーとして衝突することを、実ファイルと変換後入力で確認した。
- `normalizeLocalizationYaml`に、特殊スカラーに見えるキー位置だけをクォートする処理を追加した。既存のBOM除去、`:0`〜`:9`変換、`l_english:`補完、通常のYAML値は変更しない。回帰テストでBOM、ヘッダーなし、`:0`〜`:3`、特殊キー、6つの`MENU_BAR_*`キーの登録を確認した。
- 最新ALLの再観測は今回の実行ではなく、6キー実行のため未実施である。GDB、フック、インラインパッチ、open/readフックは変更していない。

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
- `/tmp/eu4dll-text-args.log`（85135 bytes、`TRACE_ARGS` 678行）で、`CGraphics::CreateTextSprite` 236回（全てtid=1、pc=`0x2079b00`）と `CTextSprite::SetText` 442回（全てtid=1、pc=`0x20d9da4`）の実機ヒットおよび候補CStringアドレスを確認した。EU4 v1.37.5は正常終了し、MENU画面まで到達した。
- 記録したのは候補CStringアドレスのみで、文字列は読み出していない。ログ中に `Load Game` も `ロード` も現れないため、上記ヒットと `MENU_BAR_LOAD_GAME` の直接対応、CString構造、各レジスタ候補の正しさ、文字列形式・寿命は未確認である。両関数をMENU画面で頻繁に通る表示生成経路候補として記録するが、既知キー対応とは断定しない。
- `MENU_BAR_LOAD_GAME` の安全な文字列ポインタ根拠は未確認で、ASCII/UTF-8/UTF-16相当のメモリ探索は実施していない。次の最小ステップは、未確認ポインタの無条件読み取りを追加せず、静的解析または安全な条件付き観測方法を検討することとする。全 `PdxLocalize` テンプレート一括フック、`open`/`read` フック、インラインパッチは禁止する。
- `tools/trace_eu4_text_args.gdb` と `tools/trace_eu4_text_args.sh` は未確認ポインタの文字列読出しを行わず、アドレス、tid、pc、回数だけを記録するため、安全性と限界を確認した。次は既存の有志翻訳Mod/translationMapを入力データとして維持しつつ、CString ABIを静的確認し、少数の引数だけを安全条件付きで観測する。全 `PdxLocalize` 一括、`open`/`read` フック、インラインパッチは禁止する。
- EU4 v1.37.5を起動せずに `readelf -Ws --wide | c++filt` と `objdump -dC` を実行し、`CString::CString(char const*)`（`0x254b1c2`）、`CString::operator==(CString const&) const`（`0xd96f6a`）、`CTextSprite::SetText(...)`（`0x20d9da4`）、`CGraphics::CreateTextSprite(...)`（`0x2079b00`）を確認した。CStringの `+0` はデータポインタ候補、`+8` は長さ候補で、SetTextの `rdx` およびCreateTextSpriteの `rsi` がその `+0` を読む根拠を記録した。
- GDB標準機能だけでは、候補ポインタが読み取り可能なマッピング内にあることをブレークポイントコマンドで安全に保証できない。未確認ポインタの `x/s`、`x/b`、GDB Python、inferior関数呼出しは追加せず、既存のアドレスのみの調査スクリプトを維持した。文字列一致は未確認で、`MENU_BAR_LOAD_GAME` 対応とは断定しない。
- `tools/trace_eu4_text_preview.gdb` と `.sh` を追加し、`CTextSprite::SetText` の `rdx` と `CGraphics::CreateTextSprite` の `rsi` について、NULLでないCStringオブジェクトの `+0` データポインタ候補と `+8` 長さ候補を各関数の最初の最大10ヒットだけ記録するようにした。GDB標準機能でデータポインタのreadable判定を保証できないため、文字列表示は実装していない。`Load Game`、`ロード`および `MENU_BAR_LOAD_GAME` との対応は未確認のままである。実機結果は次項に記録する。
- 実機トレース結果を `/tmp/eu4dll-text-preview.log` に記録した（10612 bytes）。EU4 v1.37.5は正常終了しMENU画面まで到達した。各関数の最初の最大10ヒットを対象にNULLでないCStringだけを観測し、`CGraphics::CreateTextSprite` の `rsi` は全件で `+0` データポインタ候補が非NULL、`+8` 長さが `7,7,13,13,18,13,6,32,32,13`、`CTextSprite::SetText` の `rdx` は全件で `+0` データポインタ候補が非NULL、`+8` 長さが `0,0,0,4,2,6,6,5,5,2` だった。文字列本体は読み出していないため、静的根拠とのメタデータ整合性までを確認事項とし、文字列内容、`Load Game`/`ロード`との一致、`MENU_BAR_LOAD_GAME`との直接対応、引数の意味、寿命は未確認である。次はデータポインタと長さの組を静的に検討し、必要なら安全条件を明示した単一候補・単一ヒットの観測を設計する。全 `PdxLocalize` 一括、`open`/`read` フック、インラインパッチは禁止する。
- 今回の判断として、Linuxの`/proc/<pid>/maps`を利用する外部監視はGDBバッチスクリプトだけでは実装できず、未確認ポインタの文字列読出しも現時点では不可欠でないため追加しない。既存の静的根拠とメタデータ観測を維持し、次は置換候補の絞り込みへ進む。文字列一致が必要になった場合のみ、安全条件と別プロセス監視の導入可否を再評価する。

## 未完了

- 実機で未観測のキーを表示されたと断定しない前提で、`EU4DLL_TRANSLATION_OBSERVATION_KEYS` による既存辞書の複数キー選択と loaded/missing/value の直接照会を追加した。未設定時の既定値は`MENU_BAR_LOAD_GAME`である。
- `EU4DLL_TRANSLATION_OBSERVATION_KEYS=ALL` を追加し、ロード済み`translationMap`の全キーを辞書順で列挙する。件数と各キーの loaded/missing/value を出力するためログ量が増える。これはゲーム本体のフックではなく辞書ロード後の直接観測で、実機表示や`SetText`引数との対応証拠ではない。複数指定した6キーがmissingだった現象は未解決であり、ALLで自動解決するとは断定しない。
- 実機ALL観測（`key_count=6923`）は全件loadedで、6つの`MENU_BAR_*`キーだけが対象ブロックに無かった。配置上の3キーは`EU4_l_english.yml`、3キーは`text_l_english.yml`に存在したが、後者は`Mapping values are not allowed here`等のパースエラーでファイル単位スキップされていた。両ファイルのUTF-8 BOMと`:1`〜`:3` suffixを確認し、`:0`だけの変換不足を根因と特定した。
- `mod.d`でUTF-8 BOMを除去し、`:0`〜`:9`を`: `へ変換してから不足時の`l_english:`補完を行うよう修正した。テストはBOM・ヘッダー補完・6つの`MENU_BAR_*`キーが`translationMap`へ入ることを最小データで検証する。実機再確認は未実施。
- 既知文字列のゲーム本体内ランタイム追跡（今回の観測はtranslationMap到達まで）。
- Linux版の置換地点確定。

## SetText置換PoCの判断（2026/08/22）

- `CTextSprite::SetText` の1件置換PoCは安全停止点として見送った。
- 実機観測ではCStringの候補ポインタと長さだけが得られ、`MENU_BAR_LOAD_GAME` のキーまたは表示値との一致、各引数の意味、バッファの寿命・所有権・終端は未確認である。
- 既存の `makeJmp` / `ScopedPatch` は5バイトJMPとW^X切替を行うが、命令境界、トランポリンと元処理への復帰、相対アドレス範囲、一意AOB、パッチ競合を検証しない。今回のSetTextへ流用すると、無効化可能かつ失敗時に原文を維持する要件を満たせない。
- 本体命令を書き換えるフック、無条件の文字列読出し、元CStringの直接変更、一時CStringの未証明な生成は追加していない。再開条件は、実引数の一致確認とLinux専用の検証済みパッチ設計である。

## CString所有権・容量・寿命の調査（2026/11/21）

- 詳細は `memory-bank/details/cstring_ownership.md` に記録した。
- `CString` は libstdc++ `std::string` と同じ32バイトレイアウト（+0 データポインタ、+8 長さ、+16 SSOバッファ／ヒープ容量の共用体）で、バッファはオブジェクト自身が所有し、デストラクタがヒープ時のみ解放する。コピーはバッファを共有しない。
- `CTextSprite::SetText` は引数の長さフィールドを使わず、`strlen(data)` の結果を自オブジェクト内の文字列へ `_M_replace` でコピーする。引数の寿命は呼び出しの間だけ必要である。
- 現在のフックは先頭16バイトしか読まないため容量は判定できない。可変長置換は、ヘッダ32バイト化と容量の実測を先に行い、容量以内の場合に限り、+8 と終端NULを同時に更新する形でのみ検討する。容量超過の置換は引き続き実装しない。
- 実機確認（2026-11-21 12:10 smoke、runs/20261121-121004）：同一長置換2件（長さ4と13）が `result=applied`、EU4はExitボタンで正常終了した。

## 可変長置換の実装（2026/11/21）

- `settext_hook.d` のヘッダ読み取りを16バイトから32バイトへ広げ、CString の容量（+16）を読むようにした。データポインタがオブジェクト+16 と一致する場合は SSO 容量15、それ以外は +16 の `size_t` をヒープ容量とする（純粋関数 `cstringCapacity`、単体テストあり）。
- 置換は、置換後の長さが容量以下の場合に限り長さが違う置換も許可する。データへ置換バイト列と終端NULを書き、長さフィールド（+8）を合わせて更新する。データポインタと +16 は変えない。
- 容量を超える場合は置換を見送り、`result=skipped reason=exceeds-capacity` をマッピングごとに1回ログへ出す。容量が元の長さ未満の場合は `reason=invalid-capacity` で見送る。
- 環境変数の entry は長さが違う組も読み込むようになった（`length-mismatch` の却下は廃止）。単体テストで可変長の parse、SSO／ヒープ容量、容量境界を確認した。
- 検証: `make test`（6モジュール通過）、`make all` 成功。実機 smoke（runs/20261121-122234、同一長2件）では両マッピングとも `result=applied`、`invalid-capacity` なし、EU4はExitボタンで正常終了した。可変長そのものの実機確認は次の項目で行う。

## 可変長置換の過去の試行整理と容量の実測（2026/11/21）

- 詳細は `memory-bank/details/variable_length_history.md` に記録した。過去の試行は、f25f5a3 のGDB PoCが同一バイト長を前提に可変長を明示的にスキップし（所有権・寿命・容量が未確認のため）、その後も容量が読めないことが止まった理由だった。
- この変更では置換の許可範囲を変えず、マッチ時に容量を1回だけログへ出す行（`SetText capacity id=.. length=.. capacity=..`、純粋関数 `formatSetTextCapacityLog`）だけを追加した。
- 実機実測（smoke runs/20261121-122907、EU4はExitボタンで正常終了）: `Back`（長さ4）と `Connect to ID`（長さ13）はどちらもSSOで容量15。両対象とも15バイトまでの置換が容量に収まる。それ以外の文字列やヒープ確保の文字列の容量は未実測。

## 文字化けの原因の切り分け（2026/11/21）

- 詳細は `memory-bank/details/mojibake_settext.md` に記録した。結論: SetText置換は変換処理を通らない。フックは環境変数のバイト列をそのままCStringへ書く（`settext_hook.d` の `parseSetTextProbeEntry`／`tryReplace`）。`translationMap` も参照しない。
- DLL本来の2バイト文字の仕組みは、テキスト処理ループ側の復号（`main_text.d` の `ESCAPE_SEQ_1..4` = 0x10〜0x13＋2バイトコードポイント）と `font.d` のパッチだが、`dllmain.d` では `Font.init`／`TextView.init` がTODOとしてコメントアウトされており、Linux版では有効になっていない。有効なのは `loadTranslationMods`、`ReloadTrace`、`SetTextHook`、`PluginVersion` のみ。
- そのためEU4は置換後のCStringを通常の1バイト文字として読み、UTF-8の各バイトが別々の字形になる。`戻る` は E6 88 BB E3 82 8B の6バイトで、長さや容量の問題ではなく表示側の解釈で化ける。
- 実機確認（smoke runs/20261121-123828、`Back=戻る`）: `SetText capacity id=0 length=4 capacity=15`、`result=applied` を確認し、EU4はExitボタンで正常終了した。書き込み側は日本語バイト列でも動作する。画面表示の成否は判定に入れていない。
- 今後の見通し: SetTextでUTF-8を書く方式のままでは日本語は表示できない。先にテキスト処理ループとフォント側の復号をLinux v1.37.5で有効にし、置換文字列はエスケープ形式で渡す必要がある。このリポジトリにUTF-8からエスケープ形式への変換器はまだ無い。実装はしていない。

## translationMapとSetText実引数の対応確認（2026/11/21）

- 詳細は `memory-bank/details/translationmap_settext_correspondence.md` に記録した。結論: 直接の対応はない。`translationMap` のキーはローカライズキー（例 `MENU_BAR_LOAD_GAME`）で、SetTextへ渡るのはキーではなく解決済みの表示文字列であり、`l_english` セッションではゲーム自身の英語値である。値側（日本語訳）もSetTextへは渡らない。橋渡しは「キー -> 英語値 -> SetText引数」の間接対応のみ。
- 実機照合（smoke runs/20261121-124618、EU4はExitボタンで正常終了）: `BACK`->`Back` は id=0 で `result=applied`（容量15）、`CONNECT_TO_IP`->`Connect to ID` は id=1 で `result=applied`（容量15）。一方 `MENU_BAR_LOAD_GAME`->`Load Game` は id=2 に applied／capacity／content-mismatch のいずれも出ず、メインメニュー実行ではSetText到達を観測できなかった（理由は未証明で、不一致の証明ではない）。
- 同じ実行で `translationMap` は0件だった。agent環境にはParadoxのmodディレクトリ自体が無く（`Mod directory not found`）、観測キー3件は全て `status=missing`。実データの日本語値を埋めるには `submodules/EU4JPModAppendixI` の初期化と、その `main.py`（要 `PARATRANZ_SECRET`）による生成が必要だが、指示によりサブモジュール初期化は行わなかった（`git submodule status` は `-19be99e` の未初期化状態）。この点は所有者の判断待ちとして記録した。
- フックは `translationMap` を参照しない（項目5）ため、この対応は情報整理のみ。辞書連携へ進む場合はキーではなく英語値で結び、英語値の衝突と、SetTextへ到達しないキーへの扱いを決める必要がある。


## 翻訳ファイル読み込みへの移行設計（2026/11/21）

- 詳細は `memory-bank/details/translation_file_loading_design.md` に記録した。設計のみで実装は変更していない。大きな作り替えは所有者の確認待ちとする。
- 現状: SetTextフックは環境変数 `EU4DLL_SETTEXT_REPLACEMENTS`（`MaxMappings=8`、`MaxProbeBytes=256`）から `ProbeMapping` 表を作り、`translationMap` は `loadTranslationMods()` がmodディレクトリのymlから読み込むがフックは参照しない。両者は `dllmain.d` で辞書ロード→フックの順に既に動いているため、移行は結合部の追加であり書き直しではない。
- 項目6の制約: キーはローカライズキーでSetTextへは渡らず、英語値を介した反転（キー -> 英語値 -> 日本語値）が必要。英語値は一意でないため衝突ルールを要し、提案は同一英語・異なる訳の場合は `reason=ambiguous-source` で見送ってログに残すこと。`MENU_BAR_LOAD_GAME` のようにSetTextへ到達しないキーがあり、全件置換は約束できない。
- 項目5の制約: 置換文字列はUTF-8ではなくエスケープ形式（0x10〜0x13＋2バイト）で渡す必要があり、UTF-8→エスケープ変換器はまだ無いため新規の純粋関数として設計した（復号側の `SHIFT_2/3/4` の逆変換、往復テストと固定ベクタで検証、容量判定はエスケープ後のバイト長で行う）。エスケープ後は1文字3バイトになるため、実測SSO容量15では日本語は最大5文字までしか収まらない点も記録した。
- 前提条件: 変換器、Linux v1.37.5での復号側（`Font.init`／`TextView.init`、テキスト処理ループとフォントパッチ）の有効化、実データのためのサブモジュール初期化＋ `PARATRANZ_SECRET` による生成。復号側が無い間、ファイル読み込みの検証はロード／結合／変換のログとフィクスチャ、英文同士の組の表示、フックでの `result=applied` までに限る。
- 段階案: A 変換器＋テスト、B opt-inスイッチ（提案名 `EU4DLL_SETTEXT_FROM_TRANSLATIONS=1`）の後ろで結合とファイル読み込み（現行の表の上限のまま、既知2件で検証、環境変数は設定時に優先する上書きとして残す）、C 全辞書向けの保存／検索の拡張と実測、D 復号側の有効化と日本語の画面確認。
- 所有者の判断待ち: 英語側の入手方法（ゲームのymlをロード時に読む／生成した対応ファイルを同梱する）、衝突ルール、環境変数の優先扱い、サブモジュール初期化と秘密情報の用意、段階DをB・Cより前に置くかどうか。

## 翻訳本体の所在と形式の確認（2026/11/21）

- 詳細は `memory-bank/details/translation_body_location.md` に記録した。結論: 環境内にJSON形式の翻訳本体は見つからなかった。実在する翻訳本体はyml形式で、配置先は `~/.local/share/Paradox Interactive/Europa Universalis IV/mod/eu4dll_translations/localisation/`（145ファイル、約16MB）。本人の別チェックアウト `~/git/EU4dll/submodules/EU4JPModAppendixI/source/localisation/` の生成物と同一であることをdiffで確認した。
- 形式: UTF-8 BOM付き、`l_english:` ヘッダー、行は ` KEY:N "日本語"`。値は素のUTF-8で、エスケープバイト（0x10〜0x13）は含まれない（text_l_english.ymlで0件）。例: BACK="戻る"、CONNECT_TO_IP="ID接続"、MENU_BAR_LOAD_GAME="ロード"。
- JSONはリポジトリのテスト用 `tests/resources/test_translation.json`（`{"KEY":{"text":"value"}}` 形式、4件）のみで、読み込むコードは無い。Steam／Paradox配下のJSONはランチャー等のデータだった。Workshopの日本語化Mod（1359233579）はアーカイブ実体がディスクに無く確認できなかった。
- 項目9以降は、このyml本体を翻訳の入力として扱う。agent自身のParadox modディレクトリは無いため、従来の実機実行でtranslationMapが0件だった点も再確認した。

## 復号の有効化方法の調査（2026/11/21）

- 詳細は `memory-bank/details/decode_enablement_investigation.md` に記録した。調査のみで実装は変更していない。
- 結論: `dllmain.d` の `Font.init`／`TextView.init` のコメントアウトを外すだけでは有効にならない。`font.d`／`main_text.d` の全インジェクタは `EU4Ver.v1_37_5` のケースを持たず（上限はv1.33.3.0）、defaultでバージョンエラーになる。
- パターン実測: ローカル（〜v1.33）の全パターンと、上流 matanki-saito/EU4dll の `develop` ブランチ（Windows版1.37対応、ビルド番号370〜375を `v1_37_0_0` に割当）のv1.37用パターンの両方をLinux版v1.37.5バイナリ（60,526,352バイト）へ走査し、**全て0件**だった。Linux版は別ビルド（SysV ABI、レジスタ割当が異なる、Windowsヒープ無し）のため、パターンもフックもLinuxバイナリから新規に導出する必要がある。
- 上流v1.37の知見: Font側はリミッタのパターンが分岐オフセットのみ変更、BufferClear1/2はパターン変更。MainText側はProc1/2/4でパターンとアセンブリの両方が新規（V137版、レジスタ変更）、Proc3は戻り先パターンのみ変更。つまり1.37ではゲーム側のループが再コンパイルされており、Windows側でも流用はできなかった。
- その他の障害: この移植の `BytePattern.hasSize()` は常時trueのスタブで、ヒット0件でも `getFirst()` を参照しかねない。`font.d`／`main_text.d` は5バイトrel32 `makeJmp` を使うが、Linuxでは遠距離で使えなかった実績があり、実証済みのSetText方式（14バイト絶対JMP＋命令境界検証）への置き換えが要る。HeapZeroClear（WindowsのHeapAlloc前提）と0x3D88前提のバッファパッチはLinuxに同形の箇所が無い（0x3D88の出現7件は全てトークンID等の無関係箇所だった）。
- Linux側の候補箇所はシンボルから特定した: テキスト処理ループの実体は `CBitmapFont::GetRequiredSize`（0x20565aa）、`GetActualRequiredSize`（0x2055f92）、`FillVertexBuffer`（0x2055448）、`RenderToTexture`（0x204e886）等で、フォントバッファ側は `CreateBuffers`（0x204d524）／`ParseFontFile`（0x204de66）。有効化の作業手順（箇所特定→Linux用AOBとアセンブリ→v1_37_5ケース追加→opt-in配線→段階確認）を詳細ファイルに残した。
- この調査が済むまで項目11（日本語の画面確認）は実施できない。項目10の変換器は単体テスト（復号規則との往復）までの検証になる。


## UTF-8→エスケープ変換器の実装（2026/11/21）

- 詳細は `memory-bank/details/escape_codec.md` に記録した。新規モジュール `source/plugin/localization/escape_codec.d` に純粋関数 `encodeUtf8ToEscaped`／`encodeCodePoint` と、単体テスト専用の復号テストダブル `decodeEscaped` を実装した。SetTextフックへの配線はまだ行っていない（項目7設計の段階B）。
- 変換表の出どころ: 上流 matanki-saito/EU4dll の `develop` ブランチ `Plugin64/escape_tool.cpp`（同ファイルの最終変更は a0fedb2、2024-08-24）の `convertWideTextToEscapedText` 等を移植した。項目7の設計時点では復号側のシフト量（SHIFT_2=0x0E、SHIFT_3=0x900、SHIFT_4=0x8F2）しか分かっていなかったが、実際の変換には回避バイト集合（29値。高位バイトが集合内なら+2、下位バイトが集合内なら+1でエスケープバイト 0x10〜0x13 を決め、保存ワードをずらして集合内のバイトが現れない形にする）と、CP1252特殊ケース（27件、例 U+20AC→0x80）が要ることが上流コードで判明した。
- 検証: 固定ベクタで4つのエスケープ帯全てを確認した（戻=`11 49 62`、る=`10 8B 30`、続=`12 9A 74`、尻=`13 49 53`）。往復テストはASCII・かな・漢字・混在文と、項目8の実訳値（戻る、ID接続、ロード）で通過した。`make test` は7モジュール通過（従来6）、`make all` 成功。
- 上流からの意図的な相違を1件記録した: CP1252特殊ケースで上流は `(BYTE)cp`（元のコードポイントの下位バイト）を書くが、それでは上流自身の復号（CP1252ToUCS2）で戻らないため、この移植では変換表の値（U+20ACなら0x80）を書く。
- 制限も記録した: 0x100より大きく0xA00未満の帯域は上流仕様で +0xE000 ずらされ往復しない（日本語は0xA00以上で無関係）。BMPを超えるコードポイントは表現が無いため変換失敗として返す。復号テストダブルのNOT_DEF境界は上流 `convertEscapedTextToWideText` に従い、`main_text.d` フック側（16ビット切捨て、0x98F以下で代替）とは細部が異なる点も記録した。
- 項目11（日本語の画面確認）は、復号側が有効になっていないため実施しない（項目9の結論どおり、有効化にはLinux用パターンとフックの新規作成が要る）。

## Font側のLinux用パターン導出（2026/11/21）

- 詳細は `memory-bank/details/font_linux_patterns.md` に記録した。導出のみで、注入は有効にしていない（`font.d` は無変更、`Font.init` はコメントアウトのまま）。
- リミッタは一意に導出できた: `CBitmapFont::ParseFontFile` の VA 0x204e366、`cmp r13d, 0FFh / ja +0x125`、パターン `41 81 FD FF 00 00 00 0F 87 25 01 00 00` はバイナリ全体で1件。cmp単独では23件のため分岐込みのパターンが要る。グリフはコードポイントで引く表（`0x100(%rcx,%r13,8)`、要素16バイト確保）へ登録されることも確認した。
- HeapZeroClear はLinuxに対応箇所が無い（`CreateBuffers`／`CreateBuffer` は `GfxCreateVertexBuffer` を直接呼び、ゼロクリアの呼び出しは無い）。Linux計画からは外す。
- BufferClear1/2 と BufferExpansion の前提だった即値 0x3D88 はLinuxのフォントコードに無い（`mov edx,0x3d88` は0件、全レジスタでも7件全て無関係）。Linuxで頂点バッファの大きさに当たる即値は 0x4B0（ストライド 0x1C）で、`GfxCreateVertexBuffer` 呼び出しは2箇所のみ。文脈込みパターンでは各1件に一意化できるが、0x4B0 がWindowsの 0x3D88 と同じ役割かは未証明のため、候補として記録するに留めた。
- FontSizeLimit は見つからなかった: `cmp r14d, 1000000h` は0件、マスクした汎用形でも20件全て `CBitmapFont` の範囲外で、フォント範囲内に大きな即値の比較は無い。別定数か呼び出し側へのインライン化の可能性は未証明。

## TextView側のLinux用パターン導出（2026/11/21）

- 詳細は `memory-bank/details/main_text_linux_patterns.md` に記録した。導出のみで、注入は有効にしていない（`main_text.d` は無変更、`TextView.init` はコメントアウトのまま）。
- LinuxのテキストループはWindowsと構造が違う: 文字取得は `CString::operator[]` 呼び出し経由（戻り値ポインタへ `movzbl`）、グリフ表は +0x100、スケールは +0x940（Windowsは +0x848）。`movzbl (%rax),%eax` 単独は全体で305件、グリフ参照込みの短い形でも12件あるため、文脈込みパターンが要る。
- Proc1（ループ2）は `FillVertexBuffer` 内に取得箇所が2つあり（VA 0x2055562 と 0x2055ac1）、文脈込みで各1件に一意化できた。どちらを対象にするかは未決定。
- Proc4（ループ1）はループ1が3関数（GetRequiredSize／GetActualRequiredSize／GetActualRealRequiredSizeActually）に分かれており、各関数に取得箇所が1つずつあり（VA 0x2056872／0x2056198／0x20570b6）、各1件に一意化できた。
- Proc2はWindowsの形では見つからなかった: バッファアドレスを取り出す `lea`（グローバルバッファ）が無く、カウント側は文字列を scratch バッファへ写さない。唯一のバイトコピーは色コード（0xA3）の名前をスタックへ写す処理（上限0x7E、各関数で一意だが役割が違う）。
- Proc3は、フック形（グリフ+6の word 比較＋分岐）は `FillVertexBuffer` VA 0x2055619 に1件だけあるがループ2側で、戻り先2（グローバルフラグ比較 `80 3D ...`）は候補関数内に存在しない。Proc2→Proc3/Proc4 の `s_lastCodePoint` の受け渡しにもLinux側の足場が無いため、項目14/15ではWindowsのProc1〜4の移植ではなく、取得箇所そのもので復号する設計が要る。
