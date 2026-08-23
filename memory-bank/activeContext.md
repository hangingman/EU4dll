# Active Context

## 現在の焦点

`ReloadPdxLocalize` hook成功後の次段階として、constructorで翻訳ロードを行わず、localisation初期化後に一回だけ安全に翻訳ロードするPoCを設計する。

## 確定事項

- `loadTranslationMods()`をconstructor内で実行すると、EU4の表示文字列が`???`になる。
- `EU4DLL_SKIP_TRANSLATIONS=1`でスキップすると、`SetText`実引数は`Connect to ID`、`Back`などの正常な英語に戻る。
- GDBの直接観測では`ReloadPdxLocalize`の入口・復帰を確認できる。これはDLL側hookの成功を示さない。
- `ReloadPdxLocalize`の静的アドレスは`0x1fefa3a`、直接callsiteは`0x14bfee2`、`0x19fe50d`、`0x1ff0ebf`、`0x1ff9942`。
- 関数先頭は`55 41 56 53 48 83 EC 20`。先頭8バイトだけでは一意性がなく、関数先頭から`LocalizeGetCurrentLanguage`へのcallを含む13バイトAOBが一意候補。
- DLL側の最新実機ログでは、古いビルドについて`[DIAGNOSTIC] ReloadPdxLocalize entry exceeds rel32`が記録されている。
- 最新ビルドを作成してEU4側へコピーしたが、DLL側のhook installed/callbackログはまだ確認できていない。
- 実機のログ出力先はEU4インストールディレクトリの`pattern_eu4jps.log`。GDBログとは別物である。

## 原因候補の優先順位（KT法・検証チェックリスト）

- [x] **1. 実行対象DLLの不一致** — `make all`後の生成物とEU4側コピーはサイズ・更新時刻・SHA-256を比較済み。同一SHA-256（`ddde53...4bc3`）。wrapperの既定値もリポジトリ`libeu4dll.so`を絶対化して使用する。
- [x] **2. PIE/relocationによるアドレス基準の誤り** — `readelf -h`でEU4は`Type: EXEC`。PIEではなくload biasは0。AOB結果`0x1fefa3a`は実行時対象アドレスとして妥当。`BytePattern`はELF virtual addressを返すが、このバイナリでは追加加算不要。
- [x] **3. AOB検索範囲・パターンの誤り** — `.text`/`.rodata`を走査し、13バイトAOBは1件、`0x1fefa3a`を検出。version判定も`v1_37_5`。
- [x] **4. rel32範囲超過** — 2026/08/23 18:31の実機ログで`target=0x1fefa3a entry=0x40afa000 distance=1051764161 fits=true`、`hook installed`、`call enter`、`call return result=true`を確認。原因は`CallPatchLength`（`size_t`）混在によるunsigned比較。`fitsRel32()`で`CallPatchLength`を`long`へ明示変換して解消した。`MAP_32BIT`は維持し、絶対JMP化は不要。
- [x] **5. ログ出力先・時刻の取り違え** — stderr raw markerとEU4側`pattern_eu4jps.log`の今回起動分を同時に確認できた。`LD_DEBUG=libs`でも`./libeu4dll.so`のロード/initを確認済み。空白を含む絶対`LD_PRELOAD`値は動的リンカーが分割するため不可（`Europa`/`Universalis`/`IV/libeu4dll.so`）。
- [x] **6. GDBブレークポイントとの干渉** — `entry exceeds rel32`はGDBなしの直接起動でも記録されており、今回の主因ではない。成功確認時は引き続き対象関数へGDB breakpointを置かない。

### Gemini助言の追記・検証結果

- [x] stderrへのraw constructor marker提案 — `dllmain.d`へD runtime/std.logger非依存の固定`write(2,...)`を追加済み。constructor入口と`hijackProcess()`入口を分離観測する。
- [x] GDBなし直接起動提案 — 実施済み。EU4はexit 0だが、旧ビルドではrel32エラーを確認できた。
- [x] PIE/relocation確認提案 — `EXEC`確認により今回の原因から除外。
- [x] AOB一致数・target・trampoline・距離の記録提案 — `reload_trace.d`へtarget/entry/distance/fitsを1行で記録する診断ログを追加済み。次回実機起動で実値を確認する。
- [ ] `snprintf`を使う可変長raw logger提案 — 未採用。未検証のvarargs実装を増やさず、必要なら固定メッセージの`write(2,...)`だけを使う。

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
- 2026/08/23の修正版直接起動は、相対`LD_PRELOAD=./libeu4dll.so`で実施。EU4は停止後プロセス終了を確認したが、ログファイル差分は0 bytes。`LD_DEBUG=libs`ではDLLのロードとinit呼び出しを確認した。
- 次回実機確認では`/tmp/eu4dll-direct-current.log`から`[DIAGNOSTIC-RAW] crt_constructor entered`と`[DIAGNOSTIC-RAW] hijackProcess entered`を抽出する。前者のみならD runtime/logger初期化境界で停止、両方ならFileLogger以降の問題に絞る。
- 2026/08/23 18:31の直接起動で、`fits=true`、`hook installed`、`call enter`、`call return result=true`を確認。ReloadPdxLocalize hook診断は完了した。
