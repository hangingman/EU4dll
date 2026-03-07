# Memo

## Mod

[Mods - Europa Universalis 4 Wiki](https://eu4.paradoxwikis.com/Mods)

Modのインストールフォルダは以下:

```
Windows: ~\Documents\Paradox Interactive\Europa Universalis IV\mod\
GNU/Linux: ~/.local/share/Paradox Interactive/Europa Universalis IV/mod/
Mac: ~/Documents/Paradox Interactive/Europa Universalis IV/mod/
```

ちなみにワークショップで配布されるModは以下:

```
// 以下、debianの場合
~/.steam/debian-installation/steamapps/workshop/content/236850/[Workshop item ID]
```

## EU4

EU4本体のインストールフォルダは以下:

```
// 以下、debianの場合
~/.steam/debian-installation/steamapps/common/Europa Universalis IV
```

このへんはsteamのゲーム一覧からプロパティを選ぶことで確認できる

## EU4でこのdllを使う方法（予定）

- 一応以下の方法で.soをhijackできることが確認できた
- launcher-settings.jsonで指定できれば嬉しいができないっぽい

```
// 以下、debianの場合, libeu4dll.soをコピーしておく
$ cd ~/.steam/debian-installation/steamapps/common/Europa Universalis IV
$ LD_PRELOAD=./libeu4dll.so ./eu4
```

## D言語ビルドとテストの修正履歴 (2025/11/21)

### 発生した主なエラーと修正内容

-   **`ScopedPatch` の設計変更:**
    -   RAIIリソース管理をより堅牢にするため、`ScopedPatch`は`struct`として設計されています。これにより、デストラクタが確定的に呼び出され、GCとの競合を回避し、安全なメモリパッチ管理を実現しています。
-   **`undefined identifier 'get_branch_destination_offset'` エラー:**
    -   `source/plugin/tooltip_and_button.d` に `import plugin.misc;` を追加し、未定義識別子を解決しました。
-   **`PatchManager.addPatch` の引数型不一致エラー:**
    -   `source/plugin/tooltip_and_button.d` にて、`PatchManager.instance().addPatch` の引数を `cast(void*)` と `cast(ubyte[])` で明示的にキャストし、型不一致を解消しました。
-   **`GC` が未定義であるエラー (unittest時):**
    -   `source/plugin/patcher/patcher.d` に `import core.memory;` を追加し、GC関連の機能が利用できるようにしました。
    -   unittest 内の `GC.collect()` と `GC.minimize()` の呼び出しは、GCの確定的なデストラクタ呼び出しを保証しないため、コメントアウトしました。また、アサート内容もパッチが当たった状態であることを確認するように修正しました。

## D言語ビルドとテストの修正履歴 (2025/12/01)

### 発生した主なエラーと修正内容

-   **ロギングライブラリの移行 (`dlogg` -> `std.logger`):**
    -   プロジェクト全体で`dlogg`のインポートとログ出力の呼び出しを`std.logger`形式に修正しました。
    -   `source/plugin/file_save/proc7.d`, `source/plugin/input/entry.d`, `source/plugin/input/proc1.d`, `source/plugin/input/proc10.d`, `source/plugin/input/proc11.d`内の`std.stdio.writeln`を`std.logger.info`に置換しました。
    -   `source/plugin/input/entry.d`に`cursorAddress`と`imeAddress`の検索結果ログを追加しました。
-   **`BytePattern`テストにおけるビルドエラー:**
    -   `tests/plugin/test_byte_pattern.d`から、`std.logger`への移行に伴い削除された`startLog`と`debugOutput`の呼び出しを削除し、テストのビルドエラーを解消しました。
-   **`mod.d`におけるYAMLファイルパス解決のバグ:**
    -   `source/plugin/mod.d`において、`std.file.DirEntry.name`が`dirEntries(SpanMode.depth)`によって絶対パスとして返されることを考慮し、`filePath`を`entry.name`を直接使用するように修正しました。これにより、`tests/plugin/test_mod.d`のユニットテストが成功するようになりました。

## D言語ビルドとテストの修正履歴 (2026/03/07)

### 発生した主なエラーと修正内容

-   **Linux x86_64におけるインラインアセンブリのPIC対応と再配置エラー:**
    *   **問題**: LDCを使用して共有ライブラリ（.so）をビルドする際、インラインアセンブリ（iasm）内でグローバル変数に `[symbol]` 形式でアクセスすると、リンカが `R_X86_64_PC32` や `R_X86_64_32S` の再配置エラー（shared object作成時に使用不可）を出す。
    *   **解決**: 全てのグローバル変数アクセスに **RIP相対アドレッシング** `[RIP + symbol]` を使用するように修正。これにより、位置独立コード（PIC）として正しくリンク可能になった。
    *   **補足**: `dub.json` に `-fvisibility=hidden` を追加し、内部変数を非公開にすることで、リンカによる最適化と再配置の安定性を向上させた。

-   **LDC/DMD-iasmにおける `MOVSXD` の互換性問題:**
    *   **問題**: レジスタ間（例: `movsxd RDX, EDI`）の `MOVSXD` 指令が LDC のインラインアセンブラで `invalid operand size/type` エラーを発生させることがある。
    *   **解決**: **手動符号拡張** を実装。 `shl RAX, 32` -> `sar RAX, 32` のシーケンスを使用することで、指令レベルの互換性問題を回避し、確実に32bitから64bitへの符号拡張を実現。

-   **メモリオペランドのサイズ明示 (`ptr` 構文):**
    *   **内容**: `byte [RCX+R9]` などの記述は LDC の iasm パーサで曖昧さとみなされる場合があるため、 `byte ptr [RCX+R9]` のように `ptr` を付加する Intel/DMD 互換構文を徹底。

### 結果

-   `ldc2` を使用したビルドとテストが、Linux環境のPIC要件を満たした状態で完全に成功（PASS）。
-   GitHub Actions CIにキャッシュ機能を導入し、ビルド時間を短縮。
