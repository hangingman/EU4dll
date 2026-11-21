# Active Context

## 現在の焦点

Linux版EU4 v1.37.5で、翻訳Modを有効にした状態の全面日本語表示が実機確認済み（メニュー、Game Browser、国選択画面。所有者の環境でも直接起動で確認済み、2026-11-21）。現在の作業対象はフォントサイズ調整と表示品質で、残課題は TODO.txt に集約した。項目1〜32と2026-11-21夜の追加作業は全て master へマージ・push 済み。読み込みフックの既定有効化とSetText辞書の廃止も2026-11-22にマージ済み。

## 確定事項

- 日本語表示は次の組合せで成立する。(1) 生成フォント（Noto Sans CJK JP、翻訳ymlの3,130字）とグリフ表サイドテーブル（id >= 0x100 のグリフ保持）。(2) 描画・計測経路の復号フック（既定で有効、EU4DLL_ENABLE_DECODE=0 で無効化）。(3) ローカライズ読み込みフック（LocalizeYmlAddKey、既定で有効、EU4DLL_LOCALIZE_ESCAPE=0 で無効化。値をエスケープ形式のまま SLanguageData::AddKeyValuePair へ格納し、ConvertUTF8ToLatin1 の「？」化を回避する）。
- 内部表現は UTF-8 → UCS2 → Clausewitz エスケープ形式（0x10〜0x13 の3バイト表現、CP1252特殊ケースを含む）。変換器は source/plugin/localization/escape_codec.d。
- DLL は非EU4プロセスでは即座に戻る（preload ガード、/proc/self/exe の basename が "eu4" のときだけ動作）。Steam の起動連鎖を壊さないため。
- SetText 置換 PoC（CTextSprite::SetText の第1 CString、14バイト絶対JMP、同一長から容量内可変長まで）は実装済みだが、翻訳の本線ではない。基礎調査の記録は details/cstring_ownership.md、details/variable_length_history.md、details/mojibake_settext.md。
- make test の後は必ず make all を実行する。unittest ビルドが通常版 libeu4dll.so を上書きし、DLL が無効化される（details/dll_inactivation_item25.md）。

## 未確定・制約

- ゲーム内マップの国名表示（Render3d site 2 の wide path）は修正済みだが実機未踏。
- 生成フォントが全体的に2〜3pt大きく見える（所有者指摘）。チェックボックスのラベル重なり、狭い見出しの省略、メニューボタンの文字切れも未解消。
- フックは Linux・EU4 v1.37.5 に限定。バージョン更新時は AOB 一意性と命令境界の再検証が要る。

## 2026/08/29 の調査結果（要約）

- CString 所有権・容量・寿命: details/cstring_ownership.md、details/variable_length_history.md。
- SetText 置換が文字化けした原因（復号側未有効のため UTF-8 が1バイト文字として解釈された）: details/mojibake_settext.md。
- translationMap のキーと SetText 実引数に直接対応は無い: details/translationmap_settext_correspondence.md。
- 翻訳本体の所在（yml 145ファイル、素のUTF-8）と読み込み設計: details/translation_body_location.md、details/translation_file_loading_design.md。

## 2026-11-21 の作業記録（details 一覧）

- 復号有効化の調査と配線: decode_enablement_investigation.md、decode_optin_enablement.md、decode_default_enablement.md
- エスケープ変換器: escape_codec.md
- Font／TextView のパターン導出と注入: font_linux_patterns.md、main_text_linux_patterns.md、linux_injection_method.md、font_limiter_linux_injection.md、font_remaining_linux_injectors.md、main_text_linux_injection.md
- 変換器の SetText 接続: settext_escape_wiring.md
- 文字集合とフォント生成: charset_and_font_generation.md、font_generation_item23.md
- 表示確認と阻害要因: font_display_check_item24.md、dll_inactivation_item25.md、font_charset_table_limit_item26.md、font_display_recheck_item27.md、glyph_table_expansion_item28.md、bitmapfont_bytewidth_decode_item29.md、font_display_final_item30.md、ellipsis_distinguish_item31.md、ellipsis_fix_item32.md
- SetText辞書: translation_dict_stage_b.md、settext_dict_position_review.md、settext_dict_removal.md（辞書経路は2026-11-22に廃止。記録として残す）
- 読み込みフック: localisation_load_conversion_survey.md、localize_escape_hook.md
- wide path 修正: getheightofstring_decode_survey.md、decode_widepath_fix.md
- preload ガード: preload_guard.md
- 初期調査: runtime_trace.md、linux_patching_details.md
