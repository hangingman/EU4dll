# Active Context

## YAMLキー修正（2026/08/22）

修正後に`TRACE_GDB="$PWD/tools/trace_eu4_text_preview.gdb" ./tools/trace_eu4_text_with_dll.sh`を実行した。`/tmp/eu4dll-all-key-preview-fixed2.log`は8009 bytes、GDB wrapperのエラーなし、`TRACE_PREVIEW`は20行（CreateTextSprite 10、SetText 10）で、EU4 v1.37.5は正常終了し最新ログに`DLL [OK]`がある。前回実行の最新ALLブロックは`key_count=117805`で全件loadedであり、今回の6キー実行はALLではない。

修正後の6キーはすべてloadedだった。`MENU_BAR_LOAD_GAME=ロード`、`MENU_BAR_LOAD=ロード`、`MENU_BAR_QUIT=ゲーム終了`、`MENU_BAR_SAVE_GAME=セーブ`、`MENU_BAR_GAME_OPTIONS=ゲームのオプション`、`MENU_BAR_CLOSE=閉じる`。`text_l_english.yml`も今回の6キー実行でパース成功し、以前の`Key 'true' appears multiple times`は修正で解消した。

残存していた`text_l_english.yml`の`Key 'true' appears multiple times in mapping`は、未クォートの`on`、`off`、`NO`、`YES`などをd-yaml 0.10.0がYAML 1.1の真偽値キーとして解決し、異なるキーを衝突させたものと確認した。`normalizeLocalizationYaml`で特殊スカラーに該当するマッピングキーだけをクォートし、BOM除去、`:0`〜`:9`変換、ヘッダー補完、通常の値を維持する最小修正を追加した。回帰テストは`true`、`false`、`null`、`YES`、`on`、`off`と6つの`MENU_BAR_*`キーを確認する。

これはYAMLロード、DLL、GDB TRACE_PREVIEW取得、EU4正常終了までの確認であり、日本語表示の実証ではない。TRACE_PREVIEWは候補CStringの`+0`データポインタと`+8`長さだけで、文字列本体は未読出し。長さはCreateTextSpriteが`7,7,13,13,18,13,6,32,32,13`、SetTextが`0,0,0,4,2,6,6,5,5,2`で、SetText文字列と翻訳キー・表示値の対応および置換可否は未確認である。実機起動、GDB、フック、インラインパッチ、open/readフックはこの作業では変更しない。

## 現在の焦点

Linux版EU4の文字列置換経路を、Ghidra先行ではなく実行時観測から特定する。

## 今回の判断（SetText置換PoC）

`CTextSprite::SetText` の置換フックは今回実装しない。実機で得られたのは候補CStringのメタデータだけで、`MENU_BAR_LOAD_GAME` のキー・表示値との一致、各引数の意味、バッファの寿命と所有権が未確認である。さらに既存の `makeJmp` / `ScopedPatch` は5バイトJMPを無条件に書き込むだけで、SetText先頭の命令境界、上書き命令のトランポリン復帰、相対アドレス範囲、一意AOB、パッチ適用時の競合を検証しない。未確認の文字列を本体へ渡す安全な一時CStringも設計できないため、置換を追加することは失敗時に原文を維持する要件を満たさない。

## 次の作業

- `EU4DLL_TRANSLATION_OBSERVATION_KEYS` で既存`translationMap`内の複数キーを辞書観測対象として選択でき、`ALL`では全キーを辞書順に照会する。ALLはロード後の辞書直接観測であり、キー件数と各キーの値を出すためログが大きくなり得る。未設定時は`MENU_BAR_LOAD_GAME`のみを照会する。これはゲーム実機での表示観測やキー対応の証明ではなく、6キーがmissingだった現象も未解決である。
- ALL観測の`6923`件は全件loadedだったが、6つの`MENU_BAR_*`キーは`text_l_english.yml`のパースエラーによるファイル単位スキップが原因だった。BOM除去と`:0`〜`:9` suffix変換を実装し、最小テストで6キーの登録を確認した。実機再確認は未実施。
- GDB自身へ`LD_PRELOAD`を設定せずinferiorのEU4だけへDLLを設定する専用wrapper `tools/trace_eu4_text_with_dll.sh` を追加した。実行例は `memory-bank/details/runtime_trace.md` に記録し、実機結果は未取得である。
- 文字列読出しを急がず、今回得たCStringのデータポインタと長さの組を静的に検討する。必要なら安全条件を明示した単一候補・単一ヒットの観測を設計する。全 `PdxLocalize` 一括、`open`/`read` フック、インラインパッチは行わない。
- 置換を再開する前に、Linux v1.37.5での実引数文字列一致、CStringの所有権・寿命、命令境界とトランポリン、AOB一意性、相対アドレス範囲、W^X復元を個別に証明する。

## 今回の判断

GDBバッチスクリプトだけでは `/proc/<pid>/maps` の読み取り可能範囲をブレークポイント処理の安全な条件式として利用できない。未確認ポインタの文字列読出しは、現時点の静的解析とCStringメタデータ観測に不可欠ではないため、外部監視スクリプト、追加フック、実機起動、パッチは追加しない。次の一手は、既存データから置換候補を絞ることとし、文字列一致が必要になった場合だけ別途安全条件を再評価する。

## 直近の完了

`Misc.getVersion()`の実行ファイル指定を、個人環境の絶対パスから既存の`BytePattern.setModule()`既定値へ変更した。既定値は`std.file.thisExePath()`で実行中の実行ファイルを解決する。

## 方針変更

FreeType/HarfBuzz、SDL/OpenGL描画API、Windows版アドレスの直接流用は前提にしない。

## 直近の完了

`tests/poc`に`fopen`の対象限定観測を追加した。`localisation`、`.yml`、`.yaml`、フォント拡張子だけをstderrへ出力し、通常のI/Oは記録しない。`make -C tests/poc`と`make test`、`make all`が成功した。

EU4本体を`make run`で起動し、メニュー到達・操作可能を確認した。相対パスの`pattern_eu4jps.log`はEU4インストール先に作成され、起動時の翻訳YAMLロードと`DLL [OK]`を確認できる。`fopen`観測PoCのstderrログは本体DLLにはまだ組み込んでいない。

## 今回の変更

EU4 v1.37.5を起動せずに `readelf -Ws --wide | c++filt` と `objdump -dC` を実行し、`CString::CString(char const*)`（`0x254b1c2`）、`CString::operator==(CString const&) const`（`0xd96f6a`）、`CTextSprite::SetText(...)`（`0x20d9da4`）、`CGraphics::CreateTextSprite(...)`（`0x2079b00`）を確認した。コンストラクタは `std::string(char const*)` を呼び、比較演算子は両CStringの `+8` を長さとして比較した後、`+0` を `bcmp` のデータポインタとして使用する。SetTextは `rdx` の `+0` を読み `strlen` に渡し、CreateTextSpriteは `rsi` の `+0` を読み `std::string` 構築へ渡す。従って `+0` はデータポインタ候補、`+8` は長さ候補だが、ABI・寿命・可読性を確定するものではない。

GDBの `info proc mappings` は表示を行うだけで、ブレークポイントコマンド内で任意アドレスが読み取り可能範囲にあることを検査する標準的な条件式へ安全に変換できない。候補ポインタの間接参照自体も未確認メモリを読むため、`x/s`、`x/b`、GDB Python、inferior関数呼出しは追加しない。`tools/trace_eu4_text_args.gdb` と `.sh` は変更せず、アドレス・tid・pc・回数のみの観測を維持する。

候補関数ごとにSysV x86-64 ABI上の先頭2つのCString候補アドレスを記録する調査用GDBスクリプトを実機で実行した。`/tmp/eu4dll-text-args.log` は85135 bytes、`TRACE_ARGS` は678行で、候補アドレスのみを記録し、文字列は読み出していない。

EU4 v1.37.5は正常終了し、MENU画面まで到達した。`CGraphics::CreateTextSprite` は236回、`CTextSprite::SetText` は442回で、全てtid=1、pcはそれぞれ `0x2079b00`、`0x20d9da4` だった。ログ中に `Load Game` も `ロード` も現れず、既知キーとの直接対応、CString構造、レジスタ候補、文字列形式・寿命は未確認である。両関数はMENU画面で頻繁に通る表示生成経路候補として記録するが、既知キー対応とは断定しない。

`tools/trace_eu4_text_preview.gdb` と `.sh` を追加した。`CTextSprite::SetText` の `rdx` と `CGraphics::CreateTextSprite` の `rsi` について、NULLでないCStringオブジェクトの `+0`（データポインタ候補）と `+8`（長さ候補）を各関数の最初の最大10ヒットだけ記録する。GDB標準機能だけではデータポインタのreadable判定を安全に保証できないため、文字列表示は行わない。実機では `+0` 非NULLと `+8` 長さのメタデータを確認したが、`Load Game`、`ロード`との一致および `MENU_BAR_LOAD_GAME` との関係は未確認である。

次の最小ステップでは、全 `PdxLocalize` テンプレート一括フック、`open`/`read` フック、インラインパッチを行わず、まず静的解析または安全な条件付き観測方法を検討する。

## これまでの変更

`MENU_BAR_LOAD_GAME`（`Load Game` / `ロード`）を既知観測対象に固定した。翻訳ロード完了時にこのキーだけを照会し、loaded/missing と値を1行記録する。ゲーム本体の `LocalizeAddLocalization`、`YmlParse`、`PdxLocalize` 系、`CTextBox` は安全な呼び出し境界を確認できないため、フックは追加していない。

## これまでの観測

前回の候補 `CTextBuffer::ChangeString()` と `CTextBox::ChangeString(CString const&)` は、breakpoint設定には成功したが `/tmp/eu4dll-candidate-trace.log`（9484 bytes）でTRACE 0件だった。今回の操作では呼ばれておらず、成功扱いにしない。続く `CTextBox::UpdateTextSprite()` と `CTextBox::ChangeString(CString const&, FontFormatting, bool)` もMENU画面までのTRACE 0件だったため除外した。新候補を `CTextSprite::SetText(...)` と `CGraphics::CreateTextSprite(...)` に更新し、各ヒットで `symbol/tid/pc` の1行だけを記録した。実機ヒットの対応関係と引数は未確認である。

実機トレースではlocalisation読み込み経路を確認したが、`CTextBox::ChangeTextBox`はヒットせず、表示時の既知キー追跡には至っていない。次は候補を一括で増やさず、表示更新に近い既存テキスト関数を1つずつ観測する。
