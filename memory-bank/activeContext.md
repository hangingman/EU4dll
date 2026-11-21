# Active Context

## 現在の焦点

Linux版EU4 v1.37.5で、`CTextSprite::SetText` の呼び出し境界に限定した文字列置換PoCを検証済み。CString所有権・容量・寿命の調査は完了し、`memory-bank/details/cstring_ownership.md` に記録した。容量（+16）の読み取りと可変長置換を実装した。可変長置換の過去の試行整理と容量の実測は完了し、`memory-bank/details/variable_length_history.md` に記録した（対象2件はどちらもSSO容量15）。文字化けの原因の切り分けは完了し、`memory-bank/details/mojibake_settext.md` に記録した（SetText置換は変換を通らず、復号側のテキスト処理ループ／フォントフックがLinux版では未有効のため、UTF-8バイト列が1バイト文字として解釈されて化ける）。翻訳ファイル読み込みへの移行設計は完了し、`memory-bank/details/translation_file_loading_design.md` に記録した（設計のみ、実装は所有者の確認待ち）。翻訳本体の所在確認は完了し、`memory-bank/details/translation_body_location.md` に記録した（JSON形式の本体は環境内に無く、実在するのはuser側に配置されたyml形式145ファイルで、値は素のUTF-8・エスケープ無し）。

## 確定事項

- `ReloadPdxLocalize` のフック通過だけでは、生成済みUIの表示は更新されなかった。
- `CTextSprite::SetText` はGDB観測でMENU画面を頻繁に通過し、第1 `CString` はSysV x86-64の`rdx`にある。
- v1.37.5の`SetText`固有AOBは、先頭17バイトと続く`44 89 4C 24 3C`を含めて一意化している。
- 5バイトrel32 JMPはstub配置の都合で使用できなかった。旧C++版にも遠距離時の14バイト絶対間接JMPが実装されていたため、Linux版も`FF 25 00 00 00 00 + 64bit address`を使用する。
- 絶対JMP、17バイトの完全命令境界、ABI保存stub、CStringの境界付きread/writeを実装した。
- `EU4DLL_SETTEXT_PROBE=1` と `EU4DLL_SETTEXT_REPLACEMENTS='Back=Home;Connect to ID=Connect to JP'` で実機起動し、`SetText probe installed` と `SetText replacement applied` 2件を確認した。EU4は正常終了し、`Back → Home` のUI反映を確認した。
- `make test`、`make all`、`git diff --check` は成功。依存ライブラリ由来のdeprecation warningは残る。

## 未確定・制約

- 可変長置換は容量以下の場合に限って実装済み。容量超過は `exceeds-capacity` で見送る。`Back=戻る`は実機で `result=applied` を確認済みだが、表示は文字化けする（原因は `details/mojibake_settext.md`）。
- `translationMap`のキーとSetText実引数の直接対応はないことを確認した（詳細は `details/translationmap_settext_correspondence.md`）。キーはローカライズキーで、SetTextへ渡るのは英語値側。`MENU_BAR_LOAD_GAME` の英語値 `Load Game` はメインメニュー実行ではSetText到達を観測できなかった。実データの日本語値はサブモジュール未初期化のため未取得。PoCは明示的な環境変数マッピングを使う。
- フックはLinux・EU4 v1.37.5・明示opt-inに限定。全UI経路やWindows版への展開は未実施。
- GDB診断スクリプト末尾の`no registers`は、EU4終了後にレジスタを読む後処理エラーであり、native置換成功とは別問題。

## 次の作業

1. この変更をコミットする。
2. 必要なら置換ログへmapping idを追加し、2件の対応を個別に記録する。
3. 可変長置換を実機で確認する（Game Browser で長さの違う置換と日本語置換の表示）。
4. EU4のバージョン更新時はAOB一意性と完全命令境界を再検証する。

## 復号の有効化方法の調査（2026/11/21追記）

- 詳細は `memory-bank/details/decode_enablement_investigation.md` に記録した（調査のみ）。`Font.init`／`TextView.init` は、インジェクタにv1.37.5のケースが無く、ローカル／上流v1.37（Windows）の全パターンがLinuxバイナリで0件のため、コメントアウトを外すだけでは有効にならない。有効化にはLinux版 `CBitmapFont` 系関数からのフック箇所特定とLinux用パターン／アセンブリの新規作成が要る。


## UTF-8→エスケープ変換器の実装（2026/11/21追記）

- 詳細は `memory-bank/details/escape_codec.md` に記録した。`source/plugin/localization/escape_codec.d` に純粋な変換器を実装し、復号テストダブルとの往復テストと4帯域の固定ベクタで検証した（`make test` 7モジュール通過）。変換表は上流 matanki-saito/EU4dll の `Plugin64/escape_tool.cpp` の移植で、回避バイト集合とCP1252特殊ケースを含む。フックへの配線は未実施（項目7設計の段階B、所有者の判断待ち事項が残る）。項目11の画面確認は復号側の有効化が済んでいないため実施しない。

## Font側のLinux用パターン導出（2026/11/21追記）

- 詳細は `memory-bank/details/font_linux_patterns.md` に記録した（導出のみ、注入は無効のまま）。Font側6注入のうち、リミッタ（`ParseFontFile` VA 0x204e366、`41 81 FD FF 00 00 00 0F 87 25 01 00 00`、全体で1件）だけが一意パターンまで確定した。HeapZeroClear はLinuxに対応箇所なし、BufferClear／Expansion の 0x3D88 は存在せず候補は `GfxCreateVertexBuffer` の即値 0x4B0 の2箇所（役割の同一性は未証明）、FontSizeLimit は未発見。

## TextView側のLinux用パターン導出（2026/11/21追記）

- 詳細は `memory-bank/details/main_text_linux_patterns.md` に記録した（導出のみ、注入は無効のまま）。Proc1は `FillVertexBuffer` の2箇所（VA 0x2055562／0x2055ac1）、Proc4はループ1の3関数に各1箇所（VA 0x2056198／0x2056872／0x20570b6）が文脈込みで各1件に一意化できた。Proc2はWindowsの形（バッファ `lea`＋全文字コピー）がLinuxに無く、Proc3はフック形がループ2側に1件あるのみで戻り先2が無い。文字取得は `CString::operator[]` 経由、グリフ表+0x100、スケール+0x940。

## Linux注入方式の整備（2026/11/21追記、項目14）

- 詳細は `memory-bank/details/linux_injection_method.md` に記録した。patcherの `makeJmp` は14バイト絶対ジャンプになり、BytePatternは全件数え＋`hasSize` 実判定になった。`Font.init`／`TextView.init` はまだ無効。次は項目15（復号の有効化、opt-in）。絶対ジャンプを使う注入は「完全な命令を14バイト以上上書きし、トランポリンのコピー長と一致させる」ことが条件で、ReloadPdxLocalize（コピー長8バイト）は相対ジャンプのまま明示した。

## 復号の有効化配線（2026/11/21追記、項目15）

- 詳細は `memory-bank/details/decode_optin_enablement.md` に記録した。`EU4DLL_ENABLE_DECODE=1` の場合だけ `Font.init`／`TextView.init` を呼ぶ。v1.37.5では各注入にケースが無くパッチは当たらないため、復号はまだ機能しない（項目16の前提は未充足）。配線の過程で `DllError` の `|` 演算子が無限再帰する潜在バグが見つかり、フィールド単位ORへ修正済み（初回smoke runs/20261121-145211 は eu4_wait=139 で落ち、修正後の runs/20261121-145625 は正常終了・英語表示正常）。

## Font側リミッタ注入の実装（2026/11/21追記、項目17）

- 詳細は `memory-bank/details/font_limiter_linux_injection.md` に記録した。リミッタは v1.37.5 で実装済み（パターン1件一致時のみ、即値 0xFF→0xFFFF、opt-in時のみ）。他のFont注入（BufferClear／Expansion／FontSizeLimit）は項目18で整理する。リミッタ単独では日本語表示は有効にならず、項目19のTextViewフックと項目20の変換器接続が要る。

## Font側の残り注入の整理（2026/11/21追記、項目18）

- 詳細は `memory-bank/details/font_remaining_linux_injectors.md` に記録した。FontSizeLimit は `CTextureHandler::LoadTexture` VA 0x22a7edb のファイルサイズ上限（16MiB）だと特定して v1.37.5 で実装済み（1件一致時のみ 04000000h へ、opt-in時のみ）。BufferClear1/2 はLinuxに対応箇所なし、BufferExpansion の候補 0x4B0 は頂点数であり同等性が否定されたため実装しない。Font側で残る未実装はこの3件（＋HeapZeroClear）で、いずれも理由を記録して閉じた。
