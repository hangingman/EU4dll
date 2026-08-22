# Progress

## 翻訳ロードスキップ実機比較（2026/08/23）

- EU4 v1.37.5、Japanese Language mod無効、Waifu Universalis維持、`eu4dll_translations`有効の条件で、LD_PRELOAD + GDB実機に`EU4DLL_SKIP_TRANSLATIONS=1`を指定した。
- `SetText`最初の5ヒットはlength `0,0,0,13("Connect to ID"),4("Back")`で、翻訳ロードありの`ID??`/`??`から英語へ戻った。EU4は正常終了した。
- `loadTranslationMods()`単体または起動初期の大量YAML/Dランタイム/GC処理を文字列破損の有力原因と判定する。画面全体の正常表示はユーザーの手動確認を根拠とし、未確認なら断定しない。
- 設計方針を、constructor中の翻訳ロードを避け、EU4本体の正規localisation初期化後に適切な内部境界で観測・フックする形へ更新した。`SetText`フックは先に実装しない。`EU4DLL_SKIP_TRANSLATIONS=1`の診断実装は`source/plugin/dllmain.d`に既存で、通常動作を壊さない。

## SetText実引数文字列観測（2026/08/22）

- `tools/trace_eu4_settext_string.gdb` と `.sh` を追加した。既存のDLL付きwrapperを再利用し、`CTextSprite::SetText` の第1 `CString`（`rdx`）だけを観測する。`CreateTextSprite` と既存のtrace/previewスクリプトは変更していない。
- 対象関数の最初の5ヒットに限定し、CString/data NULLを除外、`+8` 長さが `1..64` の場合だけ `TRACE_STRING` と長さ分の `x/<length>xb` を `eval` で記録する。各READに `SETTEXT_READ_##` 識別子を付け、`x/s` は削除した。長さ0や範囲外は `SKIP` とし、無条件読出し、GDB Python、inferior呼出し、フック、メモリ書換えは追加していない。
- 旧版の実機 `/tmp/eu4dll-settext-string.log` では5ヒットを取得し、最初の3件は `length=0` のためSKIP、後2件はREADとなったが、GDB表示は `ID??` と `??` で非ASCIIバイトを判定できなかった。今回のバイト列版は実機未実施である。
- GDB標準機能では任意ポインタのreadable判定を保証できないため、条件を満たしても読出し失敗でGDB/EU4が終了する可能性がある。文字列内容、`MENU_BAR_*`との対応、置換可能性は未確認である。

## 次回再開時の直近タスク

- `x/s`では非ASCII文字が`?`になるため、`CTextSprite::SetText`の`rdx`について、最初の少数ヒットだけ限定長バイト列を16進で記録する。
- 得られたバイト列をASCII/UTF-8等として判定し、既存`translationMap`の表示値と照合する。実引数が表示値と一致しない限り、キー対応・置換可能とは断定しない。
- 一致後にのみLinux v1.37.5専用のAOB、命令境界、トランポリン、元処理復帰、W^X、再入、CString所有権・寿命を設計する。

## 今後のタスク

1. 実引数の文字列バイト列を同定する。
2. `translationMap`表示値との対応を確認する。
3. 置換なしの安全なSetTextフック方式を検証する。
4. 翻訳値1件を一時CStringへ置換するPoCを実装する。
5. 実機で表示、操作継続、正常終了を確認する。
6. 成功後に対象キーを複数化する。

## 再開時の直近タスク

- `SetText` の `rdx` を対象に、最初の少数ヒットだけ文字列バイト列を16進で記録する。`x/s` の `??` 表示に依存しない。
- バイト列をUTF-8/ASCII等として解析し、`translationMap`の表示値と照合する。実引数が表示値と一致しない限り、キー対応・置換可能とは断定しない。
- 一致後にLinux v1.37.5専用のAOB、命令境界、トランポリン、元処理復帰、W^X、再入、CString所有権・寿命を設計する。

## 今後のタスク

1. 実引数の文字列同定
2. `translationMap`表示値との対応確認
3. 置換なしの安全なSetTextフック設計・検証
4. 翻訳値1件の一時CString置換PoC
5. 実機で表示・操作継続・正常終了を確認
6. 成功後に複数キーへ拡張

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
