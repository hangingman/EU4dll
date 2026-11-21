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

## Linux注入方式の整備（2026/11/21、項目14）

- 詳細は `memory-bank/details/linux_injection_method.md` に記録した。`Font.init`／`TextView.init` はまだ有効にしていない。
- patcher: SetTextで実証済みの14バイト絶対ジャンプを `makeAbsoluteJmp`／`makeAbsoluteJmpPadded` として共有化し、`makeJmp` は絶対ジャンプを返すようになった（旧5バイト相対形は `makeJmpRel`）。`PatchManager.addJmpPatch` を追加。SetTextフックは共有版を使うようになった（パッチは従来どおり17バイト）。
- BytePattern: `findIndexes` が全件を数えるようになり（従来はセクションごとに最初の1件だけ）、スタブだった `hasSize` が実判定になった。注入側の `hasSize(1, ...)` の一意性確認がこれで実際に効く。最初の1件だけを使う正当な利用向けに `hasAtLeast` を追加した。
- 全件化で見つかった既存の不整合を同項目で直した: (1) SetTextパターンは22バイトでは2件（もう1件は VA 0x2140660）あったため文脈を延長して VA 0x20d9da4 の1件に一意化した。(2) バージョン文字列は4件あるため PluginVersion は `hasAtLeast(1)` で明示した。(3) ReloadPdxLocalize はコピー長8バイトと結びついているため相対ジャンプを明示的に使う形に留めた（絶対ジャンプを流した中間ビルドではEU4が起動直後に落ちた。runs/20261121-144008、eu4_wait=11）。
- 検証: `make test` 8モジュール通過、`make all` 成功。smoke runs/20261121-144447 でDLL [OK]、SetText target=0x20d9da4 に適用成功（id=0 result=applied）、Exitで正常終了（eu4_wait=0）、メニュー画面の英語表示は正常だった。

## 復号の有効化配線（opt-in、2026/11/21、項目15）

- 詳細は `memory-bank/details/decode_optin_enablement.md` に記録した。`dllmain.d` で `EU4DLL_ENABLE_DECODE=1` の場合だけ `Font.init`→`TextView.init` を呼ぶ配線を追加した（順序は上流どおり）。結果の `DllError` は集約してログへ出すが致命的にはしない（PluginVersion の判定が従来どおり唯一の終了条件）。v1.37.5では各注入にケースが無いため現状パッチは当たらず、復号自体はまだ機能しない。項目16の前提（取得箇所フックの実装）は未充足のまま。
- 初回smoke（runs/20261121-145211）でEU4が起動直後に落ちた（eu4_wait=139）。原因は `DllError.opBinary("|")` が `return this | rhs;` という無限再帰で、これまで集約する経路が有効でなかったため踏まれていなかった。フィールド単位のORへ直し、単体テストを追加した（`make test` は8→9モジュール通過）。
- 検証: smoke runs/20261121-145625（EU4DLL_ENABLE_DECODE=1＋SetTextプローブ）でメニュー到達、DLL [OK]、Exitで正常終了（eu4_wait=0）。メニュー画面のスクリーンショットで通常の英語表示に崩れが無いことを目視確認した。

## Font側リミッタ注入の実装（2026/11/21、項目17）

- 詳細は `memory-bank/details/font_limiter_linux_injection.md` に記録した。`font.d` の `charCodePointLimiterPatchInjector` に v1.37.5 のケースを追加した。パターンは項目12の一意パターン（`ParseFontFile` VA 0x204e366、`41 81 FD FF 00 00 00 0F 87 25 01 00 00`）で、`hasSize(1)` が一致件数1を確認した場合だけ当てる。即値はオフセット3から `FF 00 00 00` で、オフセット4へ `0xFF` を書くと `0xFFFF` へ広がる（Windows版の+3はREX接頭辞が無い分で、Linux版は+4）。
- 動作は従来どおり opt-in（`EU4DLL_ENABLE_DECODE=1` で `Font.init` が呼ばれる場合だけ）。他のFont注入は項目18の範囲で未変更のため、decode全体のエラーログは引き続き出る（致命的ではない、項目15の配線どおり）。
- 検証: `make test` 9モジュール通過、`make all` 成功。smoke runs/20261121-150649（opt-in＋SetTextプローブ）で `WriteMemory for charCodePointLimiterPatchInjector (v1.37.5) called.` を確認し、リミッタの件数不一致ログは無かった。DLL [OK]、Exitで正常終了（eu4_wait=0）、メニュー画面の英語表示は正常だった。

## Font側の残り注入の整理（2026/11/21、項目18）

- 詳細は `memory-bank/details/font_remaining_linux_injectors.md` に記録した。
- FontSizeLimit は実装した: 全レジスタ形の `cmp imm 1000000h` を再走査し、グラフィックス／テクスチャ関係で唯一の箇所が `CTextureHandler::LoadTexture` VA 0x22a7edb（`cmp ebx,1000000h`、ebx は `CVirtualFile::GetSize()`、16MiB以上は読み込み拒否）だと特定した。他の汎用形19件は lua／curl／OpenSSL／ネットワーク等の無関係箇所。`font.d` に v1.37.5 ケースを追加し、`hasSize(1)` のときだけ即値末尾へ 0x04 を書いて上限を 04000000h（64MiB）へ広げる（opt-in時のみ）。
- BufferClear1/2 は実装しない: Linuxのフォントバッファ経路に 3D88h のクリア箇所は無く、`GfxCreateVertexBuffer` へはデータポインタ NULL で生成され、対応する memset が存在しない。
- BufferExpansion は実装しない: 候補だった 0x4B0 は `GfxCreateVertexBuffer` 本体の確認でバイトサイズではなく頂点数（1200、ストライド 01Ch）だと分かり、埋める側に 1200 の上限チェックが無いため、割り当てだけ広げても効果が実証できない。項目19/21で実際に頂点数の切り捨てが出たら再検討する。
- 検証: smoke runs/20261121-151742（opt-in＋SetTextプローブ）で FontSizeLimit とリミッタ両方の WriteMemory ログを確認し、件数不一致は無かった。DLL [OK]、Exitで正常終了（eu4_wait=0）、メニュー画面の英語表示は正常だった。

## TextView側フックの実装（2026/11/21、項目19）

- 詳細は `memory-bank/details/main_text_linux_injection.md` に記録した。項目13のパターンを使い、`main_text.d` に v1.37.5 のケースを追加した: Proc1インジェクタが `FillVertexBuffer` の2箇所（VA 0x2055562／0x2055ac1）、Proc4インジェクタが計測側3関数（GetActualRequiredSize VA 0x2056198／GetRequiredSize VA 0x2056872／GetActualRealRequiredSizeActually VA 0x20570b6）を担当する。各箇所とも `hasSize(1)` で1件一致を確認した場合だけ、項目14の絶対ジャンプ（`addJmpPatch`、パッチ長は箇所ごとに16／14バイト）で当てる。
- フックは取得箇所そのもので復号する設計（WindowsのProc2経由の受け渡しはLinuxに無いため）。`CString::operator[]` の戻りポインタが指すバイトがエスケープバイト（0x10〜0x13）なら続くワードを既存フックと同じずらし量で復号し、その箇所のループ添字を2進め、グリフ取得（+0x100）を再現して戻る。戻り先が条件分岐の箇所では、フック末尾で元の `test` を実行してフラグを立てる。Proc2／Proc3 はLinuxに対応箇所が無いため未変更で、v1.37.5では従来どおりバージョンエラーを返す（opt-in配線では致命的ではない）。
- 添字を2進める先（レジスタかスタック上のdwordか）は箇所ごとに逆アセンブルで特定したが、エスケープ経路は通常の英語表示では通らないため、実証は項目21に残る。
- 検証: `make test` 9モジュール通過、`make all` 成功。smoke runs/20261121-152852（opt-in＋SetTextプローブ）で5箇所全てのJMP作成ログを確認し、件数不一致は無かった。DLL [OK]、SetText id=0 result=applied、Exitで正常終了（eu4_wait=0）。メニュー画面のスクリーンショットで通常の英語表示に崩れが無いことを目視確認した。

## 変換器の接続（2026/11/21、項目20）

- 詳細は `memory-bank/details/settext_escape_wiring.md` に記録した。`settext_hook.d` で、非ASCIIの置換先を読み込み時に `escape_codec` でエスケープ形式へ変換し、容量チェックには変換後の長さを使うよう配線した（ASCII置換は従来どおり）。
- 前回の項目20で出た異常（画面真っ黒・eu4_wait=7）は、実はクラッシュだった（ミニダンプ生成を確認）。切り分けの結果、原因は項目19フックの復号経路にあると特定した: Linuxのグリフ表は +0x100 に256件しかないのに、フックが復号後のコードポイント（漢字・かな、NOT_DEF 0x2026 を含む）でそのまま引いており、範囲外のゴミポインタを呼び出し側が参照していた。
- 修正: 5フック全てで、コードポイントが 0x100 以上ならグリフポインタを null にする（全ての呼び出し箇所は null を安全にスキップする）。通常フォントでは日本語は描かれず飛ばされる。実際に描くには日本語グリフを含むフォントが要り、それは項目21で見る。
- 検証: `make test` 9モジュール通過、`make all` 成功。smoke は復号OFF＋日本語（runs/20261121-155643）、復号ON＋日本語（runs/20261121-155958）、復号ON＋英語（runs/20261121-160231）の3本とも正常終了（eu4_wait=0）で、メニュー画面の目視でも英語表示に崩れは無かった。

## Character set and font generation method (2026/11/21, item 22)

- Recorded in `memory-bank/details/charset_and_font_generation.md`. Collected the value character set from the 145 yml files (126,796 entries): 3,130 distinct characters, none above the BMP, none in the (0x100, 0xA00) shift band. Font ids equal the code points except the 5 CP1252 specials, which will be registered at both the byte id and the code point. EU4fontcreate agrees with escape_codec on CP1252 and on the +0xE000 shift direction; its stated shift band (0x100-0x1FF, example U+03BB) differs from the codec band (0x100, 0xA00), but with zero affected characters the codec stays ground truth. Its 0x0E/0x0F date glyphs are not adopted.
- Generation method decided: a self-contained Python Pillow + fontTools generator with Noto Sans CJK JP Regular (coverage 3,127/3,130; the 3 missing are non-printing and become empty glyphs), emitting a vanilla-form text .fnt + TGA atlas. PoC in ~/work/eu4-run/item22/poc/. BMFont/bmfont64.exe (Windows) and fontforge (not installed) were rejected with reasons.
- Blockers for items 23/24 recorded in the same file: the item 20 guard (null glyph for code points >= 0x100 on hooked paths) and the item 21 Game Browser path that bypasses the hooks.

## Font generation and placement (2026/11/21, item 23)

- Recorded in `memory-bank/details/font_generation_item23.md`. Generated 16 UI text fonts (vic_18, vic_18_grey, standard, standard_18, vic_22, vic_22_bl, standard_22, vic_29, vic_36, Arial12, garamond_12/14/14_bold/16/16_bold/24) with the item 22 method (Pillow + Noto Sans CJK JP, Regular/Bold per vanilla bold flag), 3,218-3,240 glyphs each (item 22 charset ids incl. CP1252 dual registration, union each font's vanilla ids), vanilla-form .fnt + RGBA TGA. lineHeight/base use the source font metrics (PoC precedent), not the vanilla Garamond values. Mapfont, tahoma and the shadow (vic_*s) variants were left out with reasons recorded.
- Placement: the translation mod folder is not agent-writable (verified), so the files stay in `~/work/eu4-run/item23/gfx/fonts/` (154 MiB) with placement steps in the details file; placement itself is the owner's task after returning home.
- Verification via a throwaway test mod in agent's own user folder (removed afterwards): run runs/20261121-162822 (no DLL) loaded the fonts and the main menu rendered normally in the new font (screenshot checked visually), ended_by_exit_button, eu4_wait=0. English rendering is not broken.
- FINDING: the stock .fnt parser rejects every char id >= 0x100 (`bitmapfont.cpp:436` Invalid character ID, 120,880 lines in that run's error.log; for vic_18 the accepted set is exactly the 218 ids <= 0xFF). A generated font alone therefore does not load its Japanese glyphs. The same count appeared in decode-opt-in runs, but DLL activation could not be confirmed in those runs (no DIAGNOSTIC-RAW lines, no fresh pattern_eu4jps.log, unlike all DLL runs up to 16:07 today; same .so and EU4 binary, cause unproven), so whether the item 17 limiter patch covers this parser check is UNVERIFIED. Item 24 needs this parser check investigated (and DLL activation in smoke runs re-confirmed) first.
- Also recorded: vic_36/vic_29/garamond_24 TGAs (33/17/17 MiB) exceed the vanilla 16 MiB texture cap and depend on the item 18 FontSizeLimit patch being active.

## Japanese display check after font placement (2026/11/21, item 24)

- Recorded in `memory-bank/details/font_display_check_item24.md`. Placement was simulated with a throwaway test mod in agent own user folder (all 32 item 23 font files, removed afterwards, user folder restored), run runs/20261121-165545-multiplayer with EU4DLL_ENABLE_DECODE=1, EU4DLL_SETTEXT_PROBE=1, EU4DLL_SETTEXT_REPLACEMENTS for Back to the Japanese word.
- Result NEGATIVE: the Game Browser bottom-left button shows plain English "Back" (screenshot checked visually); menu and Game Browser otherwise render normally in the generated font, no corruption.
- Blocker 1 re-confirmed: the DLL did not activate in this run (no DIAGNOSTIC-RAW lines, no fresh pattern_eu4jps.log), the same unexplained absence since 16:07 today, reproduced with the variables explicitly set and the same .so/binary; cause unproven. The replacement was therefore never applied.
- Blocker 2 re-confirmed: with the fonts loaded, error.log again has exactly 120,880 bitmapfont.cpp:436 Invalid character ID lines, so all glyphs >= 0x100 are dropped at load time regardless of the DLL.
- Items 1-24 are now all accounted for. Remaining work is blockers (a) DLL activation and (b) the .fnt parser check, plus the item 22 blockers; no new item started.

## DLL inactivation root cause (2026/11/21, item 25)

- Recorded in `memory-bank/details/dll_inactivation_item25.md`. The "DLL stopped activating after 16:07" phenomenon is solved: `make test` (dub build --build=unittest for the default configuration) overwrites libeu4dll.so with a unittest build whose crt_constructor hijack() is a NOP under version(unittest), so the .so loads silently with no DIAGNOSTIC-RAW lines and no pattern_eu4jps.log.
- Proven by reproduction: after `make test` the .so md5 is 24a49710b4b6eeee5042b9da6958a633 (exactly the value item 24 recorded during the failing period; /bin/true preload prints nothing, exit 0), and `make all` restores the normal build md5 2e645e64952315dacad5ed762024a6dd (/bin/true preload prints both DIAGNOSTIC-RAW lines). Items 22-24 ran their smokes while the unittest build was in place.
- Restoration verified: smoke runs/20261121-170719 (decode opt-in + SetText probe Back=Home) shows DIAGNOSTIC-RAW lines, a fresh pattern_eu4jps.log with SetText id=0 result=applied, DLL [OK], ended_by_exit_button, eu4_wait=0; menu screenshot checked visually, normal English, no corruption.
- Going forward: after any `make test`, run `make all` and confirm the normal build (the /bin/true DIAGNOSTIC check) before smoking. Item 24's Invalid character ID count is not evidence about the item 17 limiter, because the DLL was inactive in those runs; item 26 re-checks it with an active DLL.

## Font charset table limit (2026/11/21, item 26)

- Recorded in `memory-bank/details/font_charset_table_limit_item26.md`. With the DLL active, bitmapfont.cpp:436 Invalid character ID = 0 (run runs/20261121-171402), so the item 17 limiter does cover the parser check; no separate parser patch is needed.
- New blocker identified: the CBitmapCharacterSet glyph table embedded at CBitmapFont+0x100 has exactly 0x100 pointer entries (ctor memset 0x800 bytes; charset destructor iterates 0x100 entries, then the kerning unordered_map at charset+0x800). ParseFontFile indexes it by id with no bounds check, so every id >= 0x100 reads/writes other object fields or heap memory: false Duplicate character ID reports (bitmapfont.cpp:431) for non-zero words, and glyph pointer writes into unrelated memory for zero words.
- Minimal reproduction (runs/20261121-172215, throwaway test mod removed afterwards): standard.fnt with only ids 256, 1000 and 8199 added - all three reported Duplicate, Invalid = 0, game reached the menu and ended by the Exit button, menu screenshot visually normal. This corrects the earlier reading that duplicates start at 8199 (the generated .fnt files simply contain no ids between 256 and 8198).
- The full-font segfault in runs/20261121-171402 (116,338 Duplicate lines, crash ~4s after launch) is consistent with this overflow. Generated Japanese glyphs are therefore NOT loaded, and item 27 must not be run until a real wide-glyph table fix (side table or table expansion with all indexers fixed up) is implemented as a new item.

## Wide glyph table design (2026/11/21, item 28 part 1)

- Recorded in `memory-bank/details/glyph_table_expansion_item28.md`. Design decided: DLL-owned side table for ids >= 0x100 only (EU4CHS map direction), keyed by (font base, code point); ids < 0x100, the charset destructor loop and byte-keyed kerning stay vanilla. Wide glyphs leak until process exit (bounded, about 0.75 MiB for all generated fonts); accepted for the first implementation.
- Registration: both ParseFontFile sites verified unique in the whole binary by byte scan - duplicate check VA 0x204e385 (`48 83 BC C8 00 01 00 00 00`, 1 hit) and glyph store VA 0x204e563 (`4A 89 84 E9 00 01 00 00`, 1 hit). Both get 14-byte absolute-jump trampolines under the decode opt-in; the duplicate-check trampoline must reproduce the branch decision (return to 0x204e527 empty / 0x204e394 occupied).
- Fetch inventory (objdump over VA 0x204d000-0x2058000): 15 fetches with 0x100 displacement. Five are the item 19 hooked sites (FillVertexBuffer x2, GetActualRequiredSize, GetRequiredSize, GetActualRealRequiredSizeActually); GetRequiredSize and GetActualRealRequiredSizeActually each have a SECOND unhooked fetch (0x205664f, 0x2056df7); eight more are unhooked (RenderToTexture x2, RenderToScreen x2, GetHeightOfString, GetWidthOfString, Render3d x2) and need per-site index-width analysis before any patch. SetCharacter has no call site found (UNPROVEN); kerning is unsigned-char keyed and needs no redirect; map-text charset users are out of scope.
- Implementation order for the next runs: (1) side-table D module with unittests, (2) ParseFontFile registration redirect verified with the item 26 minimal font, (3) item 19 hooks lookup the side table instead of returning null for >= 0x100, (4) width analysis / redirect of the remaining fetch sites, (5) full 16-font check. Item 27 stays blocked until item 28 completes.

## Wide glyph side table module (2026/11/21, item 28 step 1)

- Recorded in memory-bank/details/glyph_table_expansion_item28.md (implementation step 1). New pure module source/plugin/glyph_table.d: WideGlyphTable keyed by (font base, code point) for ids >= 0x100, refusing non-wide, null and duplicate registrations, with extern(C) wideGlyphRegister/Lookup/ClearAll/Count wrappers for the later trampolines.
- Verification: make test 10 modules passed (was 9; threshold, item 26 ids 256/1000/8199, duplicate, per-font isolation, 3,022-entry scale, global wrappers), make all OK and finished last (normal build, DIAGNOSTIC-RAW present). No smoke: no runtime patch yet.
- Next: item 28 step 2 - ParseFontFile registration redirect, verified with the item 26 minimal font (Duplicate must become 0).

## Wide glyph fetch redirect (2026/11/21, item 28 step 3)

- Recorded in memory-bank/details/glyph_table_expansion_item28.md (implementation step 3). The five item 19 v1.37.5 fetch hooks in source/plugin/main_text.d now resolve decoded code points >= 0x100 through wideGlyphLookup(font base, code point) instead of returning null; a miss still returns null. Font-base registers per site and the RSP-alignment / live-register argument are recorded in the details file and in a comment at the hooks.
- Verification: make test 10 modules passed, make all OK and run last (normal build). Smoke runs/20261121-175544 (item 26 minimal font, throwaway mod removed afterwards, EU4DLL_ENABLE_DECODE=1): all five fetch and both registration injector lines present, Duplicate = 0, Invalid = 0, ended_by_exit_button, eu4_wait=0, menu screenshot visually normal English.
- Next: item 28 step 4 - width analysis of the eight not-hooked fetch sites and the two second fetches in GetRequiredSize / GetActualRealRequiredSizeActually.

## Wide glyph fetch width analysis (2026/11/21, item 28 step 4)

- Recorded in memory-bank/details/glyph_table_expansion_item28.md (implementation step 4). All eight not-hooked fetch sites (RenderToTexture x2, RenderToScreen x2, GetHeightOfString, GetWidthOfString, Render3d x2) index the glyph table with a zero-extended single byte (movzbl from a CString::operator[] result or a direct string byte), and the two second fetches in GetRequiredSize (0x205664f) and GetActualRealRequiredSizeActually (0x2056df7) use a sign-extended single byte (movsbq, range -128..127). No wide code point >= 0x100 can reach any of them, so no redirect is needed; no runtime code changed in this step.
- Next: item 28 step 5 - full check with all 16 generated fonts placed via the throwaway test mod, decode opt-in on (no Duplicate flood, no Invalid lines, no crash, English menu screenshot normal). Item 27 stays blocked until item 28 completes.

## Wide glyph full-font check (2026/11/21, item 28 step 5) - item 28 complete

- Recorded in memory-bank/details/glyph_table_expansion_item28.md (implementation step 5). Smoke runs/20261121-180844 with all 16 generated fonts (32 files) via the throwaway test mod testfonts_item28 (removed afterwards, user folder restored) and EU4DLL_ENABLE_DECODE=1: Duplicate character ID = 0, Invalid character ID = 0, no crash, ended_by_exit_button, eu4_wait=0, menu screenshot visually normal English. The item 26 full-font segfault is gone.
- Item 28 is complete. Next: item 27 - Japanese display re-check (Game Browser) with the generated fonts placed.

## Japanese display re-check (2026/11/21, item 27) - item 27 complete, items 27/28 done

- Recorded in memory-bank/details/font_display_recheck_item27.md. Smoke runs/20261121-181435-multiplayer with all 16 generated fonts via the throwaway test mod testfonts_item27 (removed afterwards, user folder restored), EU4DLL_ENABLE_DECODE=1, EU4DLL_SETTEXT_PROBE=1, Back replaced with the Japanese word for it: DLL active, SetText id=0 result=applied, Duplicate = 0, Invalid = 0, no crash, menu screenshot visually normal English.
- Result NEGATIVE for display: the Game Browser bottom-left button shows four glyphs (I, b, boxed-X, 0), which are exactly the escaped bytes 11 49 62 10 8B 30 rendered byte by byte. Path identified: this button is drawn by a byte-width CBitmapFont path (RenderToScreen/RenderToTexture/GetWidthOfString family, item 28 step 4), not by the five hooked TextView functions, so escapes are never decoded there.
- Items 27 and 28 are both complete. Japanese on this class of UI text needs a new item (decode escapes inside the byte-wise BitmapFont paths); do not start it without owner instruction.

## Byte-width BitmapFont decode (2026/11/21, item 29 step 1)

- Recorded in `memory-bank/details/bitmapfont_bytewidth_decode_item29.md`. Implemented the first byte-width decode hook: `CBitmapFont::GetWidthOfString` fetch at VA 0x2054027 now decodes escape sequences (0x10-0x13 + word, same shifts and NOT_DEF band as the TextView hooks), advances the loop index by 2 extra bytes, and resolves ids >= 0x100 via the item 28 side table. AOB verified exactly 1 hit in a full binary scan; opt-in only, installed from the Proc4 injector v1.37.5 case.
- Analysis recorded for the next steps: RenderToScreen site 1 (VA 0x2052189) is the width/line-break pass over the original string and also builds the global pText buffer; site 2 (VA 0x2053084) is the draw pass and re-reads the raw bytes from pText, so site 1 alone cannot fix drawing - the pText interaction must be decided first. RenderToTexture x2, GetHeightOfString and Render3d x2 still need per-site analysis.
- Verification: `make test` 10 modules passed, `make all` run last (normal build, DIAGNOSTIC-RAW present). Smoke runs/20261121-183436-multiplayer (decode opt-in, SetText probe, Japanese Back replacement, vanilla fonts): GetWidthOfString JMP line present with all earlier JMP lines, SetText id=0 result=applied, no crash, menu and Game Browser screenshots visually normal English; the button still shows byte glyphs, as expected before the RenderToScreen work and without the generated fonts.
- Item 29 is NOT complete. Next: RenderToScreen site 1 + site 2 (pText) decision and implementation.

## Byte-width BitmapFont decode (2026/11/21, item 29 step 2)

- Recorded in memory-bank/details/bitmapfont_bytewidth_decode_item29.md (step 2). Implemented both RenderToScreen byte-width decode hooks: site 1 (width/line-break pass, VA 0x2052189, patch at 0x2052184) decodes escapes for measuring and keeps the full 3-byte escape sequence in the scratch buffer so the global pText buffer carries it; site 2 (draw pass, VA 0x2053084, patch at 0x205307f) decodes the sequence again from pText and resolves wide glyphs via the side table. Both AOBs re-verified exactly 1 hit in a full binary scan; opt-in only, installed from the Proc4 injector v1.37.5 case. The wide paths spill the live XMM low halves around the lookup call (site 1: XMM1-XMM3; site 2: XMM0-XMM5).
- Verification: make test 10 modules passed, make all run last (normal build, DIAGNOSTIC-RAW present). Smoke runs/20261121-184743-multiplayer (decode opt-in, SetText probe, Japanese Back replacement, vanilla fonts): both RenderToScreen JMP lines present with all earlier lines, SetText id=0 result=applied, no crash, menu and Game Browser screenshots visually normal English. The Game Browser button still shows byte glyphs, which with vanilla fonts points to a remaining unhooked path (RenderToTexture candidates) rather than these two sites.
- Item 29 is NOT complete. Next: step 3 - RenderToTexture x2, GetHeightOfString, Render3d x2 analysis and hooks.

## Byte-width BitmapFont decode (2026/11/21, item 29 step 3)

- Recorded in memory-bank/details/bitmapfont_bytewidth_decode_item29.md (step 3, sections 7-9). Per-site analysis of the remaining five fetch sites (RenderToTexture x2, GetHeightOfString, Render3d x2): all five read their byte via CString::operator[], whose body proves a CString data pointer sits at offset 0, so a hook can read the escape payload word directly without calling operator[]. Every site has a single index register, a common tail that adds 1, and a verified AOB: RenderToTexture site 1 (fetch 0x204ef59, index R14D, font [rsp+0x38], out RBP, tail inc at 0x204f576), RenderToTexture site 2 (fetch 0x2051088, index R14D, font R13, out R11, tail inc at 0x2051489, live XMM8), GetHeightOfString (fetch 0x2053d56, index EBP, font RBX, out RAX, tail inc at 0x2053eb2), Render3d site 1 (fetch 0x20546d7, index R15D, font R12, out RBX), Render3d site 2 (fetch 0x2054cd0, index R15D, font R12, out RAX, live XMM10; short AOB has 4 hits, the long form with the je target and XMM10 reload has exactly 1). All other AOBs exactly 1 hit in a full binary scan.
- Decision: no site is unhookable, but none is implemented in this step - patch/return offsets, index and glyph registers and live XMM sets all differ per site, and a wrong spill crashes the game, so implementing all five at once would make a smoke failure unbisectable. Split: step 4 = RenderToTexture x2 hooks (prime suspects for the Game Browser button), step 5 = GetHeightOfString + Render3d x2, after pinning the Render3d draw-pass loop tail (still open).
- Item 29 is NOT complete. Next: step 4 - RenderToTexture site 1 + site 2 decode hooks.

## Byte-width BitmapFont decode (2026/11/21, item 29 step 4)

- Recorded in memory-bank/details/bitmapfont_bytewidth_decode_item29.md (step 4). Implemented both RenderToTexture byte-width decode hooks: site 1 (measuring / line-break pass, fetch VA 0x204ef59, patch at the preceding movzbl VA 0x204ef51, 16-byte patch) and site 2 (draw pass, fetch VA 0x2051088, patch at VA 0x2051085, 14-byte patch), both in CBitmapFont::RenderToTexture, decoding escapes at the CString::operator[] result pointer and resolving ids >= 0x100 via the side table. Both AOBs re-verified exactly 1 hit in a full binary scan in this run; opt-in only, installed from the Proc4 injector v1.37.5 case. Wide paths spill XMM low halves around the lookup call (site 1: XMM0-XMM5 insurance; site 2: XMM0-XMM5 plus XMM8).
- Verification: make test 10 modules passed, make all run last (normal build, DIAGNOSTIC-RAW present). Smoke runs/20261121-190418-multiplayer (decode opt-in, SetText probe, Japanese Back replacement, vanilla fonts): both RenderToTexture JMP lines present with all earlier lines, SetText id=0 result=applied, no crash, screenshots visually normal English. The Game Browser bottom-left button is now EMPTY instead of the byte glyphs of steps 1-2, which is the expected vanilla-font result (decoded wide glyph is null and skipped) if the button draws through RenderToTexture - the decode now reaches this path.
- Item 29 is NOT complete. Next: step 5 - GetHeightOfString + Render3d site 1 + site 2 hooks, after pinning the Render3d draw-pass loop tail.

## Byte-width BitmapFont decode (2026/11/21, item 29 step 5)

- Recorded in memory-bank/details/bitmapfont_bytewidth_decode_item29.md (step 5). Implemented the last three byte-width decode hooks: GetHeightOfString (fetch VA 0x2053d56, patch at 0x2053d53), Render3d site 1 (fetch VA 0x20546d7, patch at 0x20546d4) and Render3d site 2 (fetch VA 0x2054cd0, patch at 0x2054ccd, long AOB), all decoding escapes at the operator[] result pointer and resolving ids >= 0x100 via the side table. The Render3d draw-pass loop tail left open in step 3 is pinned: all paths converge on inc R15D at VA 0x2055218 (measuring tail inc R15D at VA 0x205496a). All three AOBs re-verified exactly 1 hit in a full binary scan; opt-in only. Wide paths spill XMM low halves (site 2 also XMM10).
- Verification: make test 10 modules passed, make all run last (normal build, DIAGNOSTIC-RAW present, .so md5 e3d3b28224ce4b712a8d8a5a03c94196). Smoke runs/20261121-191301-multiplayer (decode opt-in, SetText probe, Japanese Back replacement, vanilla fonts): all three new JMP lines present with all earlier lines, DLL [OK], SetText id=0 result=applied, no crash, screenshots visually normal English, Game Browser button stays empty as after step 4.
- Item 29 is COMPLETE: every byte-width fetch site from the item 28 inventory now decodes escapes (GetWidthOfString, RenderToScreen x2, RenderToTexture x2, GetHeightOfString, Render3d x2). Next: item 30 - final Japanese display check with the generated fonts placed.

## Final Japanese display check (2026/11/21, item 30)

- Recorded in `memory-bank/details/font_display_final_item30.md`. Smoke runs/20261121-192004-multiplayer with all 16 generated fonts via the throwaway test mod testfonts_item30 (removed afterwards, user folder restored), EU4DLL_ENABLE_DECODE=1, EU4DLL_SETTEXT_PROBE=1, Back replaced with the Japanese word for it: all item 29 JMP lines present, SetText id=0 result=applied, Duplicate = 0, Invalid = 0, no crash, menu screenshot visually normal English.
- Result NEGATIVE: the Game Browser bottom-left button does not show the Japanese word. It shows only an ellipsis-like three dots at the text baseline, where item 27 showed the raw escaped-byte glyphs and item 29 with vanilla fonts showed an empty button. Font data is sane (both code points present in all 16 .fnt files with normal xadvance), so the remaining blocker is upstream or at lookup time: either a GUI-side measuring/truncation step outside the hooked sites substitutes an ellipsis, or the side-table lookup misses for this button's font instance and NOT_DEF (U+2026) is drawn.
- Item 30 is complete as a check; items 1-30 are all accounted for. Next step needs owner instruction: a new item to add opt-in per-decode logging (font pointer, code point, side-table hit/miss) to the byte-width hooks and identify which explanation holds.

## Ellipsis distinguishing (2026/11/21, item 31)

- Recorded in `memory-bank/details/ellipsis_distinguish_item31.md`. Added opt-in side-table debug logging to `source/plugin/glyph_table.d` (`EU4DLL_GLYPH_DEBUG=1`, off by default, fd-2 writes, only U+623B / U+308B / U+2026 logged so the full run stays at 265 lines; formatter and filter unit-tested, make test 10 modules passed).
- Smoke runs/20261121-193152-multiplayer with all 16 generated fonts via the throwaway test mod testfonts_item31 (removed afterwards, user folder restored), decode + glyph debug + SetText probe on, same Japanese Back replacement as items 27/30: SetText id=0 applied, Duplicate = 0, Invalid = 0, no crash, screenshots visually normal English UI; the button again shows only the three dots.
- Result: explanation 2 is RULED OUT and explanation 1 holds. All three code points register-hit on 40 font instances; the only load-time misses are the duplicate checks immediately before registration; at render time both Japanese code points lookup-HIT 10 times each on the single font instance used (0xfdde650), in five groups of (U+623B, U+308B) x2 followed by one U+2026 hit - the string is measured, the glyphs resolve, and the GUI control still draws only the ellipsis. The blocker is the GUI-side width check / truncation for button text, not the font, the decode or the side table.
- Item 31 is COMPLETE. Next: item 32 - locate the GUI button width-check/truncation site, fix the width it computes for escaped text, and re-check the Game Browser button.

## Ellipsis fix, caller identification (2026/11/21, item 32 step 1)

- Recorded in memory-bank/details/ellipsis_fix_item32.md. The opt-in glyph debug log now also records the caller (return address inside the calling trampoline, as an offset from wideGlyphLookup, via llvm.returnaddress), so each render-time lookup can be attributed to a fetch site.
- Smoke runs/20261121-194451-multiplayer with all 16 generated fonts via the throwaway test mod testfonts_item32 (removed afterwards, user folder restored), decode + glyph debug + SetText probe on, same Japanese Back replacement as items 27/30/31: SetText id=0 applied, side table 120,880 entries, no crash, screenshots show the same three-dots button and otherwise normal English UI.
- Result: per render group, both Japanese code points are fetched by the GetRequiredSize hook and by the RenderToTexture site 1 (measuring) hook, and the ONLY glyph fetched by the RenderToTexture site 2 (draw) hook is U+2026. The ellipsis substitution therefore happens inside CBitmapFont::RenderToTexture, between its measuring/line-break pass and its draw pass; the draw pass reads a line buffer that already decodes to a single U+2026 (no 0x2026 immediate exists in RenderToTexture).
- Item 32 is NOT complete. Next: step 2 - find where RenderToTexture builds the draw-pass line buffer and where its fit check fails for escaped text, fix it, and re-check the Game Browser button.

## Ellipsis fix, draw-pass buffer dump (2026/11/21, item 32 step 2)

- Recorded in memory-bank/details/ellipsis_fix_item32.md (section 6). The RenderToTexture site 1 / site 2 wide paths now call wideGlyphRawLog (same EU4DLL_GLYPH_DEBUG opt-in) to dump the raw bytes of the string each pass reads; make test 10 modules passed, make all run last (.so md5 37484c609b1d90de8b75642811d25b16).
- Smoke runs/20261121-195701-multiplayer with the throwaway test mod testfonts_item32s2 (removed afterwards, user folder restored), decode + glyph debug + SetText probe on, same Japanese Back replacement: SetText id=0 applied, no crash, screenshot shows the same three-dots button and otherwise normal English UI.
- Result: site 1 (measuring) reads the full escaped string `11 49 62 10 8b 30`; site 2 (draw) reads a different 2-byte buffer `11 10` - only the lead byte of each escape sequence, payload bytes dropped. That buffer's first pseudo-escape (word 0x0010, minus SHIFT_2 = 0x0002) falls in the NO_FONT band and is mapped to NOT_DEF (U+2026), and the index advance of 3 ends the loop, so exactly one ellipsis glyph is drawn. The substitution site is the per-character 1-byte copy that builds the line buffer between the two passes.
- Item 32 is NOT complete. Next: step 3 - locate that copy in RenderToTexture (region VA 0x204f000-0x2051000), fix it to copy all 3 bytes of an escape sequence, and re-check the Game Browser button.

## 2026-11-21 - Item 32 step 3: line-buffer 1-byte copy fixed (item 32 COMPLETE)
- Located the copy: RenderToTexture measuring loop head (VA 0x204ea0e) appends one byte per iteration to the word buffer CString at 0x58(%rsp) via CString(char) + operator+=(move); the site 1 hook advances the index by 3 per escape, so only lead bytes (11 10) reached the stored line buffer. A Ghidra headless import was started (project ~/work/ghidra-eu4/proj EU4Proj) but was still analysing at commit time; identification rests on disassembly + live evidence.
- Fix: mainTextRenderToTextureV137LineBuf_hook patches the loop head (60 bytes, AOB 1 hit) and appends all 3 bytes of an escape sequence with the same construct/append/cleanup sequence; returns at VA 0x204ea4a.
- Verify: make test 10 modules passed, make all run last (.so md5 2e79fa621626cbfbec2c1109278c4a98). Smoke runs/20261121-200810-multiplayer (throwaway mod removed, user folder restored): draw pass now reads the full escaped string and fetches both Japanese code points; screenshot shows the Game Browser button rendering the Japanese word correctly, English UI otherwise normal, Duplicate=0, no crash.
- Item 32 is COMPLETE. Details: memory-bank/details/ellipsis_fix_item32.md section 8.

## 2026-11-21 - Decode default-on (post item 32)
- Owner decision: decode runs by default; EU4DLL_ENABLE_DECODE=0 opts out. dllmain.d helper flipped from opt-in ("1") to opt-out ("0"), unit tests updated, log lines reworded. Details: memory-bank/details/decode_default_enablement.md.
- Verify: make test 10 modules passed, make all run last. Smoke runs/20261121-210753 (no env: decode-enabled log line, menu, Exit, eu4_wait=0) and runs/20261121-211038 (=0: skip log line, menu, Exit, eu4_wait=0). The aggregate decode-error line also appears in the verified item 32 runs, so it is the known state.

## 2026-11-21 - SetText dictionary from translation files (Stage B + C)
- settext_hook can now be fed from the translation files instead of the env-var probe: EU4DLL_SETTEXT_FROM_TRANSLATIONS=1 joins translationMap with the game English localisation (new mod.d loadLocalisationMap / gameLocalisationDir / joinTranslationDictionary) and feeds tryReplaceDict through a dynamic ProbeMapping[] + exact-match AA (Stage C storage). EU4DLL_SETTEXT_REPLACEMENTS still wins when set (source=env logged); probe logs and the init gate are unchanged.
- Join rules pinned by tests: both-sides keys only, same-English/same-Japanese deduplicated, same-English/different-Japanese dropped as ambiguous. Load line reports source=translations with loaded and per-reason skip counts.
- Verify: make test 10 modules passed (new cases in test_mod.d and settext_hook unittest), make all run last. No smoke run this time. Rough count over the real files: ~106k joined English strings, ~92.5k would load after the 256-byte limits. Details: memory-bank/details/translation_dict_stage_b.md.

## 2026-11-21 - Translation dictionary verification + load-conversion finding
- Run runs/20261121-212246-multiplayer (throwaway mod: all 145 placed yml + 32 fonts, PROBE=1 + FROM_TRANSLATIONS=1, no env replacements): dictionary loaded=42886 (joined=46845, ambiguous=491), one SetText replacement applied, no crash. Details in memory-bank/details/translation_dict_stage_b.md.
- Finding: with the localisation mod enabled, the game loads the Japanese values itself and renders every Japanese character as '?' (Game Browser screenshot). The UTF-8-to-internal conversion at localisation load is the broad-coverage blocker; the SetText dictionary only covers strings that reach SetText in English. Next investigation: identify and hook the localisation load conversion point.

## 2026-11-21 - Localisation-load escape hook
- New opt-in entry hook on LocalizeYmlAddKey (EU4DLL_LOCALIZE_ESCAPE=1, v1_37_5 only): with the pData+0x38 flag set, a pure-ASCII key and a non-ASCII value are stored directly through SLanguageData::AddKeyValuePair with the value escape-encoded by escape_codec, skipping ConvertUTF8ToLatin1 and its '?' substitution; every other case (flag clear, non-ASCII key, ASCII value, unencodable value) delegates to the original. AddKeyValuePair and the pData global are derived at run time from the function's own rel32/rip-relative instructions (byte-checked, cross-verified against the flag-clear tail jump), never hardcoded.
- Verify: make test 11 modules passed (decision cases + derivations pinned against the real instruction bytes), make all run last. No smoke run yet; end-to-end rendering of hook-stored values is the next check. Details: memory-bank/details/localize_escape_hook.md.

## 2026-11-21 - Localize escape hook verification: stores work, crash in GetHeightOfString
- Run runs/20261121-213554-multiplayer (throwaway mod: 145 yml + 32 fonts, EU4DLL_LOCALIZE_ESCAPE=1): hook installed at the surveyed addresses, first escaped store logged, then SIGSEGV before the menu. Crash stack: CBitmapFont::GetHeightOfString <- CInstantTextBox::UpdateScrollbarSize <- CTutorial::Init. GetHeightOfString is a measure path the decode hooks do not cover yet; escaped dictionary values reach it via tutorial text. Details: memory-bank/details/localize_escape_hook.md. Next: survey and extend decode coverage to that path.

## 2026-11-21 - Wide-path glyph result fix (GetHeight + Render3d site 2)
- Implemented the patch plan of getheightofstring_decode_survey.md unchanged: in mainTextGetHeightV137_hook and mainTextRender3dV137Site2_hook the wide path no longer pushes/pops RAX around wideGlyphLookup (the pop overwrote the glyph pointer with the code point id - the GetHeight SIGSEGV at VA 0x2053d67, and a latent twin in Render3d site 2). Stack adjustment sub/add RSP 48 -> 40 keeps the total a multiple of 16. No AOB, patch length, return address, or constant changes.
- Grep re-check of every push/pop RAX site in main_text.d and font.d: all other sites copy the result out of RAX (or, for glyphStore, ignore it by design); no other instance of the pattern. Details: memory-bank/details/decode_widepath_fix.md.
- Verify: make test 11 modules passed, make all run last (.so md5 e2bfd99fe75344c6fe2bf5ab81042705). No smoke run yet; the survey's real-machine verification (localisation-escape rerun, then Render3d map labels) is next.

## 2026-11-21 - Wide-path fix verified: Game Browser renders Japanese
- Run runs/20261121-214814-multiplayer (branch work/decode-widepath-fix, throwaway mod: 145 yml + 32 fonts, EU4DLL_LOCALIZE_ESCAPE=1): no crash, menu and multiplayer reached, eu4_wait=0. Game Browser shows Japanese across the screen (search boxes, headers, Back button) instead of '?'. Checkbox labels partly overlap and two narrow headers truncate; layout quality is a follow-up. Render3d site 2 (map labels) fixed in the same commit but not yet exercised. Details: memory-bank/details/localize_escape_hook.md.

## 2026-11-21 - Country-select screen renders Japanese; map labels still open
- Run runs/20261121-215310-single: country-select screen fully Japanese (bookmarks, country panel, description text, buttons), no crash. The script's clicks missed France and the Start button, so the in-game map (Render3d site 2 labels) is still unverified. Details: memory-bank/details/localize_escape_hook.md.

## 2026-11-21 - Preload guard: DLL stays inert outside the EU4 process
- Steam launches died silently because LD_PRELOAD put the DLL into every launcher/runtime helper and hijackProcess exit(-1) killed each one (measured: preloaded /bin/true exited 255). The crt_constructor in dllmain.d now checks the /proc/self/exe basename via pure isEu4ExecutablePath and returns immediately in non-EU4 processes; EU4-side behaviour unchanged. make test: 11 modules pass. Preloaded /bin/true now exits 0 silently, /bin/echo works, /bin/false keeps exit 1, no pattern log created. In-game behaviour not re-run on the machine (CPU); owner's next Steam launch is the confirmation. Details: memory-bank/details/preload_guard.md.

## 2026-11-21 - Localisation escape hook on by default
- localize_escape_hook.d: new pure helper localizeEscapeEnabled (value != "0", same shape as decodeEnabled); initLocalizeEscapeHook installs unless EU4DLL_LOCALIZE_ESCAPE=0, logging the opt-out when it skips. Header comment updated; dllmain.d untouched. make test 11 modules passed, make all run last. No EU4 run (owner is playing); the default-on path is the code path already verified with =1. Details: memory-bank/details/localize_escape_default_enablement.md.

## 2026-11-21 - SetText file dictionary removed
- Folded the dictionary per settext_dict_position_review.md: the load hook covers yml localisation per key, the dictionary's own verification run applied exactly one replacement, and its mod-disabled configuration is blocked by the fonts living in the same mod. Removed loadLocalisationMap / gameLocalisationDir / joinTranslationDictionary (+ join structs) from mod.d; dictMode storage, loadTranslationDictMappings, buildDictMapping, findDictMapping, tryReplaceDict and the FROM_TRANSLATIONS branch from settext_hook.d; retired EU4DLL_SETTEXT_FROM_TRANSLATIONS and EU4DLL_GAME_LOCALISATION_DIR; dropped test_mod.d cases 8-12. The SetText hook and the EU4DLL_SETTEXT_PROBE / EU4DLL_SETTEXT_REPLACEMENTS probe stay. Verify: grep shows no remaining references, make test 11 modules passed, make all run last. Details: memory-bank/details/settext_dict_removal.md.

## 2026-11-21 - Owner confirms Japanese display on the real machine
- After merging work/preload-guard (940a26e) and pushing, the owner enabled eu4dll_translations in dlc_load.json, placed steam_appid.txt (236850) in the game folder, and launched eu4 directly with EU4DLL_LOCALIZE_ESCAPE=1 and LD_PRELOAD on his own build: all injector JMP logs present, DLL active, Japanese rendering confirmed in game by the owner (reported 2026-11-21 23:30). This also serves as the in-game confirmation for the preload guard.
- New owner feedback: the generated fonts look 2-3pt too large overall; font size adjustment is the next investigation.

## 2026-11-21 - Memory-bank cleanup
- TODO.txt rewritten: the 2026/08/29 content (SetText PoC era, all superseded) replaced by the current state, six remaining issues (font size adjustment, Render3d site 2 map labels, layout quality, LOCALIZE_ESCAPE default-on decision, SetText dictionary positioning, version-update AOB re-verification), verification policy, and completion criteria.
- activeContext.md rewritten: focus updated to the confirmed full-screen Japanese display, confirmed facts trimmed to those still in force, the 2026/08/29 survey sections compressed to details references, and the 2026-11-21 sections replaced by an item-to-details index. History remains in progress.md and details/.

## 2026-11-22 - TODO follow-up: LOCALIZE_ESCAPE default-on and SetText dictionary issues closed
- PR #7 (merged as b796de4) settled the two decisions the 2026-11-21 TODO still listed as open: the localisation escape hook is on by default (EU4DLL_LOCALIZE_ESCAPE=0 opts out) and the SetText file dictionary was removed. TODO.txt updated in PR #8: both items moved to a completed-decisions section, the remaining list renumbered (font size adjustment, in-game map labels, layout quality, version-update AOB re-verification), the completion criteria updated, and activeContext.md corrected on the same two points.

## 2026-11-22 - Debian package
- Added debian/ packaging (branch work/debian-package): one .deb bundles libeu4dll.so (usr/lib/eu4dll/), the eu4dll_translations mod data (localisation 145 yml + generated fonts 32 files, usr/share/eu4dll/mod/), and the eu4dll-launch / eu4dll-install-mod helper scripts. Mod data is copied at build time from EU4DLL_MOD_SRC because it is not stored in this repository. Build succeeds on the build machine (12.7 MB package); contents, the packaged library's preload-guard behaviour, and eu4dll-install-mod against a scratch data home were verified. Installing on a second machine and an in-game run from the package alone are not verified yet. Details: memory-bank/details/debian_packaging.md.
