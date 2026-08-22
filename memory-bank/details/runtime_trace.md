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
5. `TRACE symbol=...`、`tid`、`pc` の1行出力を保存する。候補のヒットが多い場合は、対象メニューへ到達するまでのログと到達後のログを分ける。

## 観測対象

`readelf -Ws` と `objdump -dC` でEU4 v1.37.5に存在し、テキスト更新に近いことを確認したシンボルを最大2つだけ候補にする。

| シンボル | 現時点で言える役割 | 未確認事項 |
| --- | --- | --- |
| `CTextSprite::SetText(CGraphics*, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int>, FontFormatting, bool)` | CStringを内部バッファへコピーし、フォント・テクスチャ処理と頂点再計算を行うテキスト設定実体 | `MENU_BAR_LOAD_GAME` 表示時に呼ばれるか、各CStringの意味と寿命 |
| `CGraphics::CreateTextSprite(CString const&, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int> const&, C2dObject*, FontFormatting, bool)` | テキストスプライトを生成し、設定の仮想関数へ文字列・書式引数を渡す生成入口 | `MENU_BAR_LOAD_GAME` 表示時に呼ばれるか、生成頻度と引数の意味 |

`PdxLocalize`、`InternalPdxLocalize`、localisation読み込み関数、`CTextBox::ChangeTextBox`、実機0ヒットの`CTextBox` 2候補は候補へ追加しない。テンプレート実体の一括ブレークや、未確認の文字列ポインタの読み取りも行わない。

## 静的選定根拠（EU4 v1.37.5）

対象バイナリに対して次のコマンドを実行した。

```sh
readelf -Ws --wide "$EU4_BIN" | c++filt | rg 'CTextSprite::SetText|CGraphics::CreateTextSprite'
objdump -dC --start-address=0x20d9da4 --stop-address=0x20da60c "$EU4_BIN"
objdump -dC --start-address=0x2079b00 --stop-address=0x2079cbc "$EU4_BIN"
```

確認結果は `CTextSprite::SetText(...)` が `0x20d9da4`、サイズ2151バイトで、複数のCStringを`std::string`内部バッファへコピーし、フォント取得、テクスチャ更新、テキスト描画データ更新、`RecalculateVertices()`まで行う実装だった。`CGraphics::CreateTextSprite(...)` は `0x2079b00`、サイズ443バイトで、テキストスプライト型を検索・生成し、末尾で設定用の仮想関数（vtable +0x1a8）へ文字列・書式・サイズ引数を渡す実装だった。前者を文字列設定の第1候補、後者を生成・設定入口の第2候補とした。これは候補選定の根拠であり、実機の表示経路や呼び出し頻度を確定するものではない。

### CStringアクセスの追加確認

同じEU4 v1.37.5実行ファイルで、次のシンボルと命令列を確認した。これは静的解析のみであり、EU4は起動していない。

```sh
readelf -Ws --wide "$EU4_BIN" | c++filt | rg 'CString::CString\(char const\*\)|CString::operator==|CTextSprite::SetText|CGraphics::CreateTextSprite'
objdump -dC --start-address=0x254b1c2 --stop-address=0x254b1d5 "$EU4_BIN"
objdump -dC --start-address=0xd96f6a --stop-address=0xd96f94 "$EU4_BIN"
objdump -dC --start-address=0x20d9da4 --stop-address=0x20da60c "$EU4_BIN"
objdump -dC --start-address=0x2079b00 --stop-address=0x2079cbc "$EU4_BIN"
```

- `CString::CString(char const*)`（`0x254b1c2`）は `std::string::basic_string(char const*, allocator const&)` を呼ぶ。
- `CString::operator==(CString const&) const`（`0xd96f6a`）は両オブジェクトの `+8` を長さとして比較し、非ゼロなら各オブジェクトの `+0` を `bcmp` のデータポインタとして渡す。
- `CTextSprite::SetText(...)`（`0x20d9da4`）は第一CString候補の `rdx` を保存し、`mov (%rdx), %rbp` の後に `%rbp` を `strlen` へ渡す。後続のCString候補でも同じ形式のアクセスがある。
- `CGraphics::CreateTextSprite(...)`（`0x2079b00`）は第一CString候補の `rsi` を `mov 0x0(%rbp), %rsi` で読み、その値を `std::string` 構築へ渡す。

以上から、CString先頭の `+0` はchar*相当のデータポインタ候補、`+8` は長さ候補である。ただし、この静的根拠だけでは候補アドレスが有効なCStringオブジェクトであること、指すデータがNUL終端であること、実機ヒット時の寿命・文字コード・引数位置を保証できない。

## 文字列読出しの安全性判断

GDB標準の `info proc mappings` はマッピングを表示できるが、ブレークポイントコマンド内でその結果を読み取り可能範囲の条件式として安全に利用する機構はない。候補CStringの `+0` を間接参照する時点で未確認メモリを読むため、`x/s` や `x/b` を条件付きで追加しても、GDB標準機能だけでアクセス成功を保証できない。GDB Pythonとinferior関数呼出しも制約により使用しない。

従って、`tools/trace_eu4_runtime.gdb` と `tools/trace_eu4_text_args.gdb` は変更せず、後者は候補アドレス、tid、pc、回数だけを各ヒット1行で記録する。`Load Game`、`ロード`、または対応するUTF-8/UTF-16値が実際に読めていないため、`MENU_BAR_LOAD_GAME`との対応は未確認のままとする。

## 判定上の注意

- シンボルの存在は、実行時にその経路が通ることを意味しない。
- ブレークポイントのヒットだけでは引数の型、文字列の寿命、登録値と表示値の同一性は確定しない。
- `MENU_BAR_LOAD_GAME` のASCII・UTF-8・UTF-16相当のメモリアドレス探索は、この手順の出力だけでは行わない。
- ハング、過剰なログ、再現性のない停止が起きた場合は追跡を中止し、フックやインラインパッチへ変更しない。

## 既存実機トレース結果（EU4 v1.37.5）

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

`CTextBox::UpdateTextSprite()` と `CTextBox::ChangeString(CString const&, FontFormatting, bool)` は、breakpointをそれぞれ `0x20d3a34`、`0x20d3b6c` に設定できたが、MENU画面までのトレースでTRACE 0件だった。EU4は正常終了したため、候補の実在やbreakpoint設定の成否とは別に、今回のMENU表示経路の候補としては除外する。

このトレースは旧スクリプトによる読み込み観測であり、現在の候補スクリプトでは再利用しない。前回候補の実機結果は `/tmp/eu4dll-candidate-trace.log` が9484 bytes、TRACE 0件だった。breakpointは `CTextBuffer::ChangeString()`=`0x20d8c7e`、`CTextBox::ChangeString(CString const&)`=`0x20d3a9a` に設定できたが、今回の起動・操作では呼ばれなかった。続く `CTextBox` 2候補もMENU画面までTRACE 0件であり、表示経路は未確定のまま成功扱いにしない。現在は新候補2関数について `symbol/tid/pc` の1行だけを記録する。`MENU_BAR_LOAD_GAME` のASCII/UTF-8表現を安全に読めるポインタ根拠はまだないため、GDBでの `x/s` 探索は実施しない。

## 新候補の実機トレース結果（EU4 v1.37.5）

`/tmp/eu4dll-sprite-trace.log` は45921 bytesで、次のヒットを確認した。

| シンボル | ヒット数 | tid | pc |
| --- | ---: | ---: | --- |
| `CGraphics::CreateTextSprite(...)` | 236 | 1 | `0x2079b00` |
| `CTextSprite::SetText(...)` | 442 | 1 | `0x20d9da4` |

EU4 v1.37.5は正常終了した。実機はMENU画面まで到達し、「ロード」表示状態を確認した。ただし短いTRACEでは文字列引数を記録していないため、これらのヒットが `MENU_BAR_LOAD_GAME` そのものに対応すること、引数の意味、文字列形式、文字列の寿命、localisation値との因果関係は未確認である。従って、`CGraphics::CreateTextSprite` → `CTextSprite::SetText` を現在最有力の表示生成経路として記録するが、表示経路の因果関係は断定しない。

再観測が必要になった場合は、候補2関数のTRACEに未確認ポインタを無条件に読む処理を追加せず、まず静的解析または安全な条件付き観測方法を検討する。全 `PdxLocalize` テンプレート一括フック、`open`/`read` フック、インラインパッチは行わない。

## 候補CStringアドレスの限定観測

既存の `tools/trace_eu4_runtime.sh` は変更せず、引数候補を記録する調査専用スクリプトを追加した。

```sh
EU4_BIN="$HOME/.steam/debian-installation/steamapps/common/Europa Universalis IV/eu4" \
  ./tools/trace_eu4_text_args.sh 2>&1 | tee text-args-trace.log
```

このスクリプトは各候補関数で最大2個の `CString` 候補について、`symbol`、`tid`、`pc`、ヒット回数、レジスタ値（アドレス）だけを記録する。`SetText` は `rdx`/`rcx`、`CreateTextSprite` は `rsi`/`rdx` を対象とする。これはSysV x86-64の暗黙の `this`（`rdi`）を除いたC++引数配置と、`readelf -Ws` のデマングル済みシグネチャに基づく。後続の引数はスタック上または整数レジスタに混在し得るため対象外とした。

GDB標準コマンドだけでは、任意の候補ポインタを読み取り可能か事前に判定し、判定失敗時も停止せずに限定長の文字列を読むことを移植性高く保証できない。このため、本スクリプトは `x/s`、`x/b`、GDB Python、関数呼出しを使用せず、アドレスのみを記録する。ログに `Load Game`、`ロード`、または対応するUTF-8/UTF-16値が現れることはないため、この観測だけでは `MENU_BAR_LOAD_GAME` 対応とは判定しない。

## 候補CStringアドレスの実機結果（EU4 v1.37.5）

`/tmp/eu4dll-text-args.log` は85135 bytesで、`TRACE_ARGS` は678行だった。EU4は正常終了し、実機はMENU画面まで到達した。`CGraphics::CreateTextSprite` は236回（全てtid=1、pc=`0x2079b00`）、`CTextSprite::SetText` は442回（全てtid=1、pc=`0x20d9da4`）だった。

記録したのは候補CStringアドレスのみで、文字列の読み出しはしていない。ログ中に `Load Game` も `ロード` も現れないため、`MENU_BAR_LOAD_GAME` との直接対応、CString構造、各レジスタ候補の正しさ、文字列形式・寿命、呼び出し元と表示値の対応は未確認である。従って、`CGraphics::CreateTextSprite` → `CTextSprite::SetText` はMENU画面で頻繁に通る表示生成経路候補として記録するが、既知キー対応とは断定しない。

このスクリプトは未確認ポインタの文字列読出しを行わないため、任意メモリ参照による停止リスクを避けられる一方、アドレスだけでは文字列一致を判定できない。次は既存の有志翻訳Mod/`translationMap`を入力データとして維持しつつ、CString ABIの構造を静的に確認し、安全条件を設けた別調査スクリプトで一度に少数の引数だけを観測する。全 `PdxLocalize` 一括、`open`/`read` フック、インラインパッチは行わない。

## CStringメタデータの限定観測スクリプト

`tools/trace_eu4_text_preview.sh` は、既存のアドレスのみの `trace_eu4_text_args.sh` を変更せずに、CStringオブジェクトのメタデータを限定観測する。実行例:

```sh
EU4_BIN="$HOME/.steam/debian-installation/steamapps/common/Europa Universalis IV/eu4" \
  ./tools/trace_eu4_text_preview.sh 2>&1 | tee text-preview-trace.log
```

`CTextSprite::SetText` の `rdx` と `CGraphics::CreateTextSprite` の `rsi` を対象とし、各関数の最初の最大10ヒットで、CStringオブジェクトがNULLでない場合だけ `+0` のデータポインタ候補と `+8` の長さ候補を記録する。GDBの `if` でオブジェクトNULLを除外するが、データポインタ自体のreadable判定は行わない。

GDB標準コマンドだけでは任意アドレスのreadable判定を安全に保証できないため、`x/s`、`x/b`、GDB Python、inferior関数呼出しは使用しない。したがって、このスクリプトは文字列本体を表示せず、`Load Game`、`ロード`との一致や `MENU_BAR_LOAD_GAME` との関係を判定できない。

## CStringメタデータの実機結果（EU4 v1.37.5）

`/tmp/eu4dll-text-preview.log` は10612 bytesだった。EU4 v1.37.5は正常終了し、実機はMENU画面まで到達した。TRACE_PREVIEWは各関数の最初の最大10ヒットを記録する。

`CGraphics::CreateTextSprite` の10ヒットすべてで、`rsi` CStringはNULLでなく、`+0` データポインタ候補も非NULLだった。`+8` 長さ候補は `7,7,13,13,18,13,6,32,32,13` だった。`CTextSprite::SetText` の10ヒットすべてでも、`rdx` CStringはNULLでなく、`+0` データポインタ候補も非NULLだった。`+8` 長さ候補は `0,0,0,4,2,6,6,5,5,2` だった。

この観測は、CStringの `+0` がデータポインタ、`+8` が長さという静的解析上の候補と整合する実機メタデータを得たことを示す。ただし、NULL除外はCStringオブジェクトに対してだけ行い、データポインタ自体のreadable判定は行っていない。文字列本体も読み出していないため、ログに `Load Game` / `ロード` の一致はなく、文字列内容、引数の意味、`MENU_BAR_LOAD_GAME`との直接対応、寿命は未確認である。既知キー対応や文字列内容を成功扱いしない。

次の最小ステップは文字列読出しを急がず、今回得たデータポインタと長さの組を静的に検討することとする。必要になった場合だけ、安全条件を明示した単一候補・単一ヒットの観測を設計する。全 `PdxLocalize` 一括、`open`/`read` フック、インラインパッチは行わない。

## 追加観測を見送る判断

Linuxの`/proc/<pid>/maps`は外部監視であれば読み取り可能範囲の確認材料になり得るが、GDBバッチスクリプトだけでその結果をブレークポイント処理の安全な条件式へ取り込むことはできない。候補CStringのデータポインタを読む処理自体にも未確認メモリ参照が残る。現時点では、文字列内容との一致確認は置換候補の静的な絞り込みに不可欠ではないため、外部監視スクリプト、追加のGDB読出し、フック、パッチは実装しない。文字列一致が必要になった場合に限り、単一候補・単一ヒットを前提とした別プロセス監視の必要性と安全条件を再検討する。
