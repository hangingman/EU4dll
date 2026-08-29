# Active Context

## 現在の焦点

Linux版EU4 v1.37.5で、`CTextSprite::SetText` の呼び出し境界に限定した文字列置換PoCを検証済み。次は実装の安定化とコミット後、同一長制約を外すためのCString所有権・容量調査へ進む。

## 確定事項

- `ReloadPdxLocalize` のフック通過だけでは、生成済みUIの表示は更新されなかった。
- `CTextSprite::SetText` はGDB観測でMENU画面を頻繁に通過し、第1 `CString` はSysV x86-64の`rdx`にある。
- v1.37.5の`SetText`固有AOBは、先頭17バイトと続く`44 89 4C 24 3C`を含めて一意化している。
- 5バイトrel32 JMPはstub配置の都合で使用できなかった。旧C++版にも遠距離時の14バイト絶対間接JMPが実装されていたため、Linux版も`FF 25 00 00 00 00 + 64bit address`を使用する。
- 絶対JMP、17バイトの完全命令境界、ABI保存stub、CStringの境界付きread/writeを実装した。
- `EU4DLL_SETTEXT_PROBE=1` と `EU4DLL_SETTEXT_REPLACEMENTS='Back=Home;Connect to ID=Connect to JP'` で実機起動し、`SetText probe installed` と `SetText replacement applied` 2件を確認した。EU4は正常終了し、`Back → Home` のUI反映を確認した。
- `make test`、`make all`、`git diff --check` は成功。依存ライブラリ由来のdeprecation warningは残る。

## 未確定・制約

- 現在は同一UTF-8バイト長の置換だけ。`Back=戻る`など可変長置換は未対応。
- `translationMap`のキーとSetText実引数の対応は未証明。PoCは明示的な環境変数マッピングを使う。
- フックはLinux・EU4 v1.37.5・明示opt-inに限定。全UI経路やWindows版への展開は未実施。
- GDB診断スクリプト末尾の`no registers`は、EU4終了後にレジスタを読む後処理エラーであり、native置換成功とは別問題。

## 次の作業

1. この変更をコミットする。
2. 必要なら置換ログへmapping idを追加し、2件の対応を個別に記録する。
3. CStringの所有権・容量・寿命を確認できるまで可変長置換を実装しない。
4. EU4のバージョン更新時はAOB一意性と完全命令境界を再検証する。

## 可変長置換調査結果（2026/08/29）

- `CString`の`+0=data pointer`、`+8=length`は、`CString::operator==`、`CString(char const*)`、実機観測と整合する。`+0x10`は`std::string`のSBO領域またはcapacity union候補だが、値の意味・capacity・所有権は未証明。
- `CTextSprite::SetText`の先頭（`0x20d9da4`）は、`rdx`のCStringから`+0`を取得し、`strlen`を実行した後、`std::string::_M_replace`でテキストスプライト内部（`this+0x220`）へコピーする。第1入力CStringのpointer/lengthを変更する命令はない。
- したがって「SetText内部でコピーされる」は確定したが、「入力CStringのpointerを一時差し替えれば安全」「length/capacityを変更できる」「元バッファを拡張できる」はいずれも未証明。
- 方針を補正し、TLS上の一時CStringビューによる1ケース限定の診断PoCを実験した。ASCII可変長は成功したが、日本語UTF-8は文字化けしたため、実験コードは恒久コードから削除し、同一長PoCへ戻した。
- 実験ビューは正規CStringオブジェクトではなく、SetTextが読む`+0/+8`だけを満たす借用ビューだった。SetText呼出し期間中はTLSバッファを保持し、callbackの戻り値をstubが保存済み`rdx`へ反映した。実験は終了済みである。
- これは安全性の証明でもUI成功の証明でもない。実機では対象範囲を`Back=戻る`の1ケースに限定し、DLLログとGDBログを分離して、ビュー生成・元CString非破壊・SetText継続・UI反映・クラッシュなしを個別確認する。
- 追加の所有権観測（constructor/copy/move/destructor、`+0/+8/+0x10`、allocation/free）は継続する。capacity推測、lengthだけの変更、任意アドレス探索は行わない。

## 可変長PoC実機結果（2026/08/29）

- 強制通常版ビルド後、提示された成功時と同じGDB wrapperで実機起動した。`crt_constructor entered`、`hijackProcess entered`、`SetText probe installed`を確認した。
- `Back=戻る`は9回`VARIABLE_VIEW_READY`となり、元CStringを変更せず一時TLSビューをSetTextへ渡す経路は実行された。EU4は正常終了した。
- しかしUIは日本語を文字化け表示した。判定は「Approach Bのpointer/lifetime検証は通過」「UTF-8バイト列の直接投入による日本語表示は失敗」。SetText入口のCString差し替えだけでは、EU4側が期待する文字コード/内部変換/フォント経路を満たさない。
- 今後はUTF-8変換を仮定して再試行せず、文字化けの実バイト列とEU4の期待形式を限定観測する。可変長PoCは診断状態のまま、翻訳機能として成功扱いにしない。
- 再発防止として`make all`を強制通常ビルドにし、`tools/trace_eu4_text_with_dll.sh`が通常版constructor markerを検証してからEU4を起動するようにした。

## ASCII可変長PoC実機結果（2026/08/29）

- `Back=Go Back`で再起動し、`VARIABLE_VIEW_READY source_length=4 replacement_length=7`を9件確認した。
- UI上で`Back → Go Back`を確認し、EU4は正常終了した。ログ上もSIGSEGV/SIGBUSはない。
- これにより、SetText呼出し中の一時CStringビュー差し替え、stubによる`rdx`差し替え、短期寿命保持はASCII可変長で動作確認済み。
- `Back=戻る`の失敗は可変長制御経路ではなく、日本語バイト列の入力形式・文字コード・フォント/後段変換の問題に絞る。次は既存日本語表示成功箇所のSetText生バイト列を観測する。

## SetText全CString候補の非ASCII観測結果（2026/08/29）

- `EU4DLL_SETTEXT_HEX_NONASCII=1`で`SetText`の`rdx`・`rcx`・`r8`を観測した。各候補はNULL、read失敗、負数/過大length、終端NUL不一致を除外し、length 1..64の高ビット列だけを最大64件記録した。
- 非ASCII列は0件だった。今回の実機操作では、`ロード`のUTF-8列や独自高ビットマッピング列がSetTextの3候補に現れた証拠はない。EU4は正常終了し、SIGSEGV/SIGBUSもない。
- 判定は未完了。日本語UIの実表示が別経路、別引数、ASCII相当の内部コード、または今回の操作対象外である可能性を残す。次はCreateTextSprite候補または日本語表示を確実に発生させる入口を同じ境界付き観測で調べる。

## Back限定再観測（2026/08/29）

- 専用ログ`/tmp/eu4dll-back-only-observe.log`で、`Back=戻る`の`VARIABLE_VIEW_READY`を9件確認した。`source_length=4`、`replacement_length=6`。
- constructor、hook設置、元入力一致、一時ビュー生成、EU4正常終了を確認したが、UI表示は文字化けした。
- Back経路については「可変長制御は通るが、日本語を表示可能な入力表現は未同定」という状態を確定する。

## 旧C++版のエンコード処理確認（git履歴 `c649f5c^`）

- `Plugin64/injector.hpp`にはASCII/UTF-8切替処理はなく、`MakeJMP`等の命令patchと`VirtualProtect`によるメモリ保護だけがある。
- `Plugin64/plugin_64.h`の`ParadoxTextObject`は、`char text[0x10]`/`char* p` union、`UINT64 len`、`UINT64 len2`。短文字列はinline、長文字列はpointerで、長文字列時の`len2=0x1F`を含む独自表現を使う。
- `Plugin64/escape_tool.cpp`はUTF-8をWindows `MultiByteToWideChar(CP_UTF8)`でUCS2へ変換し、UCS2をClausewitz用escaped text（`0x10`〜`0x13`の3-byte表現、CP1252互換byteを含む）へ変換する。UTF-8 bytesをそのままSetTextへ渡していない。
- `Plugin64/font.cpp`はchar code point上限、font buffer zero-clear/clear/expansion、font size limitをpatchする。旧`dll_main.cpp`は`Font::Init`と`Input::Init`を実行していた。
- 判定: 日本語表示に必要なのは、単純なCStringフラグではなく、少なくともUTF-8→escaped表現変換とフォント側容量/上限patchの組合せである可能性が高い。旧実装のWindows APIやアドレスをLinuxへ直接流用しない。
