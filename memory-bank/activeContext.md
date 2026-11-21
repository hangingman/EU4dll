# Active Context

## 現在の焦点

Linux版EU4 v1.37.5で、`CTextSprite::SetText` の呼び出し境界に限定した文字列置換PoCを検証済み。CString所有権・容量・寿命の調査は完了し、`memory-bank/details/cstring_ownership.md` に記録した。容量（+16）の読み取りと可変長置換を実装した。次は可変長置換の実機確認へ進む。

## 確定事項

- `ReloadPdxLocalize` のフック通過だけでは、生成済みUIの表示は更新されなかった。
- `CTextSprite::SetText` はGDB観測でMENU画面を頻繁に通過し、第1 `CString` はSysV x86-64の`rdx`にある。
- v1.37.5の`SetText`固有AOBは、先頭17バイトと続く`44 89 4C 24 3C`を含めて一意化している。
- 5バイトrel32 JMPはstub配置の都合で使用できなかった。旧C++版にも遠距離時の14バイト絶対間接JMPが実装されていたため、Linux版も`FF 25 00 00 00 00 + 64bit address`を使用する。
- 絶対JMP、17バイトの完全命令境界、ABI保存stub、CStringの境界付きread/writeを実装した。
- `EU4DLL_SETTEXT_PROBE=1` と `EU4DLL_SETTEXT_REPLACEMENTS='Back=Home;Connect to ID=Connect to JP'` で実機起動し、`SetText probe installed` と `SetText replacement applied` 2件を確認した。EU4は正常終了し、`Back → Home` のUI反映を確認した。
- `make test`、`make all`、`git diff --check` は成功。依存ライブラリ由来のdeprecation warningは残る。

## 未確定・制約

- 可変長置換は容量以下の場合に限って実装済み。容量超過は `exceeds-capacity` で見送る。`Back=戻る`などの実機表示は未確認。
- `translationMap`のキーとSetText実引数の対応は未証明。PoCは明示的な環境変数マッピングを使う。
- フックはLinux・EU4 v1.37.5・明示opt-inに限定。全UI経路やWindows版への展開は未実施。
- GDB診断スクリプト末尾の`no registers`は、EU4終了後にレジスタを読む後処理エラーであり、native置換成功とは別問題。

## 次の作業

1. この変更をコミットする。
2. 必要なら置換ログへmapping idを追加し、2件の対応を個別に記録する。
3. 可変長置換を実機で確認する（Game Browser で長さの違う置換と日本語置換の表示）。
4. EU4のバージョン更新時はAOB一意性と完全命令境界を再検証する。
