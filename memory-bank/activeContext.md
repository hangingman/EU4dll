# Active Context

## 現在の焦点

EU4 v1.37.5 Linux版で、DLL側の`ReloadPdxLocalize` hookログが確認できていない原因を特定し、最短でhook成功へ到達する。

## 確定事項

- `loadTranslationMods()`をconstructor内で実行すると、EU4の表示文字列が`???`になる。
- `EU4DLL_SKIP_TRANSLATIONS=1`でスキップすると、`SetText`実引数は`Connect to ID`、`Back`などの正常な英語に戻る。
- GDBの直接観測では`ReloadPdxLocalize`の入口・復帰を確認できる。これはDLL側hookの成功を示さない。
- `ReloadPdxLocalize`の静的アドレスは`0x1fefa3a`、直接callsiteは`0x14bfee2`、`0x19fe50d`、`0x1ff0ebf`、`0x1ff9942`。
- 関数先頭は`55 41 56 53 48 83 EC 20`。先頭8バイトだけでは一意性がなく、関数先頭から`LocalizeGetCurrentLanguage`へのcallを含む13バイトAOBが一意候補。
- DLL側の最新実機ログでは、古いビルドについて`[DIAGNOSTIC] ReloadPdxLocalize entry exceeds rel32`が記録されている。
- 最新ビルドを作成してEU4側へコピーしたが、DLL側のhook installed/callbackログはまだ確認できていない。
- 実機のログ出力先はEU4インストールディレクトリの`pattern_eu4jps.log`。GDBログとは別物である。

## 原因候補の優先順位

1. **実行対象DLLの不一致**
   - `make all`で生成した`libeu4dll.so`、EU4インストール先へコピーしたDLL、wrapperが`EU4_DLL`で指定するDLLを同一視できていない。
   - 起動前にサイズ・更新時刻・SHA-256を3箇所で比較する。

2. **PIE/relocationによるアドレス基準の誤り**
   - EU4の静的ELFアドレス`0x1fefa3a`と、実行時の`dlpi_addr + p_vaddr`を区別する必要がある。
   - `BytePattern`がELFのvirtual addressをそのまま返している場合、PIEでは実行時アドレスにならない。
   - `readelf -h`のType、`dl_iterate_phdr`の`dlpi_addr`、AOB結果の実行時アドレスを比較する。

3. **AOB検索範囲・パターンの誤り**
   - `BytePattern`は`.text`/`.rodata`のELF virtual addressを検索結果へ格納する。
   - 13バイトパターンの一致数と、実行時対象アドレスが一致するかをログで確認する。

4. **rel32範囲超過**
   - `mmap`のhintは配置を保証しない。
   - trampoline配置先と`target → entry`距離をログへ出し、signed 32-bit範囲を確認する。
   - 範囲外なら近距離stubまたは絶対間接JMPを使う。

5. **ログ出力先・時刻の取り違え**
   - GDBの`TRACE_LOCALIZE`、`/tmp`のteeログ、EU4側`pattern_eu4jps.log`を混同しない。
   - 最新起動時刻以降のログだけを`strings`またはバイナリ対応処理で確認する。

6. **GDBブレークポイントとの干渉**
   - GDBはEU4本体へ直接breakpointを置き、DLLは同じ本体アドレスを書き換える。
   - DLL hook確認時は、`ReloadPdxLocalize`へGDB breakpointを置かず、GDBは`main`またはconstructor後の観測だけに限定する。

## 最短の診断手順

1. 起動前にビルドする。
   ```sh
   cd /path/to/EU4dll
   make all
   ```
2. 生成DLLをEU4側へコピーし、同一性を確認する。
   ```sh
   cp -f ./libeu4dll.so "/path/to/Europa Universalis IV/libeu4dll.so"
   sha256sum ./libeu4dll.so "/path/to/Europa Universalis IV/libeu4dll.so"
   ```
3. `pattern_eu4jps.log`の今回起動分を分離する。起動前のファイルサイズまたは末尾位置を記録し、終了後はその位置以降だけを確認する。
4. GDBの`TRACE_LOCALIZE`とは別に、DLL側で以下の順に診断ログを確認する。
   ```text
   constructor entered
   translation load skipped
   target AOB match count
   target runtime address
   trampoline address
   rel32 distance
   patch applied
   callback enter
   callback return
   ```
5. target AOB一致が0または複数なら、AOB・ELF virtual address・PIE基準の問題を修正する。
6. AOB一致が1でrel32超過なら、`mmap`のhint任せをやめ、targetから±2 GiB内の配置を確保するか、絶対間接JMPで置換する。
7. patch適用ログまで出るがcallbackが出ない場合は、entry trampolineの命令列・実行権限・GDB breakpoint干渉を確認する。
8. callbackが出て元処理が正常復帰した後にのみ、`ReloadPdxLocalize`復帰後の翻訳ロードを検討する。

## 現在の実装方針

- ログ専用hookを対象とし、SetText置換、翻訳値置換、全UI対応は行わない。
- `EU4DLL_SKIP_TRANSLATIONS=1`を使い、起動初期の独自翻訳ロードを止めた状態でhookだけを検証する。
- `ReloadPdxLocalize`の13バイトAOB一意性、PIEの実行時アドレス変換、rel32距離、パッチ適用、callback入口・復帰を一度の起動で記録する。
- 成功判定はGDB観測ではなく、今回起動分のDLL側ログで行う。

## 保留

- `loadTranslationMods()`の遅延実行
- SetText置換
- CString所有権・寿命を前提にした置換
- AOB一括hook
- `open`/`read` hook
- SDL/OpenGL描画層hook
- Windows版アドレスの流用

## 再開時の最初の一手

最新版DLLとEU4側コピーのSHA-256を比較し、PIE判定と`dlpi_addr`を確認したうえで、DLL側constructorからstderrへ直接ロードマーカーを出す。次に13バイトAOBの一致数・実行時target・trampoline・rel32距離を同じ起動ログへ記録する。

source/plugin/localization/reload_trace.dは未コミットの診断実装であり、実機hook成功は未確認。変更後は`make all`、`make test`、`git diff --check`、実機起動を行う。

## 既知の実行条件

- EU4実行ファイル、DLL、GDB wrapper、境界観測スクリプトは各自の環境で指定する。
- EU4実行時は`EU4DLL_SKIP_TRANSLATIONS=1`を付ける。
- EU4側ログは実行ディレクトリの`pattern_eu4jps.log`に出力される。

## 検証状態

- 2026/08/23時点で、`make all`、`make test`、`git diff --check`は成功。
- 最新DLLの実機hook成功は未確認。
- GDBによる本体関数観測は成功。
- EU4は過去の実機起動で正常終了。
- `dllmain.d`と`reload_trace.d`の実装状態は`git status`で確認する。
