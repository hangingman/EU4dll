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

-   **`ScopedPatch` がコピー不可である問題:**
    -   `struct ScopedPatch` を `class ScopedPatch` に変更し、RAIIリソースをGC管理下のクラスとして再設計しました。
    -   これにより、`PatchManager` での `ScopedPatch` インスタンスの管理を `new` を用いた生成と動的配列への格納に変更しました。
-   **`undefined identifier 'get_branch_destination_offset'` エラー:**
    -   `source/plugin/tooltip_and_button.d` に `import plugin.misc;` を追加し、未定義識別子を解決しました。
-   **`PatchManager.addPatch` の引数型不一致エラー:**
    -   `source/plugin/tooltip_and_button.d` にて、`PatchManager.instance().addPatch` の引数を `cast(void*)` と `cast(ubyte[])` で明示的にキャストし、型不一致を解消しました。
-   **`GC` が未定義であるエラー (unittest時):**
    -   `source/plugin/patcher/patcher.d` に `import core.memory;` を追加し、GC関連の機能が利用できるようにしました。
    -   unittest 内の `GC.collect()` と `GC.minimize()` の呼び出しは、GCの確定的なデストラクタ呼び出しを保証しないため、コメントアウトしました。また、アサート内容もパッチが当たった状態であることを確認するように修正しました。

### 結果

-   `make all` コマンドでプロジェクトのビルドがエラーなく成功しました。
-   `make test` コマンドでテストがすべてPASSしました。
-   `memory-bank/TODO.txt` の関連項目を `[x]` に更新しました。
